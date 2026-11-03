#!/usr/bin/env bash
# UrbanManagement Phase 1 on the Docker VM: release -> SMB automount -> config -> .env -> image ->
# mssql/redis -> database/login -> import -> um-app -> checks. "verify" runs the checks only.
# Never echo secrets: passwords live only in $BASE/.env (600 root) and container environments.
# stdin line 1 (optional): base64 of the local appsettings.secret.json, used only when the IIS config is unreadable.
set -uo pipefail

MODE="$1"; RUN_ID="$2"; HOST="$3"; UPLOADS_SHARE="$4"; WWWROOT_SHARE="$5"; CRED="$6"
RESET="$7"; LEGACY_ROOT="$8"; PUBLIC_PORT="$9"; IIS_SITE_DIR="${10}"

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
    dc stop um-app >/dev/null 2>&1 || true
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
  dc run --rm --no-deps -T -v "$dir:/import" --entrypoint sh um-app -c \
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
  if dc up -d um-app >/tmp/um-up.log 2>&1; then mark APP_UP yes; else tail -n 20 /tmp/um-up.log; fail app-up; fi
  rm -f /tmp/um-up.log
}

http_code() { curl -s -o /dev/null -m 10 -w '%{http_code}' "$1" 2>/dev/null || true; }

checks() {
  check_mount || mark UPLOADS_MOUNT_CHECK failed
  local started=$SECONDS ready=""
  for _ in $(seq 1 60); do
    ready="$(http_code "http://127.0.0.1:$PUBLIC_PORT/health/ready")"
    [ "$ready" = 200 ] && break
    sleep 3
  done
  mark READY_HTTP "${ready:-none}"
  mark READY_WAIT_S "$((SECONDS - started))"
  mark LIVE_HTTP "$(http_code "http://127.0.0.1:$PUBLIC_PORT/health/live")"
  mark ROOT_HTTP "$(http_code "http://127.0.0.1:$PUBLIC_PORT/")"
  local vm_ip
  vm_ip="$(hostname -I | awk '{print $1}')"
  mark VM_IP "$vm_ip"
  mark VM_IP_READY_HTTP "$(http_code "http://$vm_ip:$PUBLIC_PORT/health/ready")"

  mark CONTAINER_TZ "$(dc exec -T um-app date +%Z 2>/dev/null | tr -d '\r')"
  mark CONTAINER_UPLOADS_FS "$(dc exec -T um-app stat -f -c %T /app/Uploads 2>/dev/null | tr -d '\r')"
  mark CONTAINER_UPLOADS_SAMPLE_READ "$(dc exec -T um-app sh -c 'f=$(find /app/Uploads -mindepth 2 -maxdepth 2 -type f -name "*.jpg" 2>/dev/null | head -n 1); [ -n "$f" ] && head -c 4096 "$f" >/dev/null && echo ok || echo none' 2>/dev/null | tr -d '\r')"
  mark CONTAINER_TUS_WRITABLE "$(dc exec -T um-app sh -c 'test -w /app/tus && echo yes || echo no' 2>/dev/null | tr -d '\r')"
  mark CONTAINER_KEYS "$(dc exec -T um-app sh -c 'ls /app/keys 2>/dev/null | wc -l' 2>/dev/null | tr -d '\r')"
  mark CONTAINER_SECRET_JSON "$(dc exec -T um-app sh -c 'test -e /app/appsettings.secret.json && echo present || echo absent' 2>/dev/null | tr -d '\r')"

  local logs
  logs="$(dc logs --no-color um-app 2>/dev/null)"
  local err_pattern='(ERR|FTL)\]|\[(Error|Fatal)|\| +fail:'
  mark LOG_LINES "$(printf '%s\n' "$logs" | wc -l)"
  mark LOG_ERRORS "$(printf '%s\n' "$logs" | grep -c -E "$err_pattern" || true)"
  mark LOG_GOVSYNC_LINES "$(printf '%s\n' "$logs" | grep -c -i 'GovSync' || true)"
  printf '%s\n' "$logs" | grep -i 'GovSync' | head -n 3 | cut -c1-300 | sed 's/^/LOG_GOVSYNC_SAMPLE: /'
  printf '%s\n' "$logs" | grep -E "$err_pattern" | head -n 5 | cut -c1-300 | sed 's/^/LOG_ERR_SAMPLE: /'

  mark DB_USER_ROWS "$(user_rows)"
  mark SERVICES "$(dc ps --format '{{.Service}}:{{.State}}' 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
  mark DOCKER_MEM "$(sudo docker stats --no-stream --format '{{.Name}}={{.MemUsage}}' 2>/dev/null | sed 's/ //g' | tr '\n' ',' | sed 's/,$//')"
  mark MEM_AVAILABLE_MB "$(free -m | awk '/^Mem:/{print $7}')"
  mark DISK_AVAIL_ROOT "$(df -h / | awk 'NR==2{print $4}')"
}

case "$MODE" in
  deploy)
    deploy_release
    deploy_mount
    check_mount || fail uploads-mount
    deploy_config
    deploy_env
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
