#!/usr/bin/env bash
# urban-cutover helpers on the Docker VM. Never echoes secrets.
#   check
#   cutover <run-id>          # source already at /tmp/um-cutover/<run-id>/source.db
set -uo pipefail

BASE=/opt/urbanmanagement
UPLOADS_MNT=/srv/um-uploads
LEGACY_ROOT="${LEGACY_ROOT:-C:/wwwroot/UrbanManagement/Uploads}"
mark() { echo "@@ $1=$2"; }
dc() { sudo docker compose --project-directory "$BASE" -f "$BASE/compose.yaml" "$@"; }
fail() { mark FAILED_AT "$1"; exit 1; }

MODE="$1"; shift
case "$MODE" in
  check)
    mark ADDR "$(ip -4 -br addr show eth0 | awk '{print $3}')"
    mark ROUTE "$(ip route | awk '/default/{print $3; exit}')"
    mark MOUNT "$(stat -f -c %T "$UPLOADS_MNT" 2>/dev/null || echo none)"
    mark SERVICES "$(dc ps -a --format '{{.Service}}:{{.State}}' 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
    for svc in um-ingest um-ingest-2 um-attachment um-realtime um-admin um-worker um-gateway; do
      key="$(echo "${svc#um-}" | tr '[:lower:]-' '[:upper:]_')"
      code="$(dc exec -T "$svc" timeout 8 bash -c \
        'exec 3<>/dev/tcp/127.0.0.1/8080 && printf "GET /health/ready HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" >&3 && head -n 1 <&3' \
        2>/dev/null | awk '{print $2}' | tr -d '\r')"
      mark "ROLE_${key}_READY" "${code:-none}"
    done
    mark ENV_SYNC "$(grep -E '^UM_BASEPLATFORM_SYNC_ENABLED=' "$BASE/.env" 2>/dev/null | cut -d= -f2- | tr -d '\r')"
    mark ENV_POLL "$(grep -E '^UM_BACKGROUND_POLLING=' "$BASE/.env" 2>/dev/null | cut -d= -f2- | tr -d '\r')"
    logs="$(dc logs --no-color --since 10m um-worker 2>/dev/null || true)"
    mark LOG_WORKER_GOVSYNC "$(printf '%s\n' "$logs" | grep -c 'GovSyncBackgroundWorker registered' || true)"
    mark DONE yes
    ;;

  cutover)
    RUN_ID="$1"
    STAGE="/tmp/um-cutover/$RUN_ID"
    sudo test -f "$STAGE/source.db" || fail source-missing

    # Refuse to enable new sync while the old IIS entry might still be live (caller also checks).
    mark ENV_SYNC_BEFORE "$(grep -E '^UM_BASEPLATFORM_SYNC_ENABLED=' "$BASE/.env" 2>/dev/null | cut -d= -f2- | tr -d '\r')"

    # Drop and recreate application database (SA password stays inside the mssql container).
    mark DROP_START yes
    dc exec -T mssql bash -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -b -Q "
IF DB_ID('"'"'UrbanManagement'"'"') IS NOT NULL BEGIN
  ALTER DATABASE UrbanManagement SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE UrbanManagement;
END"' || fail drop-db
    mark DROP_OK yes

    dc up -d --no-deps um-migrator || fail migrator-up
    for _ in $(seq 1 60); do
      st="$(dc ps -a --format '{{.Service}} {{.State}} {{.ExitCode}}' | awk '$1=="um-migrator"{print $2" "$3; exit}')"
      echo "$st" | grep -q '^exited 0$' && break
      echo "$st" | grep -q '^exited ' && fail migrator-failed
      sleep 3
    done
    mark MIGRATOR_EXIT 0

    dir="$BASE/import"
    report="cutover-$RUN_ID.json"
    sudo mkdir -p "$dir"
    sudo install -o 1654 -g 1654 -m 640 "$STAGE/source.db" "$dir/source-$RUN_ID.db"
    dc run --rm --no-deps -T -v "$dir:/import" --entrypoint sh um-worker -c \
      "UM_IMPORT_TARGET=\"\$ConnectionStrings__Default\" exec dotnet /app/tools/import/UrbanManagement.DataImport.dll import --source /import/source-$RUN_ID.db --legacy-storage-root '$LEGACY_ROOT' --uploads-root /app/Uploads --report /import/$report" \
      >/tmp/um-cutover-import.log 2>&1
    code=$?
    mark IMPORT_EXIT "$code"
    if [ -f "$dir/$report" ]; then
      mark IMPORT_RESULT "$(sudo python3 - <<PY
import json
p='$dir/$report'
d=json.load(open(p))
print(d.get('result') or d.get('status') or 'unknown')
PY
)"
    else
      mark IMPORT_RESULT missing
    fi
    tail -n 40 /tmp/um-cutover-import.log | grep -v -i 'password=' | sed 's/^/IMPORT_LOG: /'
    [ "$code" -eq 0 ] || fail import

    # Enable sync only on um-worker via .env, then recreate that one service.
    sudo sed -i 's/^UM_BASEPLATFORM_SYNC_ENABLED=.*/UM_BASEPLATFORM_SYNC_ENABLED=true/' "$BASE/.env"
    sudo sed -i 's/^UM_BACKGROUND_POLLING=.*/UM_BACKGROUND_POLLING=true/' "$BASE/.env"
    grep -q '^UM_BASEPLATFORM_SYNC_ENABLED=' "$BASE/.env" || echo 'UM_BASEPLATFORM_SYNC_ENABLED=true' | sudo tee -a "$BASE/.env" >/dev/null
    grep -q '^UM_BACKGROUND_POLLING=' "$BASE/.env" || echo 'UM_BACKGROUND_POLLING=true' | sudo tee -a "$BASE/.env" >/dev/null
    dc up -d --no-deps --force-recreate um-worker || fail worker-up
    sleep 8
    logs="$(dc logs --no-color --since 2m um-worker 2>/dev/null || true)"
    mark LOG_WORKER_GOVSYNC "$(printf '%s\n' "$logs" | grep -c 'GovSyncBackgroundWorker registered' || true)"
    mark ENV_SYNC_AFTER "$(grep -E '^UM_BASEPLATFORM_SYNC_ENABLED=' "$BASE/.env" | cut -d= -f2- | tr -d '\r')"
    mark ENV_POLL_AFTER "$(grep -E '^UM_BACKGROUND_POLLING=' "$BASE/.env" | cut -d= -f2- | tr -d '\r')"
    mark READY_HTTP "$(curl -s -o /dev/null -m 10 -w '%{http_code}' http://127.0.0.1:5333/health/ready || true)"
    mark DONE yes
    ;;

  *) mark FAILED_AT bad-mode; exit 1 ;;
esac
