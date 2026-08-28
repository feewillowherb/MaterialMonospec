## Why

设置里的车牌识别厂商类型今天绑在 `SystemSettings.LprDeviceType` 上，全站只能一种海康 / 臻识 / 华夏；添加对话框只是借用该全局值画字段，配置行本身不记类型。现场需要按设备选定厂商（含混用），不能靠改一个 Combo 把已添加设备全部换型。

## What Changes

- 每条 `LicensePlateRecognitionConfig` 持久化 `DeviceType`（`LprDeviceType`）；添加/编辑 LPR 时在对话框内选定。
- **BREAKING（有意）**：设置页去掉全局「车牌识别设备类型」；改全局不再等于改所有已添加设备。
- DeviceManager、主动抓拍、在线探测、测试抓拍、道闸 I/O 门控按**该行**类型解析；按配置中实际出现的厂商启停 SDK（允许海康与臻识同时在线）。
- 加载时对缺 `DeviceType` 的旧 JSON 用当时的 `SystemSettings.LprDeviceType` 回填。过渡期仍可回写全局字段作兼容镜像，运行时不得再以全局为权威。
- **不做**：地磅 / 卡口 / 成品业务角色、独立 entity、萧山上报；不改 UrbanManagement / BasePlatform。

## Capabilities

### New Capabilities

- `lpr-device-type-per-config`：行级厂商类型、旧数据回填、按出现的类型启动 LPR SDK、混厂商在线/抓拍/道闸按行分发

### Modified Capabilities

- `settings-ui`：Add/Edit LPR 对话框选定类型；列表列可见性不再绑全局 `LprDeviceType`；移除设置页全局厂商 Combo
- `license-plate-recognition`：字段显隐与「切换类型」以对话框/该行配置为准，不再假设全站一份 `LprDeviceType`
- `weighing-device-capture`：主动抓拍按配置行类型解析 `ILprDevice`
- `vzvision-gate-io-control`：仅当该行 `DeviceType` 为 Vzvision 且启用道闸时走臻识 I/O

## Impact

- 子仓：仅 `repos/MaterialClient`（Common 配置与 LPR/Device 服务、UI 设置窗与 `AddLprDialog`、AttendedWeighing / `SharedDeviceStatusTracker` 在线检查、既有配置测试）。
- 设置 JSON：`LicensePlateRecognitionConfigsJson` 行内新增字段；无 EF 表迁移。
- 调研输入：`docs/2026-08-28-lpr-device-type-per-config/`。
