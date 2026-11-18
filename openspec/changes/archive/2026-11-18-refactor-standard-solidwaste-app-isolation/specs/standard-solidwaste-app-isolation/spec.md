## ADDED Requirements

### Requirement: Standard and SolidWaste have separate desktop hosts

The system SHALL provide `MaterialClient` as the Standard WinExe and `MaterialClient.SolidWaste` as the SolidWaste WinExe. Each host SHALL be built and installed separately. The SolidWaste host MUST NOT copy AttendedWeighing AXAML into its project and SHALL reuse the shared UI and attended-weighing projects.

#### Scenario: SolidWaste host composition

- **WHEN** `MaterialClient.SolidWaste` is built
- **THEN** it SHALL reference `MaterialClient.Common.SolidWaste`, `MaterialClient.UI`, and `MaterialClient.AttendedWeighing`
- **AND** MUST NOT reference `MaterialClient.Common.Standard`, `MaterialClient.Common.Urban`, or `MaterialClient.Common.Recycle`

#### Scenario: Standard host composition

- **WHEN** `MaterialClient` is built
- **THEN** it MUST NOT reference `MaterialClient.Common.SolidWaste`

### Requirement: Host product identity is fixed

The Standard host SHALL accept only `WeighingMode.Standard` and the Standard product code. The SolidWaste host SHALL accept only `WeighingMode.SolidWaste` and the SolidWaste product code. The authorization window SHALL show only the mode supplied by the running host.

#### Scenario: Saved mode belongs to the other host

- **WHEN** a host reads a saved default weighing mode that belongs to the other product
- **THEN** it SHALL exit before opening the weighing window
- **AND** MUST NOT change the saved default weighing mode
- **AND** MUST NOT delete license records

#### Scenario: New installation writes only its own mode

- **WHEN** a host starts with no saved default weighing mode and authorization completes
- **THEN** it SHALL persist its own weighing mode

### Requirement: Upgrade opens the existing data directory

A host SHALL resolve relative database and attachment paths against `Client:DataDirectory` when that absolute path is configured, and against the executable directory otherwise. The host MUST NOT relocate or delete an existing database or its attachment files. Consistent recovery backups are permitted and required before upgrading an existing database. When `Client:DataDirectory` is configured but the directory does not exist, the host SHALL stop and MUST NOT create a new database in the executable directory.

#### Scenario: SolidWaste upgrade uses the old directory

- **WHEN** `MaterialClient.SolidWaste` starts with `Client:DataDirectory` set to an existing MaterialClient directory
- **THEN** it SHALL open `MaterialClient.db` in that directory
- **AND** SHALL resolve existing relative attachment paths from that directory

#### Scenario: Missing data directory does not create an empty database

- **WHEN** `Client:DataDirectory` names a directory that does not exist
- **THEN** startup SHALL fail before creating a database

### Requirement: Installers keep product identity and field data

The SolidWaste installer SHALL use its own application id, display name, and default directory. Uninstalling the SolidWaste host MUST NOT delete the database, attachment directories, or a data directory referenced by `Client:DataDirectory`. The Standard installer MUST NOT change an auto-start entry whose target is `MaterialClient.SolidWaste.exe`.

#### Scenario: SolidWaste uninstall keeps the database

- **WHEN** the SolidWaste installer is uninstalled
- **THEN** `MaterialClient.db` and existing photo directories SHALL remain

#### Scenario: Standard installer leaves a SolidWaste auto-start entry

- **WHEN** the Standard installer runs and the current auto-start command targets `MaterialClient.SolidWaste.exe`
- **THEN** it MUST NOT replace that command with `MaterialClient.exe`

### Requirement: Historical rows stay readable

A host SHALL keep kernel weighing and waybill rows for every existing mode. New rows written by a host SHALL use that host's mode. The host MUST NOT delete or hide rows because their mode belongs to the other product.

#### Scenario: SolidWaste host reads old standard rows

- **WHEN** the SolidWaste host opens a database that contains Standard weighing rows
- **THEN** those rows SHALL remain in the database
- **AND** SHALL remain available to read


### Requirement: Legacy deployment configuration is preserved

The host SHALL resolve Client:DataDirectory from its own configuration before composing legacy configuration. Configuration priority from low to high SHALL be host appsettings.json defaults, legacy appsettings.json, legacy appsettings.secret.json, then explicit host appsettings.secret.json overrides. Duplicate paths SHALL be loaded once. Legacy configuration MUST NOT change the resolved data root or the host product identity. Secrets MUST NOT be logged or copied over source configuration.

#### Scenario: Existing server endpoint is retained

- **WHEN** SolidWaste opens a supported legacy deployment with a configured server endpoint and no explicit host override
- **THEN** the original endpoint SHALL be used together with the original database and attachment root
- **AND** the original configuration files SHALL remain unchanged

### Requirement: Existing database preflight precedes all mutable startup actions

A configured Client:DataDirectory SHALL select existing-deployment mode. Existing databases in the default directory SHALL also undergo preflight. Before migrations, backfill, settings creation, registry/shortcut changes, workers or devices start, the host SHALL acquire exclusion for the normalized actual database path and inspect the database read-only without creation. It SHALL reject missing/corrupt databases, unsupported schema versions and missing or mismatched saved product identity. Fresh database creation SHALL occur only for a fresh installation without a configured legacy root and without an existing default database.

The initial supported upgrade baseline SHALL be the schema produced by 495aa3e3. Implementation SHALL enumerate its required schema and migration identifiers. Older versions SHALL first pass through the validated database-isolation upgrade; unrecognized newer versions SHALL NOT be opened for downgrade.

#### Scenario: Existing directory contains no database

- **WHEN** a host starts in existing-deployment mode and the final database file is absent
- **THEN** it SHALL report the missing database and stop
- **AND** SHALL NOT create a database, settings or license records

#### Scenario: Wrong product or unsupported schema is rejected before writes

- **WHEN** preflight detects a mismatched product, missing product identity or unsupported/corrupt schema
- **THEN** startup SHALL stop with an actionable diagnostic
- **AND** the original database, configuration, authorization and launch entries SHALL remain unchanged
- **AND** no migration, backfill, worker or device initialization SHALL run

#### Scenario: Another process owns the deployment

- **WHEN** another new host holds exclusion for the same database or the legacy process for that deployment remains running
- **THEN** the new host SHALL stop before database migration or device initialization

### Requirement: Runtime and installers own separate launch entries

Standard SHALL own the MaterialClient auto-start value and SolidWaste SHALL own MaterialClient.SolidWaste. Runtime enable/disable/check operations and installers SHALL use the same ownership rules. Legacy SolidWaste launch entries SHALL be transferred only after successful preflight, migration and authorization, only when their normalized target matches the selected legacy installation. The transfer SHALL preserve enabled state, validate the new entry before removing a matching legacy entry, and be idempotent. Unrelated entries MUST NOT be modified. The Standard installer SHALL reject a SolidWaste target deployment before replacing binaries.

#### Scenario: Independent products keep their own auto-start entries

- **WHEN** Standard and SolidWaste use different data directories and one product toggles auto-start
- **THEN** only that product's registry value SHALL change
- **AND** the other product's startup entry SHALL remain unchanged

#### Scenario: Legacy SolidWaste entry is transferred safely

- **WHEN** successful upgrade transfers a legacy entry targeting the selected old MaterialClient.exe
- **THEN** the new SolidWaste entry SHALL preserve the previous enabled state
- **AND** unrelated installations' entries SHALL remain unchanged on initial and repeated execution

#### Scenario: Standard installer targets an old SolidWaste deployment

- **WHEN** the Standard installer identifies the target deployment as SolidWaste
- **THEN** it SHALL reject the overwrite and direct the operator to the SolidWaste package before replacing the old executable

### Requirement: Upgrade recovery preserves consistent deployment state

Before mutating a supported existing database, the upgrade SHALL create and validate a consistent recovery backup with the old process stopped and exclusion held. The recovery manifest SHALL identify the old application package, database, configuration and launch-entry state without exposing secrets. Copying only a potentially incomplete SQLite main file SHALL NOT qualify as a consistent backup. Recovery SHALL restore a compatible set of application, data, configuration and entries; reinstalling an old package alone SHALL NOT qualify. Failure SHALL NOT automatically start old binaries on a partially migrated database.

#### Scenario: Migration or launch-entry handoff fails

- **WHEN** upgrade fails during migration or launch-entry handoff
- **THEN** business startup SHALL remain disabled and a recovery diagnostic SHALL be available
- **AND** the validated backup and original launch-entry state SHALL remain recoverable

#### Scenario: New business data exists after upgrade

- **WHEN** rollback is requested after the new application has persisted business data
- **THEN** recovery SHALL preserve the new database and require an explicit reconciliation route
- **AND** SHALL NOT silently overwrite it with the pre-upgrade snapshot
