## ADDED Requirements

### Requirement: Chunked attachment upload toggle in system settings UI

MaterialClient.UI `SettingsWindow` (system settings section) SHALL expose a boolean toggle to enable or disable tus-based chunked attachment upload for Urban attachment sync. The value SHALL bind to `SystemSettings.EnableChunkedAttachmentUpload`, default `false`, and SHALL persist via the existing `ISettingsService` save flow with other system settings.

#### Scenario: Toggle visible in system section

- **WHEN** the operator opens Settings and navigates to the system settings area
- **THEN** the UI SHALL show a control labeled to enable attachment chunked upload (or equivalent Chinese label such as「启用附件分片上传」)
- **AND** the control SHALL reflect the current `EnableChunkedAttachmentUpload` value

#### Scenario: Save persists toggle

- **WHEN** the operator turns the toggle on and saves settings
- **THEN** subsequent loads of settings SHALL show the toggle on
- **AND** Urban attachment sync SHALL treat tus chunked upload as enabled

#### Scenario: Default off for existing installations

- **WHEN** existing settings JSON has no `EnableChunkedAttachmentUpload` property
- **THEN** deserialization SHALL treat the value as `false`
- **AND** attachment sync SHALL continue using multipart upload
