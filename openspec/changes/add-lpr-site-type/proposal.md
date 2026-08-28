## Why

城管现场会把同一套车牌识别设备装在地磅、卡口或成品口，设置里需要先记下「装在哪一类点」，否则后续无法按点位筛选配置。本期只把该分类做成可保存的基线字段；识别、道闸、称重仍不得依赖它。

## What Changes

- 每条 `LicensePlateRecognitionConfig` 增加站点类型字段（地磅 / 卡口 / 成品），进入内核设置 JSON 基线；缺省与旧数据均为 **地磅**。
- 增加与编辑 LPR 时，Urban 宿主可切换三种类型；**非 Urban**（标准、固废、回收等）界面只显示地磅且不可改，保存结果 MUST 为地磅。
- **禁止**在本期让 DeviceManager、匹配、道闸、称重、上云按该字段分支。

## Capabilities

### New Capabilities

- `lpr-site-type`: LPR 配置行的站点类型枚举、默认地磅、JSON 兼容、以及「无运行时业务语义」约束。

### Modified Capabilities

- `settings-ui`: 增加/编辑 LPR 对话框与表格展示站点类型；Urban 可切换，其他产品强制地磅。

## Impact

- **MaterialClient.Common**：配置类型、JSON 序列化（缺字段默认地磅）。
- **MaterialClient.UI**：`AddLprDialog` / 设置页 LPR 表格；沿用现有「增加/编辑共用对话框」。
- UrbanManagement / BasePlatform / SDK / 称重流水 **无行为变更**。
