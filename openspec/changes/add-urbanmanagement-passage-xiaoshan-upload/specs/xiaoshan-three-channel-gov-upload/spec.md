## ADDED Requirements

### Requirement: Three independent Gov outbound paths

UrbanManagement SHALL upload weighing records via `POST /sapi/v1/inoutRecord/lantu/saveRecord` with `buildLicenseNo` equal to original `L` and `dataSource` exactly `WEIGHBRIDGE_XIAOSHAN`. Checkpoint passage SHALL upload via `POST /sapi/v1/inoutRecord/save` with `buildLicenseNo` equal to original `L` and MUST NOT include `dataSource`. Finished-product passage SHALL upload via the same path with `buildLicenseNo` equal to `L` plus `-02` applied once. Weighbridge and checkpoint MUST NEVER append `-02`. Checkpoint outbound code, product outbound code, and weighbridge outbound code MUST be separate implementations (duplication allowed) and MUST NOT share one method parameterized by suffix.

#### Scenario: Weighbridge uses lantu path and constant dataSource

- **WHEN** a weighing record is forwarded to Gov
- **THEN** the request path MUST be `lantu/saveRecord`
- **AND** `dataSource` MUST be `WEIGHBRIDGE_XIAOSHAN`
- **AND** `buildLicenseNo` MUST NOT end with `-02` unless `L` itself already did before this change's transform (weighbridge MUST NOT append)

#### Scenario: Product suffix applied once

- **WHEN** a finished-product passage is forwarded and project license is `330106202212120101`
- **THEN** `buildLicenseNo` MUST be `330106202212120101-02`
- **AND** the HTTP path MUST be `inoutRecord/save`

#### Scenario: Checkpoint has no suffix

- **WHEN** a checkpoint passage is forwarded with the same `L`
- **THEN** `buildLicenseNo` MUST equal `L` without `-02`

### Requirement: Outbound converters only at Gov upload

UrbanManagement SHALL convert domain `UrbanInOutType` and `UrbanSiteType` to Xiaoshan wire values only when assembling Gov payloads. Checkpoint and finished-product converters MUST be separate types. Converters MUST be static or invoked from payload `From*` factories and MUST NOT be registered in DI. Persistence MUST keep domain enums. Weighbridge `inOutType` MUST be `0` for Enter and `1` for Exit. Checkpoint and product `deviceID` MUST be `01` for Enter and `02` for Exit. Passage payloads MUST omit `goodsWeight` when absent and MUST NOT send `0` as a fake weight.

#### Scenario: Enter maps per channel

- **WHEN** a checkpoint row with `UrbanInOutType` Enter is uploaded
- **THEN** `deviceID` MUST be `01`
- **WHEN** a weighing row with Enter is uploaded
- **THEN** `inOutType` MUST be `0`

#### Scenario: Hardcoded inOutType zero is removed

- **WHEN** a weighing row with Exit is uploaded
- **THEN** `inOutType` MUST be `1`
- **AND** MUST NOT remain hardcoded to `0`

### Requirement: Gov host configured in UrbanManagement

The Refit base address for Xiaoshan Gov SHALL be read from UrbanManagement configuration (scheme, host, port). It MUST NOT be hardcoded to documentation or pipeline demo IPs. Paths MAY share one host by default. A second base address MAY be configured when weighbridge and site APIs are not co-located. MaterialClient MUST NOT supply this host for server-to-Gov calls.

#### Scenario: Host from UM settings

- **WHEN** the worker posts a Gov request
- **THEN** the host MUST come from UrbanManagement configuration
- **AND** MUST NOT be compiled as `172.18.34.209` or `191.12.15.58`

### Requirement: No heartbeat

The system MUST NOT call `/sapi/sysdevicemng/heatBeat`.

#### Scenario: Worker does not heartbeat

- **WHEN** Gov sync runs
- **THEN** it MUST NOT HTTP POST the heartbeat path
