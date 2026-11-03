#!/usr/bin/env bash
# UrbanManagement Phase 2 on the Docker VM: release -> SMB automount -> config -> .env -> image ->
# mssql/redis -> database/login -> import -> migrator + ingest x2/attachment/realtime/admin/worker + gateway -> checks.
# "verify" runs the checks only.
# Never echo secrets: passwords live only in $BASE/.env (600 root) and container environments.
# stdin line 1 (optional): base64 of the local appsettings.secret.json, used only when the IIS config is unreadable.
set -uo pipefail

MODE="$1"; RUN_ID="$2"; HOST="$3"; UPLOADS_SHARE="$4"; WWWROOT_SHARE="$5"; CRED="$6"
RESET="$7"; LEGACY_ROOT="$8"; PUBLIC_PORT="$9"; IIS_SITE_DIR="${10}"; MSSQL_MEM_MB="${11:-1280}"
MEM_MIN_MB="${12:-500}"
APP_ROLES="um-ingest um-ingest-2 um-attachment um-realtime um-admin um-worker"

STAGE="/tmp/um-deploy/$RUN_ID"
BASE=/opt/urbanmanagement
RELEASE="$BASE/releases/$RUN_ID"
UPLOADS_MNT=/srv/um-uploads
IIS_MNT=/mnt/um-wwwroot-ro
SQLCMD=/opt/mssql-tools18/bin/sqlcmd

mark() { echo "@@ $1=$2"; }
fail() { mark FAILED_AT "$1"; exit 1; }
dc() { sudo docker compose --project-directory "$BASE" -f "$BASE/compose.yaml" "$@"; }
sqlsa() { dc exec -T mssql bash -c "SQLCMDPASSWORD=\"\$MSSQL_SA_PASSWORD\" $SQLCMD -C -S localhost -U sa -b -h -1 -W -i /dev/stdin"; }

LOCAL_SECRET_B64=""
IFS= read -r LOCAL_SECRET_B64 || true
LOCAL_SECRET_B64="${LOCAL_SECRET_B64#$'\xef\xbb\xbf'}"

if sudo -n true 2>/dev/null; then mark SUDO_NOPASSWD yes; else mark SUDO_NOPASSWD no; fail sudo; fi
mark MODE "$MODE"

deploy_release() {
  sudo test -f "$STAGE/bundle.tgz" || fail bundle-missing
  sudo mkdir -p "$RELEASE" && sudo tar -xzf "$STAGE/bundle.tgz" -C "$RELEASE" || fail extract
  sudo install -m 644 "$RELEASE/compose.yaml" "$BASE/compose.yaml"
  sudo install -m 644 "$RELEASE/.env.example" "$BASE/.env.example"
  mark RELEASE "$RELEASE"
}

deploy_mount() {
  local line="//$HOST/$UPLOADS_SHARE $UPLOADS_MNT cifs credentials=$CRED,uid=1654,gid=1654,file_mode=0664,dir_mode=0775,noserverino,vers=3.1.1,_netdev,nofail,x-systemd.automount 0 0"
  if grep -qsxF "$line" /etc/fstab; then
    mark FSTAB kept
  else
    sudo cp /etc/fstab "/etc/fstab.bak-$RUN_ID"
    sudo sed -i "\#^[^[:space:]]\+[[:space:]]\+$UPLOADS_MNT[[:space:]]#d" /etc/fstab
    echo "$line" | sudo tee -a /etc/fstab >/dev/null
    mark FSTAB written
  fi
  sudo mkdir -p "$UPLOADS_MNT"
  sudo systemctl daemon-reload
  local unit
  unit="$(systemd-escape -p --suffix=automount "$UPLOADS_MNT")"
  sudo systemctl start "$unit" || fail automount
  mark AUTOMOUNT_UNIT "$unit"
}

check_mount() {
  sudo stat "$UPLOADS_MNT/." >/dev/null 2>&1
  local fs
  fs="$(findmnt -n -o FSTYPE --target "$UPLOADS_MNT" | tail -n 1)"
  mark UPLOADS_FSTYPE "${fs:-none}"
  [ "$fs" = "cifs" ] || return 1
  mark UPLOADS_TOP_DIRS "$(sudo find "$UPLOADS_MNT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
}

deploy_config() {
  local dir="$BASE/config-source"
  local cfg_source=local
  local -a files=()
  sudo install -d -m 700 "$dir"
  sudo rm -f "$dir"/iis-* "$dir"/local-*
  sudo mkdir -p "$IIS_MNT"
  if sudo mount -t cifs "//$HOST/$WWWROOT_SHARE" "$IIS_MNT" -o "ro,credentials=$CRED,vers=3.1.1,noserverino" 2>/tmp/um-iis-mount.err; then
    if sudo test -f "$IIS_MNT/$IIS_SITE_DIR/appsettings.json"; then
      local found=""
      for f in appsettings.json appsettings.Production.json appsettings.secret.json; do
        if sudo test -f "$IIS_MNT/$IIS_SITE_DIR/$f"; then
          sudo install -m 600 "$IIS_MNT/$IIS_SITE_DIR/$f" "$dir/iis-$f"
          files+=("$dir/iis-$f"); found="$found$f,"
        fi
      done
      cfg_source=iis
      mark IIS_FILES "${found%,}"
    else
      mark IIS_MOUNT_ERROR "site dir $IIS_SITE_DIR not found on share"
    fi
    sudo umount "$IIS_MNT"
  else
    mark IIS_MOUNT_ERROR "$(head -c 200 /tmp/um-iis-mount.err | tr '\n' ' ')"
  fi
  rm -f /tmp/um-iis-mount.err
  if [ "$cfg_source" = local ] && [ -n "$LOCAL_SECRET_B64" ]; then
    echo "$LOCAL_SECRET_B64" | base64 -d | sudo tee "$dir/local-appsettings.secret.json" >/dev/null
    sudo chmod 600 "$dir/local-appsettings.secret.json"
    files+=("$dir/local-appsettings.secret.json")
  fi
  mark CONFIG_SOURCE "$cfg_source"

  local tmp
  tmp="$(sudo mktemp)"
  sudo python3 - "$tmp" "${files[@]}" <<'PY' || fail config-merge
import json, re, sys

def strip_comments(text):
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == '\\' and i + 1 < n:
                out.append(text[i + 1]); i += 2; continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True; out.append(c)
        elif text.startswith('//', i):
            while i < n and text[i] != '\n':
                i += 1
            continue
        elif text.startswith('/*', i):
            end = text.find('*/', i + 2)
            i = n if end < 0 else end + 2
            continue
        else:
            out.append(c)
        i += 1
    return re.sub(r',(\s*[}\]])', r'\1', ''.join(out))

def merge(a, b):
    for k, v in b.items():
        if isinstance(v, dict) and isinstance(a.get(k), dict):
            merge(a[k], v)
        else:
            a[k] = v

out, files = sys.argv[1], sys.argv[2:]
cfg = {}
for path in files:
    with open(path, encoding='utf-8-sig') as f:
        merge(cfg, json.loads(strip_comments(f.read())))

dropped = []
for key in ('ConnectionStrings', 'Kestrel', 'DataProtection', 'Urls'):
    if cfg.pop(key, None) is not None:
        dropped.append(key)
storage = cfg.get('StorageOptions')
if isinstance(storage, dict):
    for key in ('FilesPhysicalPath', 'TusTempPath'):
        if storage.pop(key, None) is not None:
            dropped.append('StorageOptions:' + key)

win_paths = []
def walk(node, prefix):
    if isinstance(node, dict):
        for k, v in node.items():
            walk(v, prefix + [k])
    elif isinstance(node, list):
        for i, v in enumerate(node):
            walk(v, prefix + [str(i)])
    elif isinstance(node, str) and re.match(r'^[A-Za-z]:[\\/]', node):
        win_paths.append(':'.join(prefix))
walk(cfg, [])

with open(out, 'w', encoding='utf-8') as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
print('@@ CONFIG_INPUTS=%d' % len(files))
print('@@ PROD_TOP_KEYS=%s' % ','.join(sorted(cfg.keys())))
print('@@ PROD_DROPPED=%s' % (','.join(dropped) or 'none'))
print('@@ PROD_WINDOWS_PATH_KEYS=%s' % (','.join(win_paths) or 'none'))
PY
  sudo install -m 640 -o root -g 1654 "$tmp" "$BASE/appsettings.Production.json"
  sudo rm -f "$tmp"
}

deploy_env() {
  if sudo test -f "$BASE/.env"; then
    mark ENV kept
    return
  fi
  if sudo docker volume inspect urbanmanagement_um-mssql >/dev/null 2>&1; then
    mark ENV missing-with-existing-volume
    fail env
  fi
  # hex plus fixed upper/lower/digit: satisfies the SQL Server password policy and needs no quoting.
  UM_SA="Um$(openssl rand -hex 16)x9" UM_DB="Ua$(openssl rand -hex 16)y7" \
    awk '/^UM_SA_PASSWORD=/{print "UM_SA_PASSWORD=" ENVIRON["UM_SA"]; next}
         /^UM_DB_PASSWORD=/{print "UM_DB_PASSWORD=" ENVIRON["UM_DB"]; next} {print}' "$BASE/.env.example" \
    | sudo tee "$BASE/.env" >/dev/null
  sudo chmod 600 "$BASE/.env"
  sudo sed -i "s#^UM_PUBLIC_PORT=.*#UM_PUBLIC_PORT=$PUBLIC_PORT#" "$BASE/.env"
  mark ENV created
}

env_set() {
  if sudo grep -q "^$1=" "$BASE/.env"; then
    sudo sed -i "s#^$1=.*#$1=$2#" "$BASE/.env"
  else
    echo "$1=$2" | sudo tee -a "$BASE/.env" >/dev/null
  fi
}

load_env() {
  set -a
  # shellcheck disable=SC1090
  source <(sudo cat "$BASE/.env")
  set +a
}

deploy_image() {
  local started=$SECONDS
  if sudo docker build -t "urbanmanagement-app:$RUN_ID" -t urbanmanagement-app:latest "$RELEASE" >/tmp/um-build.log 2>&1; then
    mark IMAGE "urbanmanagement-app:$RUN_ID"
    mark IMAGE_BUILD_S "$((SECONDS - started))"
    rm -f /tmp/um-build.log
  else
    tail -n 20 /tmp/um-build.log
    fail docker-build
  fi
}

deploy_infra() {
  local started=$SECONDS
  if dc up -d --wait --wait-timeout 300 mssql redis >/tmp/um-up.log 2>&1; then
    mark INFRA healthy
    mark INFRA_WAIT_S "$((SECONDS - started))"
  else
    tail -n 20 /tmp/um-up.log
    fail infra-up
  fi
  rm -f /tmp/um-up.log
}

deploy_database() {
  if [ "$RESET" = yes ]; then
    # shellcheck disable=SC2086
    dc stop um-gateway $APP_ROLES >/dev/null 2>&1 || true
    sudo docker rm -f urbanmanagement-um-app-1 >/dev/null 2>&1 || true
    sqlsa >/tmp/um-sql.out 2>&1 <<'SQL' || { head -n 20 /tmp/um-sql.out; rm -f /tmp/um-sql.out; fail db-reset; }
IF DB_ID(N'UrbanManagement') IS NOT NULL
BEGIN
  ALTER DATABASE [UrbanManagement] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE [UrbanManagement];
END
GO
SQL
    mark DB_RESET done
  fi
  sqlsa >/tmp/um-sql.out 2>&1 <<SQL || { head -n 20 /tmp/um-sql.out; rm -f /tmp/um-sql.out; fail db-setup; }
SET NOCOUNT ON;
IF DB_ID(N'UrbanManagement') IS NULL CREATE DATABASE [UrbanManagement] COLLATE Chinese_PRC_CI_AS;
GO
IF SUSER_ID(N'um_app') IS NULL CREATE LOGIN [um_app] WITH PASSWORD = N'$UM_DB_PASSWORD', DEFAULT_DATABASE = [UrbanManagement], CHECK_POLICY = ON;
ELSE ALTER LOGIN [um_app] WITH PASSWORD = N'$UM_DB_PASSWORD';
GO
USE [UrbanManagement];
IF USER_ID(N'um_app') IS NULL CREATE USER [um_app] FOR LOGIN [um_app];
ALTER ROLE db_owner ADD MEMBER [um_app];
GO
SELECT 'DB_COLLATION=' + CONVERT(nvarchar(128), DATABASEPROPERTYEX(N'UrbanManagement', 'Collation'));
GO
SQL
  mark DB_COLLATION "$(sed -n 's/^DB_COLLATION=//p' /tmp/um-sql.out | tr -d '\r')"
  rm -f /tmp/um-sql.out
  mark DB_LOGIN um_app
}

user_rows() {
  sqlsa 2>/dev/null <<'SQL' | sed -n 's/^USER_ROWS=//p' | tr -d '\r'
SET NOCOUNT ON;
USE [UrbanManagement];
SELECT 'USER_ROWS=' + CONVERT(varchar(20), ISNULL(SUM(p.rows), 0))
FROM sys.tables t JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE t.is_ms_shipped = 0 AND t.name <> N'__EFMigrationsHistory';
GO
SQL
}

deploy_import() {
  local rows
  rows="$(user_rows)"
  mark ROWS_BEFORE_IMPORT "${rows:-unknown}"
  if [ "${rows:-0}" != "0" ]; then
    mark IMPORT skipped-nonempty
    return
  fi
  sudo test -f "$STAGE/source.db" || fail source-missing
  local dir="$BASE/import" report="report-$RUN_ID.json" started=$SECONDS
  sudo install -d -o 1654 -g 1654 -m 750 "$dir"
  sudo install -o 1654 -g 1654 -m 640 "$STAGE/source.db" "$dir/source-$RUN_ID.db"
  # The target connection comes from the service's own ConnectionStrings__Default; nothing secret on this host's argv.
  # um-worker: has the Uploads mount the import checks attachments against.
  dc run --rm --no-deps -T -v "$dir:/import" --entrypoint sh um-worker -c \
    "UM_IMPORT_TARGET=\"\$ConnectionStrings__Default\" exec dotnet /app/tools/import/UrbanManagement.DataImport.dll import --source /import/source-$RUN_ID.db --legacy-storage-root '$LEGACY_ROOT' --uploads-root /app/Uploads --report /import/$report" \
    >/tmp/um-import.log 2>&1
  local code=$?
  mark IMPORT_EXIT "$code"
  mark IMPORT_S "$((SECONDS - started))"
  sudo python3 - "$dir/$report" <<'PY'
import json, sys
try:
    r = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as e:
    print('@@ IMPORT_REPORT=unreadable'); sys.exit(0)
g = lambda k: r.get(k, r.get(k[0].lower() + k[1:]))
tables = g('Tables') or []
def row_count(t):
    for k in ('Rows', 'rows', 'SourceRows', 'sourceRows'):
        if isinstance(t.get(k), int):
            return t[k]
    return 0
rows = sum(row_count(t) for t in tables if isinstance(t, dict))
checks = g('Checks') or []
failed = [c for c in checks if not c.get('Passed', c.get('passed', True))]
print('@@ IMPORT_RESULT=%s' % g('Result'))
print('@@ IMPORT_TABLES=%d' % len(tables))
print('@@ IMPORT_SOURCE_ROWS=%d' % rows)
print('@@ IMPORT_BLOCKING=%d' % len(g('Blocking') or []))
print('@@ IMPORT_WARNINGS=%d' % len(g('Warnings') or []))
print('@@ IMPORT_PATH_ANOMALIES=%d' % len(g('PathAnomalies') or []))
print('@@ IMPORT_CHECKS=%d' % len(checks))
print('@@ IMPORT_CHECKS_FAILED=%d' % len(failed))
print('@@ IMPORT_MISSING_ATTACHMENTS=%d' % len(g('MissingAttachments') or []))
PY
  tail -n 30 /tmp/um-import.log | grep -v -i 'password=' 
  rm -f /tmp/um-import.log
  if [ "$code" -eq 0 ]; then mark IMPORT done; else mark IMPORT failed; fail import; fi
}

deploy_app() {
  # up waits for um-migrator (service_completed_successfully) before starting the roles;
  # --remove-orphans drops the Phase 1 um-app container.
  if dc up -d --remove-orphans >/tmp/um-up.log 2>&1; then mark APP_UP yes; else tail -n 20 /tmp/um-up.log; fail app-up; fi
  rm -f /tmp/um-up.log
}

http_code() { curl -s -o /dev/null -m 10 -w '%{http_code}' "$@" 2>/dev/null || true; }

# HTTP status of a request made inside a role container (the aspnet image has bash but no curl).
role_http() { peer_http "$1" 127.0.0.1 "$2" "$3"; }

# HTTP status of a request from container $1 to host $2 port 8080 on the compose network.
peer_http() {
  dc exec -T "$1" timeout 10 bash -c \
    'exec 3<>/dev/tcp/$0/8080 && printf "%s %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n" "$1" "$2" "$0" >&3 && head -n 1 <&3' \
    "$2" "$3" "$4" 2>/dev/null | awk '{print $2}' | tr -d '\r'
}

role_key() { echo "${1#um-}" | tr '[:lower:]-' '[:upper:]_'; }

svc_exec() { dc exec -T "$1" sh -c "$2" 2>/dev/null | tr -d '\r'; }

checks() {
  check_mount || mark UPLOADS_MOUNT_CHECK failed
  local gw="http://127.0.0.1:$PUBLIC_PORT" started=$SECONDS ready=""
  for _ in $(seq 1 60); do
    ready="$(http_code "$gw/health/ready")"
    [ "$ready" = 200 ] && break
    sleep 3
  done
  mark READY_HTTP "${ready:-none}"
  mark READY_WAIT_S "$((SECONDS - started))"
  mark GW_HEALTH_HTTP "$(http_code "$gw/health/gateway")"
  mark LIVE_HTTP "$(http_code "$gw/health/live")"
  mark ROOT_HTTP "$(http_code "$gw/")"
  local vm_ip
  vm_ip="$(hostname -I | awk '{print $1}')"
  mark VM_IP "$vm_ip"
  mark VM_IP_READY_HTTP "$(http_code "http://$vm_ip:$PUBLIC_PORT/health/ready")"

  # Routing: only attachment maps tus; only realtime maps the hub (GET without connection id => 400, unmapped => 404).
  local tus_headers
  tus_headers="$(curl -s -o /dev/null -D - -m 10 -X OPTIONS -H 'Tus-Resumable: 1.0.0' "$gw/api/urban-attachment/tus/" 2>/dev/null | tr -d '\r')"
  mark GW_TUS_OPTIONS_HTTP "$(printf '%s\n' "$tus_headers" | awk 'NR==1{print $2}')"
  mark GW_TUS_VERSION "$(printf '%s\n' "$tus_headers" | sed -n 's/^[Tt]us-[Vv]ersion: *//p' | head -n 1)"
  mark GW_HUB_HTTP "$(http_code "$gw/hubs/devicestatus")"
  mark GW_NEGOTIATE_HTTP "$(http_code -X POST "$gw/hubs/devicestatus/negotiate?negotiateVersion=1")"
  mark GW_INTERNAL_HTTP "$(http_code "$gw/internal/client-log/online-clients")"
  mark GW_CLIENT_LOG_APP_HTTP "$(http_code "$gw/api/app/client-log/online-clients")"

  local svc key
  for svc in $APP_ROLES; do
    key="$(role_key "$svc")"
    mark "ROLE_${key}_READY" "$(role_http "$svc" GET /health/ready)"
    mark "ROLE_${key}_HUB" "$(role_http "$svc" GET /hubs/devicestatus)"
    mark "ROLE_${key}_UPLOADS_FS" "$(svc_exec "$svc" 'stat -f -c %T /app/Uploads')"
  done
  mark ROLE_INGEST_TUS_OPTIONS "$(role_http um-ingest OPTIONS /api/urban-attachment/tus/)"
  mark ROLE_ATTACHMENT_TUS_OPTIONS "$(role_http um-attachment OPTIONS /api/urban-attachment/tus/)"
  mark ROLE_ADMIN_ROOT "$(role_http um-admin GET /)"
  mark ROLE_REALTIME_ROOT "$(role_http um-realtime GET /)"
  mark ADMIN_TO_REALTIME_INTERNAL "$(peer_http um-admin um-realtime GET /internal/client-log/online-clients)"
  mark ADMIN_INTERNAL_LOCAL "$(role_http um-admin GET /internal/client-log/online-clients)"

  local migrator_id
  migrator_id="$(dc ps -a -q um-migrator 2>/dev/null | head -n 1)"
  mark MIGRATOR_STATE "$( [ -n "$migrator_id" ] && sudo docker inspect -f '{{.State.Status}}' "$migrator_id" 2>/dev/null || echo missing)"
  mark MIGRATOR_EXIT "$( [ -n "$migrator_id" ] && sudo docker inspect -f '{{.State.ExitCode}}' "$migrator_id" 2>/dev/null || echo none)"
  mark UM_APP_PRESENT "$(sudo docker ps -a --format '{{.Names}}' | grep -cx 'urbanmanagement-um-app-1' || true)"

  mark BACKPLANE_CHANNELS "$(dc exec -T redis redis-cli --raw PUBSUB CHANNELS 'UM:signalr*' 2>/dev/null | grep -c . || true)"

  mark CONTAINER_TZ "$(svc_exec um-admin 'date +%Z')"
  mark CONTAINER_UPLOADS_SAMPLE_READ "$(svc_exec um-admin 'f=$(find /app/Uploads -mindepth 2 -maxdepth 2 -type f -name "*.jpg" 2>/dev/null | head -n 1); [ -n "$f" ] && head -c 4096 "$f" >/dev/null && echo ok || echo none')"
  mark CONTAINER_TUS_WRITABLE "$(svc_exec um-attachment 'test -w /app/tus && echo yes || echo no')"
  mark CONTAINER_KEYS "$(svc_exec um-admin 'ls /app/keys 2>/dev/null | wc -l')"
  mark CONTAINER_SECRET_JSON "$(svc_exec um-ingest 'test -e /app/appsettings.secret.json && echo present || echo absent')"

  local err_pattern='(ERR|FTL)\]|\[(Error|Fatal)|\| +fail:' logs total_err=0 n
  for svc in um-migrator $APP_ROLES um-gateway; do
    key="$(role_key "$svc")"
    logs="$(dc logs --no-color "$svc" 2>/dev/null)"
    n="$(printf '%s\n' "$logs" | grep -c -E "$err_pattern" || true)"
    total_err=$((total_err + n))
    mark "LOG_${key}_ERRORS" "$n"
    mark "LOG_${key}_ROLES" "$(printf '%s\n' "$logs" | sed -n 's/.*Hosting roles: //p' | head -n 1 | cut -c1-60)"
    mark "LOG_${key}_WORKERS_SKIPPED" "$(printf '%s\n' "$logs" | grep -c 'Background workers not registered' || true)"
    mark "LOG_${key}_SNAPSHOT_REGISTERED" "$(printf '%s\n' "$logs" | grep -c 'ClientStatusSnapshotBackgroundWorker registered' || true)"
    mark "LOG_${key}_GOVSYNC_REGISTERED" "$(printf '%s\n' "$logs" | grep -c 'GovSyncBackgroundWorker registered' || true)"
    mark "LOG_${key}_MIGRATED" "$(printf '%s\n' "$logs" | grep -c 'Database migration completed' || true)"
    printf '%s\n' "$logs" | grep -E "$err_pattern" | head -n 3 | cut -c1-300 | sed "s/^/LOG_ERR_SAMPLE[$svc]: /"
  done
  mark LOG_ERRORS "$total_err"

  mark DB_USER_ROWS "$(user_rows)"
  mark SERVICES "$(dc ps -a --format '{{.Service}}:{{.State}}' 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
  mark DOCKER_MEM "$(sudo docker stats --no-stream --format '{{.Name}}={{.MemUsage}}' 2>/dev/null | sed 's/ //g; s/urbanmanagement-//; s/-1=/=/' | tr '\n' ',' | sed 's/,$//')"
  local avail
  avail="$(free -m | awk '/^Mem:/{print $7}')"
  mark MEM_AVAILABLE_MB "$avail"
  mark MEM_MIN_MB "$MEM_MIN_MB"
  mark MEM_OK "$( [ "${avail:-0}" -ge "$MEM_MIN_MB" ] && echo yes || echo no)"
  mark MSSQL_MEMORY_LIMIT_MB "$(svc_exec mssql 'echo $MSSQL_MEMORY_LIMIT_MB')"
  mark DISK_AVAIL_ROOT "$(df -h / | awk 'NR==2{print $4}')"
}

case "$MODE" in
  deploy)
    deploy_release
    deploy_mount
    check_mount || fail uploads-mount
    deploy_config
    deploy_env
    env_set UM_MSSQL_MEMORY_LIMIT_MB "$MSSQL_MEM_MB"
    load_env
    deploy_image
    deploy_infra
    deploy_database
    deploy_import
    deploy_app
    checks
    sudo rm -rf "$STAGE"
    ;;
  verify)
    sudo test -f "$BASE/.env" || fail not-deployed
    load_env
    checks
    ;;
  *) fail bad-mode ;;
esac
mark DONE yes
