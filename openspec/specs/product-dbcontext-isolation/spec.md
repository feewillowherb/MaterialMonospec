# Product DbContext Isolation Specification

## Purpose

定义内核与产品双（多）DbContext、独立 migration history、无跨 Context FK、启动迁移顺序。

## Requirements

### Requirement: Kernel and product use separate DbContext types on one SQLite file

The kernel SHALL use `MaterialClientDbContext` for baseline tables only. Urban SHALL use `UrbanDbContext` for Urban tables only. Recycle SHALL use `RecycleDbContext` for Recycle tables only. All three SHALL use the same SQLite connection string (`Default` / existing local db file). The runtime MUST NOT use ABP `ReplaceDbContext` to merge product entity types into the kernel context model.

#### Scenario: Kernel model excludes product tables

- **WHEN** the kernel `OnModelCreating` for `MaterialClientDbContext` is applied
- **THEN** the model MUST NOT include `UrbanWeighingExtension` or `RecycleWaybillExtension`

#### Scenario: Product context excludes kernel aggregate mapping for migrations

- **WHEN** `UrbanDbContext` is used to generate or apply migrations
- **THEN** those migrations MUST NOT create or alter kernel tables such as `WeighingRecords` or `Waybills`
- **AND** Urban code that needs kernel data SHALL use kernel repositories or kernel services, not kernel `DbSet`s on `UrbanDbContext` as the migration owner

### Requirement: Separate EF migration history tables

Each DbContext SHALL record applied migrations in a distinct SQLite table: `__EFMigrationsHistory_Kernel`, `__EFMigrationsHistory_Urban`, and `__EFMigrationsHistory_Recycle` (names MAY vary only if documented in the module, but MUST be unique per context).

#### Scenario: Product migration does not collide with kernel history

- **WHEN** Urban applies a product migration after kernel migrations
- **THEN** the product history table SHALL record the Urban migration
- **AND** the kernel history table MUST NOT treat that Urban migration as a kernel migration

### Requirement: Host applies kernel migrations then product migrations

Urban and Recycle hosts SHALL apply pending kernel migrations before pending product migrations at startup. The standard host SHALL apply kernel migrations only.

#### Scenario: Urban startup migrate order

- **WHEN** Urban `OnApplicationInitializationAsync` runs database migration
- **THEN** it SHALL migrate `MaterialClientDbContext` first
- **AND** SHALL then migrate `UrbanDbContext`

#### Scenario: Standard host does not migrate Urban schema

- **WHEN** the standard `MaterialClient` host applies EF migrations
- **THEN** it MUST NOT apply `UrbanDbContext` or `RecycleDbContext` migrations

### Requirement: No cross-context database foreign keys

Product extension entities SHALL continue to associate to kernel rows by logical identifiers only. The system MUST NOT introduce EF navigations or database foreign keys from product tables to kernel tables.

#### Scenario: Extension upsert by logical id

- **WHEN** an Urban service persists `UrbanWeighingExtension` for a weighing record
- **THEN** it SHALL set `WeighingRecordId` without requiring a database FK to `WeighingRecords`

### Requirement: Urban settings are not a kernel SettingsEntity column

`SettingsEntity.UrbanSettingsJson` SHALL NOT remain a required kernel baseline column. Urban settings persistence SHALL be owned by `UrbanDbContext`.

#### Scenario: Kernel settings entity without Urban blob requirement

- **WHEN** the kernel settings mapping is applied after this change
- **THEN** Urban-specific settings MUST NOT be required on `SettingsEntity` for the kernel model to be valid
- **AND** the Urban host SHALL read and write Urban settings via Urban product persistence
