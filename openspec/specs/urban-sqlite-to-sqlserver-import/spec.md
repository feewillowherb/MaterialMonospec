# urban-sqlite-to-sqlserver-import Specification

## Purpose
TBD - created by archiving change update-urban-mssql-provider. Update Purpose after archive.
## Requirements
### Requirement: Read-only census of the SQLite source

The `UrbanManagement.DataImport` tool SHALL provide a `census` command that opens the SQLite source in read-only mode and reports, per table mapped by `UrbanManagementDbContext`: row count; for `TotalWeight` and `GoodsWeight` the maximum fractional digits and maximum integer digits; for every column with a configured maximum length the actual maximum length; for every unique index containing string columns the groups that collide when compared case-insensitively; for `AttachmentFile.LocalPath` the count of values containing `\` and of rooted paths with their prefixes; and the source file size. The census MUST NOT modify the source file.

#### Scenario: Census reports blocking issues

- **WHEN** the source contains a `TotalWeight` with 5 fractional digits, or a value longer than its column's maximum length, or two unique-index keys differing only by letter case
- **THEN** the census report SHALL list each issue with table, column and primary key
- **AND** the command SHALL exit with code 1

#### Scenario: Census of a clean source

- **WHEN** the source has no blocking issues
- **THEN** the command SHALL write the report and exit with code 0
- **AND** the source file content SHALL be byte-identical before and after

### Requirement: Import into an empty SQL Server database

The `import` command SHALL run the census first and refuse to continue when it reports blocking issues. It SHALL then apply migrations to the target (connection string taken only from environment variable `UM_IMPORT_TARGET`), refuse to continue if any mapped table already contains rows, and copy all mapped tables in a single transaction. Original primary keys (including identity keys), audit fields, `ConcurrencyStamp`, `ExtraProperties`, and soft-deleted rows SHALL be preserved. If any table fails, the transaction SHALL be rolled back and the target SHALL remain empty.

#### Scenario: Non-empty target is rejected

- **WHEN** the target database already contains at least one row in a mapped table
- **THEN** the import SHALL stop before writing and exit with code 1

#### Scenario: Soft-deleted projects are imported

- **WHEN** the source contains a `GovProject` row with `IsDeleted = 1`
- **THEN** the target SHALL contain that row with the same `Id`, `IsDeleted` and `DeletionTime`

#### Scenario: Identity keys preserved

- **WHEN** the source `WorkSettings` contains a row with `Id = 7`
- **THEN** the target SHALL contain that row with `Id = 7`

#### Scenario: Failure leaves target empty

- **WHEN** a value in any table cannot be converted to its target type
- **THEN** the import SHALL roll back, report table, primary key and column, and exit with code 1
- **AND** every mapped table in the target SHALL contain zero rows

#### Scenario: Obsolete source columns are ignored

- **WHEN** a source table has a column that no longer exists in the model
- **THEN** the import SHALL ignore that column and list it as a warning in the report

### Requirement: Attachment paths normalized during import

During import, `AttachmentFile.LocalPath` SHALL be converted to the persisted relative form (`/` separators, no leading separator). A rooted path under the optional `--legacy-storage-root` SHALL be made relative to that root. Any other rooted path SHALL be imported unchanged and listed in the report as an anomaly.

#### Scenario: Backslash relative path

- **WHEN** the source `LocalPath` is `GDXS001\abc.jpg`
- **THEN** the target `LocalPath` SHALL be `GDXS001/abc.jpg`

#### Scenario: Absolute path under legacy root

- **WHEN** `--legacy-storage-root C:\Services\UrbanManagement\Uploads` is given and the source `LocalPath` is `C:\Services\UrbanManagement\Uploads\GDXS001\abc.jpg`
- **THEN** the target `LocalPath` SHALL be `GDXS001/abc.jpg`

### Requirement: Post-import verification

After the import transaction commits, the tool SHALL verify and report: equal row counts per table; equal sums of `TotalWeight` and `GoodsWeight`; equal minimum and maximum `CreationTime` per table that has that column; and, for up to 50 randomly sampled primary keys per table, equality of every imported column value after conversion (with `LocalPath` compared in normalized form). Any mismatch SHALL make the command exit with code 1. When `--uploads-root` is given, the tool SHALL check that every `AttachmentFile` resolves to an existing file and SHALL list missing files separately without failing the command.

#### Scenario: Successful import verification

- **WHEN** the import completes and all checks match
- **THEN** the report SHALL mark every check as passed and the command SHALL exit with code 0

#### Scenario: Missing attachment files are reported

- **WHEN** `--uploads-root` is given and 3 attachment files do not exist
- **THEN** the report SHALL list those 3 `AttachmentFile` ids and paths
- **AND** the exit code SHALL be determined only by the other checks

### Requirement: Rollback export to SQLite

The `UrbanManagement.DataImport` tool SHALL provide an `export-sqlite` command that takes `--source` (a pre-cutover SQLite copy used as template) and `--output` (a new file path), reads the SQL Server connection string only from `UM_IMPORT_TARGET`, and produces a SQLite file whose model tables contain exactly the SQL Server rows. The command MUST refuse an existing `--output` or one equal to `--source`, MUST NOT modify `--source`, and MUST keep template tables outside the model and `__EFMigrationsHistory` unchanged. All model tables SHALL be replaced in a single transaction. Values SHALL be stored in the formats written by the EF Core SQLite provider, and GUID text case SHALL follow the case found in the template for each column. The command SHALL verify row counts and every row's values by primary key after reading the output back, and SHALL verify that rows present in both files with semantically equal values have identical stored values.

#### Scenario: Export reflects changes made after cutover

- **WHEN** a record that exists in the template has a changed sync status in SQL Server, and another record exists only in SQL Server, and a third exists only in the template
- **THEN** the output SHALL contain the first record with the SQL Server sync status, SHALL contain the second record, and SHALL NOT contain the third
- **AND** the command SHALL exit with code 0 when all checks pass

#### Scenario: Template schema does not fit the model

- **WHEN** a model table is missing in the template, or the template has a required column without default that the model does not have
- **THEN** the command SHALL report a blocking issue, delete the output file and exit with code 1

#### Scenario: Stored formats match the legacy data

- **WHEN** a GUID column in the template stores lower-case text and another stores upper-case text
- **THEN** the output SHALL store each column's GUIDs in the same case as the template
- **AND** the `storage-format` check SHALL fail if any shared row's stored value differs from the template while being semantically equal

