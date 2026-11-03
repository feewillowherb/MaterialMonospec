## ADDED Requirements

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
