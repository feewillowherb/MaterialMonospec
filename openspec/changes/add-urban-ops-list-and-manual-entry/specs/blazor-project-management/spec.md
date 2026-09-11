## ADDED Requirements

### Requirement: Project row operation includes 添加 for manual weighing

`ProjectManagement.razor` SHALL expose「添加」in the project row operation column alongside existing actions, wiring to manual weighing entry (`urban-manual-weighing-entry`).

#### Scenario: 添加 visible on project row

- **WHEN** the operator views the project list
- **THEN** each project row's operation area SHALL include「添加」
- **AND** activating it SHALL open the manual weighing entry flow for that project
