## MODIFIED Requirements

### Requirement: Pending record selection from UrbanWeighingRecord

The government sync worker SHALL select pending weighing records only for projects whose `GovProject.IsSyncEnabled` is `true`. Selection MUST use the `IsSyncEnabled` property (MUST NOT reference `EnableSync`).

#### Scenario: Disabled project excluded

- **WHEN** a weighing record is pending but its project's `IsSyncEnabled` is `false`
- **THEN** the worker SHALL NOT select that record for outbound sync in the current cycle

#### Scenario: Enabled project included

- **WHEN** a weighing record is pending and its project's `IsSyncEnabled` is `true`
- **THEN** the record SHALL be eligible for pending selection subject to other filters (anomaly, retry limits, etc.)
