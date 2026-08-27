## Why

萧山上报配置与设置窗导航已在 Epic 落地，但实现仍带有切片遗留：分区切换靠 `FindControl` 字典与 code-behind 扫子树、`SettingsWindowViewModel` 直接拼信封/保留静态字段、保存异常被吞掉、客户端字段映射与服务端 `dataSource` 取值不完全一致。需要在不改产品主路径的前提下把壳层与映射收口到可维护、可测试的实现。

## What Changes

- 设置窗分区切换改为由 `SelectedSettingsSection` 声明式驱动可见性，删除导航 `FindControl` 注册表与按子控件扫描 `IsVisible` 的主路径
- 将城管配置「表单 ↔ ModesJson/SettingsJson」及未展示静态字段的保留逻辑从 `SettingsWindowViewModel` 抽到 Common Service + 命名 `record`（禁止 tuple）；Urban 宿主注入实现，主程序无城管配置时不调用
- 系统设置保存失败（含萧山推送超时/异常）SHALL 向用户提示，MUST NOT 空 `catch` 后当作成功关窗
- 客户端推送前对 modes 信封做与协议 v3 一致的启用模式校验，避免全关三模式后才被服务端拒绝
- 对齐 Weighbridge `dataSource`：客户端映射与 UrbanManagement 同样优先 mode settings，缺省再回落到 `WEIGHBRIDGE_XIAOSHAN`

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `settings-window-section-navigation`: 分区切换 MUST 由 ViewModel 选中分区驱动，不得依赖按名称注册导航控件字典作为主路径
- `settings-ui`: 保存失败 MUST 可感知（提示），不得静默吞掉异常并关闭窗口
- `xiaoshan-upload-config`: 城管配置 JSON 组装/还原 MUST 经 Common Service；客户端在推送前校验至少一模式启用
- `xiaoshan-upload-field-mapping`: Weighbridge `dataSource` 解析与服务端一致（mode settings 优先）

## Impact

- **MaterialClient.Common**：`IXiaoshanUploadSettingsFormMapper` 与 form/preserved `record`（信封类型已在 Common）
- **MaterialClient.UI**：`SettingsWindow.axaml` / `.axaml.cs`、`SettingsWindowViewModel`（仅引用 Common，禁止引用 Urban）
- **MaterialClient.Urban**：`XiaoshanUploadFieldMappingService` dataSource 对齐；可选注册 mapper 若实现放 Urban 则 MUST `ExposeServices` 且接口在 Common
- **UrbanManagement**：本 change **不改** Get/Write API、协议档位、管理端弹窗；仅若客户端映射对齐需要对照现有 `XiaoshanUploadFieldMappingService`
- 无 **BREAKING** API；无新 EF migration
