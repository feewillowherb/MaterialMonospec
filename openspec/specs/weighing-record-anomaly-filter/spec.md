# Weighing Record Anomaly Filter

## Purpose

Server-side anomaly status filtering for weighing record list queries, enabling callers to filter by `IsAnomaly` state.

## Requirements

### Requirement: IsAnomaly filter parameter on list API

The `UrbanWeighingRecordListInputDto` SHALL support an optional `IsAnomaly` filter parameter that enables server-side anomaly status filtering.

#### Scenario: Filter anomalous records

- **WHEN** `GetListAsync` is called with `IsAnomaly = true`
- **THEN** the query SHALL include `WHERE IsAnomaly = true`
- **AND** only anomalous records SHALL be returned in the paged result

#### Scenario: Filter normal records

- **WHEN** `GetListAsync` is called with `IsAnomaly = false`
- **THEN** the query SHALL include `WHERE IsAnomaly = false`
- **AND** only non-anomalous records SHALL be returned in the paged result

#### Scenario: No filter applied

- **WHEN** `GetListAsync` is called with `IsAnomaly = null`
- **THEN** the query SHALL NOT apply any `IsAnomaly` filter
- **AND** both anomalous and non-anomalous records SHALL be returned

#### Scenario: Backward compatibility

- **WHEN** an existing caller invokes `GetListAsync` without setting the `IsAnomaly` property
- **THEN** the property SHALL default to `null`
- **AND** the query behavior SHALL be identical to before this change
