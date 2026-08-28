# Xiaoshan Upload Field Mapping Specification

## Purpose

按模式把静态配置与称重上下文解析为上报字段；可选无源字段跳过并记录，Product 施工许可证号追加 `-02`。

## Requirements

### Requirement: Static and record-sourced fields are mapped per mode

The system SHALL distinguish configuration static fields (for example `buildLicenseNo`, `areaCode`, `spaceName`, `dataSource`) from fields sourced from weighing records (for example plate number, weight, snap time, images). A field mapping layer SHALL resolve values for a given enabled mode and weighing context using the authoritative settings envelope and the weighing record payload. Multi-value results SHALL use named records, not tuples.

#### Scenario: Static field taken from settings

- **WHEN** field mapping runs for Gate mode and `areaCode` is configured in static settings
- **THEN** the resolved output SHALL include `areaCode` from static settings

#### Scenario: Record field taken from weighing context

- **WHEN** field mapping runs and the weighing record provides `carNo`
- **THEN** the resolved output SHALL include the plate value from the weighing record

### Requirement: Optional fields without data source are skipped not blocked

For fields documented as non-required in the Xiaoshan upload design, when neither static configuration nor the weighing record provides a value, the system SHALL skip the field for upload assembly, SHALL NOT treat the condition as a fatal configuration error, and SHALL record the skip in the mapping result (`SkippedFields`).

#### Scenario: Skip optional field with no source

- **WHEN** an optional field has no static value and the weighing record provides no value
- **THEN** the field mapping result SHALL list the field in a skipped-fields collection with a reason indicating no data source
- **AND** the main weighing/upload flow SHALL NOT be blocked solely for this skip

### Requirement: Upload path logs skipped fields

When the MaterialClient Urban upload path processes a weighing event against Xiaoshan upload configuration, it SHALL emit a structured log entry for skipped optional fields including mode, field name, and skip reason. Required missing fields SHALL be logged at a higher severity than optional skips.

#### Scenario: Skip logged on upload path

- **WHEN** upload assembly skips an optional field because no source is available
- **THEN** the Urban client SHALL write a log entry containing the mode, field name, and skip reason

### Requirement: Product buildLicenseNo suffix rule

For Product mode, when `buildLicenseNo` is resolved from static configuration holding the original license value `L`, the mapping layer SHALL produce `L + "-02"` unless `L` already ends with the literal suffix `-02`, in which case it SHALL NOT append again. Gate and Weighbridge modes SHALL use the original value without the Product suffix.

#### Scenario: Product suffix applied once

- **WHEN** static `buildLicenseNo` is `330106202212120101` and mapping targets Product mode
- **THEN** the resolved `buildLicenseNo` SHALL be `330106202212120101-02`

#### Scenario: Product suffix not doubled

- **WHEN** static `buildLicenseNo` already ends with `-02` and mapping targets Product mode
- **THEN** the resolved `buildLicenseNo` SHALL remain unchanged

#### Scenario: Gate uses original license

- **WHEN** static `buildLicenseNo` is `330106202212120101` and mapping targets Gate mode
- **THEN** the resolved `buildLicenseNo` SHALL be `330106202212120101`
