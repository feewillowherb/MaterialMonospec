## Why

城管配置只验收：设置 UI 核心字段写入客户端 `UrbanSettingsJson` 并能读回。客户端把配置同步到 UrbanManagement（Get/Write、乐观并发、管理端双端编辑）不在验收面，MC 与 UM 两侧相关代码应删除，避免半残同步栈被误测、误接。

## What Changes

- **唯一保留并验收**：MaterialClient `SettingsWindow`「城管配置」核心字段 ↔ `UrbanSettings.XiaoshanUpload.ModesJson`，经 Common mapper，随 `ISettingsService.SaveSettingsAsync` 写入 `UrbanSettingsJson`
- **核心字段**：三模式启用；地磅进出场；卡口进出场+场地；成品进出场+场地。AccessCode 只读不入库
- **删除且不验收「客户端配置 → 服务端」**：MC LocalEvent/Facade/Refit Get+Write；UM `XiaoshanUploadConfig` Get/Write AppService 与 HTTP、Write DTO/`configVersion`/clientProtocolVersion、管理端上报配置编辑（ProjectManagement 弹窗等）、仅服务该 Write 的变更日志。无调用则删实体与后续 migration
- **MC 其余**：删 `XiaoshanUploadSettingsEnvelope`、本地 `SettingsJson`、设置路径上的 field mapping；本地模型仅 `ModesJson`
- **不删**：设置窗其它分区、分区导航、主仓 govsync pipeline。称重/卡口/成品**上报流水**若独立于配置 Get/Write 则本切片不强制删除（也不验收配置同步）

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `xiaoshan-upload-config`: MaterialClient SHALL 仅本地持久化 `ModesJson`；SHALL NOT 同步到 UrbanManagement。UrbanManagement SHALL NOT 再提供给客户端/管理端的配置 Get/Write 同步面
- `settings-ui`: Urban 宿主保存 SHALL 只写 `UrbanSettingsJson`，MUST NOT 走萧山配置 LocalEvent / Facade / UM Write

## Impact

- **MaterialClient.Common / UI / Urban**：删除配置同步栈；保留设置 UI → UrbanJson
- **UrbanManagement**：删除配置 Get/Write 与对应管理端编辑；可能含 EF 实体/迁移（仅当该表只服务配置同步）
- **不验收**：任何 MC→UM 配置推送、冲突覆盖、打开设置拉服务端
