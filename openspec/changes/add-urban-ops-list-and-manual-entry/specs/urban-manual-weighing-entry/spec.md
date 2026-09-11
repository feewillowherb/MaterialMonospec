## ADDED Requirements

### Requirement: Project management exposes manual weighing entry

`ProjectManagement.razor` SHALL provide an「添加」control in the per-row operation area (or an equivalent project-scoped add action clearly tied to that project) that opens a manual weighing-record entry dialog for the selected project.

#### Scenario: Open manual entry from project row

- **WHEN** the operator activates「添加」on a project row
- **THEN** the system SHALL open a dialog to enter weighing fields needed to create an `UrbanWeighingRecord` for that project's `ProId`
- **AND** SHALL NOT require MaterialClient to be online

### Requirement: Manual entry marks reason 人工录入 and defaults to auto upload

Manually created weighing records SHALL set `AnomalyReason` to the literal `人工录入` and SHALL default to government auto-upload eligibility.

#### Scenario: Persist 人工录入 reason

- **WHEN** the operator confirms manual entry
- **THEN** the created record SHALL have `AnomalyReason` equal to `人工录入`
- **AND** SHALL have `IsAnomaly = true`

#### Scenario: Default auto upload

- **WHEN** manual entry succeeds with default options
- **THEN** the record SHALL be eligible for the government sync pipeline without requiring a separate approval step first
- **AND** the GovSync worker SHALL NOT skip the record solely because `IsAnomaly` is true when `AnomalyReason` is `人工录入`
