## REMOVED Requirements

### Requirement: Scheduled database backup

**Reason**: D15 (user, 2026-11-03): the new stack does not need database backups; daily backup is disabled.

**Migration**: Remove the `mssql-backup` service; the deploy graph's `up -d --remove-orphans` removes its container. Rollback to IIS still uses `export-sqlite`.
