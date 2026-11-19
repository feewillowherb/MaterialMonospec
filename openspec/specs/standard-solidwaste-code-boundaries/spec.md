# standard-solidwaste-code-boundaries Specification

## Purpose

Keep Standard and SolidWaste desktop hosts on shared infrastructure without sharing executable source, and keep SolidWaste product writes outside the common weighing kernel.

## Requirements

### Requirement: Desktop hosts share infrastructure through a library

Standard and SolidWaste SHALL consume common StartupService, MinimalWebHostService and PollingBackgroundService implementations from a shared library. Neither host SHALL compile-link or reference the other executable's internal source. The shared library MUST NOT reference a product executable or product implementation assembly.

#### Scenario: Both hosts build independently

- **WHEN** Standard and SolidWaste are built
- **THEN** both SHALL resolve the shared implementations through project references
- **AND** neither SHALL require Compile Link entries into the other executable project

### Requirement: Product composition remains explicit

Each host SHALL compose only its product runtime module, identity, migrations and product configuration. Shared hosting SHALL preserve existing authorization, login, polling switches and shutdown semantics. SolidWaste SHALL bind StreetsConfig and SolidWasteTypeConfig from its effective configuration with a single source of defaults.

#### Scenario: SolidWaste resolves configuration and startup dependencies

- **WHEN** SolidWaste starts with valid product configuration
- **THEN** its product settings and required authorization/HTTP services SHALL resolve
- **AND** configured polling and shutdown behavior SHALL remain effective

#### Scenario: Standard starts without SolidWaste runtime

- **WHEN** Standard starts
- **THEN** it SHALL NOT load SolidWaste runtime modules, run SolidWaste migrations or start SolidWaste tasks

### Requirement: Product logic stays outside the common weighing kernel

SolidWaste four-field persistence and export implementation SHALL belong to the SolidWaste product module. Common weighing orchestration SHALL use only product-neutral lifecycle contracts for required product writes. UI-facing product contracts MAY live in a separate implementation-free contract library. Presentation persistence SHALL go through Services. Standard historical SolidWaste reads SHALL remain available through a read-only adapter without initializing the SolidWaste runtime.

#### Scenario: Standard reads historical SolidWaste rows

- **WHEN** Standard queries existing mixed-mode history with available SolidWaste extensions
- **THEN** existing history and its product-field display SHALL remain readable
- **AND** no SolidWaste migration or product write SHALL occur

#### Scenario: SolidWaste export reads authoritative fields

- **WHEN** a SolidWaste waybill is exported or printed
- **THEN** four product fields SHALL come from the extension data
- **AND** the net-display flag SHALL come from the canonical ExtraProperties accessor

### Requirement: Kernel and product writes are atomic

Creation, matching, unmatching, editing and deletion operations that modify both kernel and SolidWaste extension data SHALL await product persistence within a shared database transaction owned by a UnitOfWork Service. Required product persistence failures SHALL fail the operation. They MUST NOT be handled through fire-and-forget events or fake success.

#### Scenario: Extension persistence fails

- **WHEN** an extension write fails after a kernel change in the same operation
- **THEN** both kernel and extension changes SHALL roll back
- **AND** the caller SHALL receive a recognizable failure

#### Scenario: Standard performs a kernel-only operation

- **WHEN** Standard saves its weighing data
- **THEN** the product-neutral extension integration SHALL perform no SolidWaste write
- **AND** the kernel operation SHALL retain its existing behavior
