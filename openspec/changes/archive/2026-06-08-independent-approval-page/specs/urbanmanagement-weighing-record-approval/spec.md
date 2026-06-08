## MODIFIED Requirements

### Requirement: Weighing record list exposes approval action

The UrbanManagement weighing record **approval page** (`/weighing-approval`) SHALL provide an approval action for each row. The weighing record management page (`/weighing`) SHALL NOT provide an approval action.

#### Scenario: Approval button on approval page

- **WHEN** the administrator views the approval page LayUI table
- **THEN** each row SHALL include an operation control labeled「审批」
- **AND** activating the control SHALL open an approval dialog for that row's server record `Id`

#### Scenario: No approval button on weighing record page

- **WHEN** the administrator views the weighing record management page (`/weighing`)
- **THEN** no approval action SHALL be present on any row
- **AND** the "操作" column SHALL NOT appear in the table
