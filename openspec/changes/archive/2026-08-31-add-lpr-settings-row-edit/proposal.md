## Why

设置页车牌识别表格已有「编辑」命令与 `EditLprAsync`，但操作列按钮 `IsVisible="False"`，用户无法改已有行的厂商、IP、道闸等字段，只能删了再加。摄像头分区已经用同一套「增加对话框」做编辑；LPR 应同样露出并共用窗口，而不是再做一个几乎相同的 Edit 窗体。

## What Changes

- 显示车牌识别表格「编辑」按钮；点开后打开与「增加」相同的 `AddLprDialog`（同一 AXAML / 同一 ViewModel 类型）。
- 对话框按模式区分文案：增加为「添加…」，编辑为「编辑…」；字段、厂商切换、道闸可见性与保存校验与增加路径一致。
- 编辑确认后替换该行（不新增一行）；取消不改集合。
- **禁止**新增独立的 `EditLprDialog` 窗口类。不改 LPR JSON 字段形状，不改称重/道闸运行时语义。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `settings-ui`: 车牌识别行必须可编辑；编辑 MUST 复用 `AddLprDialog`，不得另起编辑专用窗口。

## Impact

- 仅 **MaterialClient.UI**：`SettingsWindow.axaml`（露出编辑）、`AddLprDialog.axaml` / `AddLprDialogViewModel`（标题与增加/编辑模式）、已有 `EditLprAsync` 预填。
- `ISettingsService` / 设备 SDK / UrbanManagement / BasePlatform 无变更。保存仍走现有设置保存命令。
