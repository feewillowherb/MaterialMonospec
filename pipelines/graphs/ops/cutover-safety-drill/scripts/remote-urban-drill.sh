#!/usr/bin/env bash
# Cutover safety drill on the Docker VM (non-destructive for the live database):
#   1. one full backup now (mssql-backup sidecar)        2. restore it into a scratch database, CHECKDB, compare rows, drop it
#   3. rollback export: newest import source (pre-cutover SQLite copy) + all SQL Server rows -> SQLite inside a throwaway container
# Never echo secrets: the sa password stays in the sidecar environment; the app connection string in um-worker's.
set -uo pipefail

RUN_ID="$1"
BASE=/opt/urbanmanagement
mark() { echo "@@ $1=$2"; }
dc() { sudo docker compose --project-directory "$BASE" -f "$BASE/compose.yaml" "$@"; }

if sudo -n true 2>/dev/null; then mark SUDO_NOPASSWD yes; else mark SUDO_NOPASSWD no; exit 1; fi
mark BACKUP_SIDECAR "$(dc ps --format '{{.State}}' mssql-backup 2>/dev/null | head -n 1)"

started=$SECONDS
dc exec -T mssql-backup bash /opt/um/mssql-backup.sh once 2>&1 | grep -E '^@@ |backup' | tr -d '\r'
mark BACKUP_S "$((SECONDS - started))"

started=$SECONDS
dc exec -T mssql-backup bash /opt/um/mssql-backup.sh verify-restore 2>&1 | grep -E '^@@ ' | tr -d '\r'
mark VERIFY_S "$((SECONDS - started))"
mark BACKUP_FILES "$(dc exec -T mssql-backup sh -c 'ls -1 /var/opt/mssql/backup/*.bak 2>/dev/null | wc -l' | tr -d '\r')"
mark BACKUP_DIR_BYTES "$(dc exec -T mssql-backup sh -c 'du -sb /var/opt/mssql/backup | cut -f1' | tr -d '\r')"
mark DISK_AVAIL_ROOT "$(df -h / | awk 'NR==2{print $4}')"

# import/ is 750 for the container user: expand the glob as root.
template="$(sudo sh -c "ls -1t $BASE/import/source-*.db 2>/dev/null" | head -n 1)"
if [ -z "$template" ]; then
  mark EXPORT_TEMPLATE none
  mark DONE yes
  exit 0
fi
mark EXPORT_TEMPLATE "$(basename "$template")"
report="rollback-report-$RUN_ID.json"
started=$SECONDS
# Output stays inside the --rm container; only the JSON report is kept under $BASE/import.
dc run --rm --no-deps -T -v "$BASE/import:/import" --entrypoint sh um-worker -c \
  "UM_IMPORT_TARGET=\"\$ConnectionStrings__Default\" exec dotnet /app/tools/import/UrbanManagement.DataImport.dll export-sqlite --source /import/$(basename "$template") --output /tmp/rollback-$RUN_ID.db --report /import/$report" \
  >/tmp/um-export.log 2>&1
code=$?
mark EXPORT_EXIT "$code"
mark EXPORT_S "$((SECONDS - started))"
tail -n 15 /tmp/um-export.log | grep -v -i 'password=' | sed 's/^/EXPORT_LOG: /'
rm -f /tmp/um-export.log
sudo python3 - "$BASE/import/$report" <<'PY'
import json, sys
try:
    r = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception:
    print('@@ EXPORT_REPORT=unreadable'); sys.exit(0)
g = lambda k: r.get(k, r.get(k[0].lower() + k[1:]))
checks = g('Checks') or []
p = lambda c, k: c.get(k, c.get(k.lower()))
failed = [c for c in checks if not p(c, 'Passed')]
tables = g('Tables') or []
print('@@ EXPORT_RESULT=%s' % g('Result'))
print('@@ EXPORT_TABLES=%d' % len(tables))
print('@@ EXPORT_ROWS=%d' % sum((p(t, 'Rows') or 0) for t in tables))
print('@@ EXPORT_BLOCKING=%d' % len(g('Blocking') or []))
print('@@ EXPORT_WARNINGS=%d' % len(g('Warnings') or []))
print('@@ EXPORT_CHECKS=%d' % len(checks))
print('@@ EXPORT_CHECKS_FAILED=%d' % len(failed))
print('@@ EXPORT_FORMAT_CHECKS=%d' % sum(1 for c in checks if p(c, 'Name') == 'storage-format'))
for c in failed[:5]:
    print('EXPORT_FAILED: %s %s %s' % (p(c, 'Name'), p(c, 'Table'), (p(c, 'Detail') or '')[:200]))
for f in (g('Blocking') or [])[:5]:
    print('EXPORT_BLOCKING: %s.%s %s' % (p(f, 'Table'), p(f, 'Column'), p(f, 'Message')))
PY
mark DONE yes
