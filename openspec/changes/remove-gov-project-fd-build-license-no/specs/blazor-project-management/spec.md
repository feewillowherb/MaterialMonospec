## MODIFIED Requirements

### Requirement: Project create operation
`ProjectManagement.razor` SHALL allow creating a new project via a modal dialog.

#### Scenario: Create project dialog
- **WHEN** the user clicks the "添加" button
- **THEN** a modal dialog SHALL appear with form fields: 项目名称 (required), 对接码 (required)
- **AND** MUST NOT include a separate 施工许可证号 / 凡东对接码 field
- **AND** clicking "保存" SHALL call `IGovProjectAppService.CreateAsync()` with the form data
- **AND** on success, the table SHALL refresh and the dialog SHALL close

### Requirement: Project edit operation
`ProjectManagement.razor` SHALL allow editing an existing project via a modal dialog.

#### Scenario: Edit project dialog
- **WHEN** the user clicks the "编辑" button on a table row
- **THEN** a modal dialog SHALL appear pre-populated with the project data (loaded via `IGovProjectAppService.GetAsync(id)`) including 项目名称 and 对接码 only for license fields
- **AND** MUST NOT display or edit `FdBuildLicenseNo`
- **AND** clicking "保存" SHALL call `IGovProjectAppService.UpdateAsync()` with the modified data
- **AND** on success, the table SHALL refresh and the dialog SHALL close
