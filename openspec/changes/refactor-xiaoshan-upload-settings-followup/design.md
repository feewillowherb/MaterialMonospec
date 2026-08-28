## Context

本 change：**验收仅 MC 设置 UI → `UrbanSettingsJson.ModesJson`。** 删除 MC+UM 的「上报配置双端同步」，且 **不把该同步列入验收**。

约束：ReactiveUI；ViewModel → Service；禁止 tuple；UI 不得引用 Urban。

## Goals / Non-Goals

**Goals:**

- 核心 UI 字段本地读写 `UrbanSettings.XiaoshanUpload.ModesJson`
- 物理删除配置同步：客户端推送栈 + UM Get/Write / 管理端配置编辑
- 本切片验收 **不含** 客户端配置同步到服务端

**Non-Goals:**

- 验收或修复 MC→UM 配置 Get/Write、version 冲突、失败回滚服务端快照
- 改主仓 `pipelines/graphs/govsync` 探测脚本
- 设置窗非城管分区重构
- 强制删除仍被上报流水使用的 UM/MC 字段映射（仅切断配置同步；流水另议）

## Decisions

### D1：保存只走 ISettingsService

禁止 LocalEvent、Facade、UM Write。验收只看本地 JSON。

### D2：UM 删除配置同步面

删除（或等价不可达）：

- `IXiaoshanUploadConfigAppService`（及实现）GetByProjectId / Write
- HTTP/DTO：`XiaoshanUploadConfigDto`、`XiaoshanUploadConfigWriteDto`、WriteResult、`expectedConfigVersion`、`clientProtocolVersion`
- 管理端萧山上报**配置**编辑 UI
- 仅随 Write 写入的 `XiaoshanUploadConfigChangeLog`（若存在）
- 实体 `XiaoshanUploadConfig`：无其它引用则删并加 migration；有残留引用则先删 API/UI，tasks 注明

**不**把「删完后仍能从客户端把配置写到服务器」当作通过条件。

### D3：MC 删除清单

同前：Event/handler、Facade、ClientService、SettingsEnvelope、`SettingsJson`、设置用 field mapping。保留 Modes 信封 + form mapper + 城管 AXAML。

### D4：核心字段 / AccessCode

与既有 D3/D4 相同（三模式 + 进出场/场地；AccessCode 不入库）。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 误删上报流水 | grep 配置 AppService vs 上报 HttpClient；流水保留 |
| 运营仍用 UM 网页改配置 | 本切片去掉该面；配置只在客户端本地 |

## Migration Plan

1. MC：去掉同步依赖，只留 UrbanJson
2. UM：去掉 Get/Write 与管理端配置编辑
3. 无引用则 drop 配置表
4. 验收：**仅**设置核心字段保存读回；**不做**同步联调

回滚：git 恢复两仓。

## Open Questions

UM `XiaoshanUploadConfig` 表若仍被上报读取：先删客户端同步与管理端 Write，读路径改为默认/其它配置源，并在 tasks 注明。默认按「表只服务双端配置同步」删除。
