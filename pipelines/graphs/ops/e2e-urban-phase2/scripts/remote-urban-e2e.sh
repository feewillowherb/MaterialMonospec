#!/usr/bin/env bash
# e2e-urban-phase2 helpers on the Docker VM. Never echoes secrets (sa password stays in the mssql container env).
#   approve-in-ingest <body-base64>                               POST approve inside um-ingest (backplane path)
#   evidence-cleanup <proId> <clientId> <licenseNo> <recA> <recB> which role logged each push, then delete probe data
set -uo pipefail

BASE=/opt/urbanmanagement
UPLOADS_MNT=/srv/um-uploads
SQLCMD=/opt/mssql-tools18/bin/sqlcmd
mark() { echo "@@ $1=$2"; }
dc() { sudo docker compose --project-directory "$BASE" -f "$BASE/compose.yaml" "$@"; }
sqlsa() { dc exec -T mssql bash -c "SQLCMDPASSWORD=\"\$MSSQL_SA_PASSWORD\" $SQLCMD -C -S localhost -U sa -d UrbanManagement -b -h -1 -W -i /dev/stdin"; }

MODE="$1"; shift
case "$MODE" in
  approve-in-ingest)
    # The body travels base64-encoded; Content-Length is computed on bytes inside the container.
    status="$(dc exec -T um-ingest timeout 20 bash -c '
      body="$(echo "$0" | base64 -d)"
      len=$(printf "%s" "$body" | wc -c)
      exec 3<>/dev/tcp/127.0.0.1/8080 || exit 1
      printf "POST /api/app/urban-weighing-record/approve HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: %s\r\nConnection: close\r\n\r\n%s" "$len" "$body" >&3
      head -n 1 <&3' "$1" 2>/dev/null | awk '{print $2}' | tr -d '\r')"
    mark INGEST_APPROVE_HTTP "${status:-none}"
    ;;

  evidence-cleanup)
    PRO_ID="$1"; CLIENT_ID="$2"; LICENSE="$3"; REC_A="$4"; REC_B="$5"
    case "$LICENSE" in E2E-*) ;; *) mark CLEANUP refused-license; exit 1 ;; esac

    for svc in um-ingest um-console um-worker; do
      key="$(echo "${svc#um-}" | tr '[:lower:]' '[:upper:]')"
      logs="$(dc logs --no-color --since 30m "$svc" 2>/dev/null)"
      mark "PUSH_LOG_${key}_A" "$(printf '%s\n' "$logs" | grep -c "Pushed server approval sync for ClientRecordId=$REC_A" || true)"
      mark "PUSH_LOG_${key}_B" "$(printf '%s\n' "$logs" | grep -ci "Pushed server approval sync for ClientRecordId=$REC_B" || true)"
      mark "LOG_${key}_ERRORS_30M" "$(printf '%s\n' "$logs" | grep -c -E '(ERR|FTL)\]|\[(Error|Fatal)' || true)"
      printf '%s\n' "$logs" | grep -E '(ERR|FTL)\]|\[(Error|Fatal)' | head -n 3 | cut -c1-300 | sed "s/^/LOG_ERR_SAMPLE[$svc]: /"
    done

    count_sql="SET NOCOUNT ON;
SELECT 'ROWS_RECORDS=' + CONVERT(varchar(20), COUNT(*)) FROM UrbanWeighingRecords WHERE ProId = '$PRO_ID';
SELECT 'ROWS_ATTACHMENTS=' + CONVERT(varchar(20), COUNT(*)) FROM AttachmentFiles WHERE LocalPath LIKE '%$LICENSE/%' OR LocalPath LIKE '%$LICENSE\\%';
SELECT 'ROWS_ONLINE=' + CONVERT(varchar(20), (SELECT COUNT(*) FROM ClientOnlineStatuses WHERE ProId = '$PRO_ID') + (SELECT COUNT(*) FROM ClientDeviceOnlineStatuses WHERE ProId = '$PRO_ID'));
GO"
    before="$(echo "$count_sql" | sqlsa 2>&1 | tr -d '\r')"
    for k in ROWS_RECORDS ROWS_ATTACHMENTS ROWS_ONLINE; do
      mark "BEFORE_$k" "$(printf '%s\n' "$before" | sed -n "s/^$k=//p")"
    done
    mark BEFORE_FILES "$(sudo find "$UPLOADS_MNT/$LICENSE" -type f 2>/dev/null | wc -l)"

    sqlsa >/tmp/um-e2e-sql.out 2>&1 <<SQL
SET NOCOUNT ON;
DELETE a FROM AttachmentFiles a
  WHERE a.Id IN (SELECT j.AttachmentFileId FROM UrbanWeighingRecordAttachments j
                 JOIN UrbanWeighingRecords r ON r.Id = j.UrbanWeighingRecordId WHERE r.ProId = '$PRO_ID');
DELETE j FROM UrbanWeighingRecordAttachments j
  JOIN UrbanWeighingRecords r ON r.Id = j.UrbanWeighingRecordId WHERE r.ProId = '$PRO_ID';
DELETE FROM UrbanWeighingRecords WHERE ProId = '$PRO_ID';
DELETE FROM AttachmentFiles WHERE LocalPath LIKE '%$LICENSE/%' OR LocalPath LIKE '%$LICENSE\\%';
DELETE FROM ClientOnlineStatuses WHERE ProId = '$PRO_ID';
DELETE FROM ClientDeviceOnlineStatuses WHERE ProId = '$PRO_ID';
GO
SQL
    mark CLEANUP_SQL_EXIT "$?"
    head -n 5 /tmp/um-e2e-sql.out | sed 's/^/SQL_OUT: /'; rm -f /tmp/um-e2e-sql.out
    sudo rm -rf --one-file-system "${UPLOADS_MNT:?}/$LICENSE"
    keys="$(dc exec -T redis sh -c "redis-cli --scan --pattern '*$PRO_ID*'; redis-cli --scan --pattern '*$CLIENT_ID*'" 2>/dev/null | tr -d '\r' | sort -u)"
    mark REDIS_KEYS_FOUND "$(printf '%s\n' "$keys" | grep -c . || true)"
    if [ -n "$keys" ]; then
      printf '%s\n' "$keys" | dc exec -T redis sh -c 'xargs -r redis-cli DEL' >/dev/null 2>&1
    fi

    after="$(echo "$count_sql" | sqlsa 2>&1 | tr -d '\r')"
    for k in ROWS_RECORDS ROWS_ATTACHMENTS ROWS_ONLINE; do
      mark "AFTER_$k" "$(printf '%s\n' "$after" | sed -n "s/^$k=//p")"
    done
    mark AFTER_FILES "$(sudo find "$UPLOADS_MNT/$LICENSE" -type f 2>/dev/null | wc -l)"
    mark AFTER_REDIS_KEYS "$(dc exec -T redis sh -c "redis-cli --scan --pattern '*$PRO_ID*'; redis-cli --scan --pattern '*$CLIENT_ID*'" 2>/dev/null | grep -c . || true)"
    ;;

  *) mark FAILED_AT bad-mode; exit 1 ;;
esac
mark DONE yes
