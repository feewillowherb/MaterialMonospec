## ADDED Requirements

### Requirement: Scheduled database backup

The compose definition SHALL include an `mssql-backup` service that shares the `um-mssql` volume, publishes no port and takes a full backup of the `UrbanManagement` database daily at `UM_BACKUP_AT` (default `02:30`, container time zone `Asia/Shanghai`) with `CHECKSUM` followed by `RESTORE VERIFYONLY`, keeping the newest `UM_BACKUP_KEEP` files (default 7). The sa password MUST reach `sqlcmd` only through the environment, never through command-line arguments. The service SHALL also provide a restore check that restores a backup into a scratch database, runs `DBCC CHECKDB`, compares user-table row counts with the count recorded before the backup, and drops the scratch database; and a replace-restore mode used by a host script that requires an explicit `--confirm` and stops the gateway and application roles while restoring.

#### Scenario: Daily backup with retention

- **WHEN** the scheduled time is reached and the backup succeeds
- **THEN** a new `.bak` file and its recorded row count SHALL exist under `/var/opt/mssql/backup`
- **AND** files beyond the newest `UM_BACKUP_KEEP` SHALL be deleted

#### Scenario: Failed backup leaves no partial file

- **WHEN** `BACKUP DATABASE` or `RESTORE VERIFYONLY` fails
- **THEN** the incomplete backup file SHALL be deleted and the failure SHALL be logged

#### Scenario: Restore check does not touch the live database

- **WHEN** the restore check runs
- **THEN** only the scratch database SHALL be created and it SHALL be dropped before the check ends
- **AND** the check SHALL report success only if `DBCC CHECKDB` passes and the row counts match

#### Scenario: Replace restore requires confirmation

- **WHEN** the host restore script is run without `--confirm`
- **THEN** it SHALL exit without stopping any service or changing the database
