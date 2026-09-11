## ADDED Requirements

### Requirement: Approval list filters by anomaly reason

The UrbanManagement weighing approval page (`/weighing-approval`) SHALL provide a dropdown to filter rows by `AnomalyReason` kind, including an「全部」option and at least the literal reason `人工录入`.

#### Scenario: Filter by selected reason

- **WHEN** the operator selects a specific anomaly reason in the dropdown and refreshes/lists
- **THEN** the list SHALL only include anomalous rows whose `AnomalyReason` equals that selection

#### Scenario: 全部 shows all anomaly reasons

- **WHEN** the operator selects「全部」
- **THEN** the list SHALL not filter by `AnomalyReason` (existing IsAnomaly / project filters MAY still apply)

#### Scenario: 人工录入 option available

- **WHEN** the anomaly-reason dropdown renders
- **THEN** it SHALL include `人工录入` as a selectable value even if no such rows exist yet
