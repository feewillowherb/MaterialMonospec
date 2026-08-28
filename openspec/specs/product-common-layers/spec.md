# Product Common Layers Specification

## Purpose

定义 MaterialClient 内核 Common 与 `MaterialClient.Common.{Product}` 产品定制层：实体、EF、Service API 与宿主引用边界。

## Requirements

### Requirement: Common is the kernel baseline assembly

`MaterialClient.Common` SHALL contain kernel domain entities, kernel Service APIs, and shared non-product infrastructure. It MUST NOT contain Urban or Recycle entities, product `DbContext` types, or product EF migrations.

#### Scenario: Standard host does not reference product Common

- **WHEN** the standard `MaterialClient` executable project is inspected
- **THEN** it MUST NOT have a `ProjectReference` to `MaterialClient.Common.Urban` or `MaterialClient.Common.Recycle`

#### Scenario: Kernel assembly has no product persistence types

- **WHEN** `MaterialClient.Common` is compiled for the standard host
- **THEN** it MUST NOT expose `UrbanDbContext` or `RecycleDbContext`
- **AND** MUST NOT map `UrbanWeighingExtension` or `RecycleWaybillExtension` in the kernel model

### Requirement: Product Common assemblies own customization

The system SHALL provide `MaterialClient.Common.Urban` and `MaterialClient.Common.Recycle` class libraries that contain the corresponding product entities, product `DbContext`, product migrations, and product Service interfaces and implementations. Product WinExe projects SHALL compose UI and host modules only and MUST NOT own product table Fluent mappings.

#### Scenario: Urban product Common is loaded only by Urban host

- **WHEN** `MaterialClient.Urban` initializes ABP
- **THEN** it SHALL depend on `MaterialClientCommonUrbanModule` (or equivalent module in `MaterialClient.Common.Urban`)
- **AND** `MaterialClient.UI` MUST NOT reference `MaterialClient.Common.Urban`

#### Scenario: Recycle product Common is loaded only by Recycle host

- **WHEN** `MaterialClient.Recycle` initializes ABP
- **THEN** it SHALL depend on the Recycle product Common module
- **AND** MUST NOT depend on `MaterialClient.Common.Urban`

#### Scenario: New product follows the same layer

- **WHEN** a future product client is added
- **THEN** product tables and product Service APIs SHALL be added as `MaterialClient.Common.{Product}`
- **AND** MUST NOT be added under `MaterialClient.Common` entity folders

### Requirement: UI mapper implementations stay off UI and off kernel Common when product-specific

Product-specific Service implementations SHALL live in `MaterialClient.Common.{Product}`. If `MaterialClient.UI` requires an interface without referencing the product assembly, the interface MAY remain in `MaterialClient.Common` and the implementation MUST be registered only by the product host module.

#### Scenario: Urban-only implementation not registered on standard host

- **WHEN** the standard `MaterialClient` host starts
- **THEN** it MUST NOT register Urban-only Service implementations from `MaterialClient.Common.Urban`
