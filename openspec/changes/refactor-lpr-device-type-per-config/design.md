## Context

今日权威是 `SystemSettings.LprDeviceType`。`LicensePlateRecognitionConfig` 无厂商字段；`AddLprDialogViewModel` 只把全局枚举当构造参数。`DeviceManagerService` 按全局互斥启动海康或臻识 LPR。抓拍、在线、测试抓拍、道闸门控同样读全局。调研见 `docs/2026-08-28-lpr-device-type-per-config/`。仅 MaterialClient；设置在 JSON，无 EF 迁移。

## Goals / Non-Goals

**Goals:**

- 每台 LPR 配置自带 `LprDeviceType`；添加/编辑时选定。
- 运行时按行解析 SDK；配置里出现的厂商都要启动对应监听（允许混厂商）。
- 旧设置缺字段时用全局值回填；过渡期仍可镜像写回 `SystemSettings.LprDeviceType`，但运行时不以它为权威。

**Non-Goals:**

- 地磅 / 卡口 / 成品业务角色或独立 entity、萧山上报。
- 实现华夏智信完整 SDK（保持现有占位行为）。
- 拆 WinExe、改 UrbanManagement。
- 清扫与本能力无关的全局 `LprDeviceType` 历史注释（触及处改掉即可）。

## Decisions

### 1. 权威在配置行，不在 SystemSettings

`LicensePlateRecognitionConfig.DeviceType` 为权威。加载：反序列化后若缺省/默认占位无法区分时，用 `SystemSettings.LprDeviceType` 回填每一条缺类型的行（类型归属方法，如 `ApplyLegacyDeviceType(LprDeviceType)`，禁止 Service 逐字段拼业务）。保存：写出每行 `DeviceType`；`SystemSettings.LprDeviceType` MAY 写成列表首条有效配置的类型（兼容旧客户端），UI 不再展示全局 Combo。

备选：立刻删除全局属性 → 旧客户端读设置会丢厂商。否决。

### 2. DeviceManager 按「出现过的类型」启停

扫描 `LicensePlateRecognitionConfigs` 中有效行的 `DeviceType`：有 Hikvision 则启动海康 LPR 服务；有 Vzvision 则启动臻识。二者可同时为真。无对应行则不启动该厂商。关闭路径仍停两边（与今日 Close 类似），避免泄漏。

备选：继续互斥启动 → 无法混厂商，否决。

### 3. 对话框内类型驱动字段

`AddLprDialogViewModel` 持有可绑定的 `DeviceType`（非只读构造注入）。`WhenAnyValue` 驱动海康 Channel / 臻识连接字段与默认值（沿用 `HikvisionLprDefaults` / `VzvisionLprDefaults`）。Save 把 `DeviceType` 写入 `LicensePlateRecognitionConfigViewModel`。编辑打开时用该行类型。设置 DataGrid：厂商列或常显用户名/端口列，**禁止**再用全局 `WhenAnyValue(LprDeviceType)` 藏整表列。

### 4. 在线与抓拍按行

`ILprDeviceResolver.GetDevice(config.DeviceType)`。在线：对每条 config 用其 `DeviceType` 调 `ILprDeviceOnlineStatusService`（扩展现有「一个 type + 列表」API，改为按行或内部按行循环）。状态栏 **仍** 为任一行在线即为在线（any-online）。主动抓拍：对每条有效配置解析对应 `ILprDevice`，不支持主动抓拍的类型跳过并记日志。道闸：识别消息已带 `DeviceType` 时以其为准；否则用匹配到的配置行类型。仅 Vzvision 行执行 SDK 开闸。

### 5. UI 不碰 Repository

设置仍走 `ISettingsService`。无新 DI Service 仅为映射（`minimal-di` / `type-owned-methods`）。

## Risks / Trade-offs

- [混厂商双 SDK 监听] → 联调海康+臻识各至少一台；Start/Stop 成对；日志带 `DeviceType`。
- [回填错误默认] → 缺字段才用全局；已有 `DeviceType` 不得覆盖。
- [DataGrid 混厂商列] → 优先增加「设备类型」列并常显连接字段，避免按错误类型藏列。
- [兼容镜像与权威不一致] → 文档与代码注释标明运行时只信行字段。

## Migration Plan

1. 发版后首次加载：回填 → 用户保存后 JSON 带 `DeviceType`。
2. 回滚：旧版本忽略未知 JSON 字段（System.Text.Json 默认）；仍可读全局 Combo。新版本写的行字段旧版不理解，旧版会回到全局互斥行为。
3. 无需 DB migration 脚本。

## Open Questions

无阻塞项。华夏行若存在：不启动未实现的 SDK，与今日一致。
