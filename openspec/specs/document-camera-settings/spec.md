# document-camera-settings Specification

## Purpose

定义高拍仪（USB 文档摄像头）的启用配置、设置界面分区与测试行为，并与设备状态栏可选显示联动。
## Requirements
### Requirement: Document camera enable configuration

The system MUST persist a boolean `DocumentCameraEnabled` (or equivalent) on `SystemSettings` / `SettingsEntity`, defaulting to `false` when unset, to control whether the document camera (高拍仪 / USB camera) is used at runtime.

#### Scenario: Default disabled on fresh settings

- **WHEN** settings are loaded and `DocumentCameraEnabled` was never saved
- **THEN** `DocumentCameraEnabled` MUST be `false`
- **AND** the document camera service MUST NOT be started during application startup

#### Scenario: Enable via settings save

- **WHEN** user enables the document camera in settings and saves successfully
- **THEN** `DocumentCameraEnabled` MUST be persisted as `true`
- **AND** the document camera service MUST be eligible for startup on next application start or device restart cycle

#### Scenario: Disable via settings save

- **WHEN** user disables the document camera in settings and saves successfully
- **THEN** `DocumentCameraEnabled` MUST be persisted as `false`
- **AND** the document camera service MUST NOT remain running as an active device after save/restart policy applies

### Requirement: Document camera settings UI section

MaterialClient.UI `SettingsWindow` MUST provide a dedicated settings area labeled for the document camera (高拍仪), separate from Hikvision weighing camera configuration.

#### Scenario: Settings navigation entry

- **WHEN** SettingsWindow is opened
- **THEN** the left navigation MUST include a document camera (高拍仪) section
- **AND** selecting it MUST show an enable toggle bound to `DocumentCameraEnabled`
- **AND** SHALL show connection/configuration controls applicable to the USB document camera when enabled

#### Scenario: Test action when enabled

- **WHEN** document camera is enabled and user invokes the test action in the section
- **THEN** the system MUST invoke the existing USB/document camera test API if available
- **AND** MUST surface success or failure feedback consistent with other device test buttons in settings

#### Scenario: Test action when disabled

- **WHEN** document camera is not enabled
- **THEN** test and connection-specific controls MUST be disabled or hidden
- **AND** saving MUST NOT start the document camera service

