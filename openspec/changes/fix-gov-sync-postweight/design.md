## Context

UrbanManagement 通过 `GovSyncBackgroundWorker` → `GovSyncManager` → `IGovSyncHttpClient.PostWeightAsync` 将 `UrbanWeighingRecord` 转发至政府平台 `StorageOptions.GovAddress`。

联调日志（`docs/gov-sync-postweight-analysis.md`、`_temp/post-weight-result-20260615-110808.txt`）确认：

- **请求契约**：`snapImages` 为 JSON 数组；`carType` 为 `"大车"`/`"小车"`；`grossWeight`/`goodsWeight` 为千克数值
- **响应契约**：`{ "code": 200, "msg": "操作成功", "data": null }`，**无** `success` 字段

当前 `GovSyncManager` 使用 `response.Success` 判定，Refit 反序列化后恒为 `false`，造成「平台成功、本地失败」。部分 payload 字段问题在工作区已局部修复，但成功判定与强类型出站仍未落地。

约束：

- 子仓库实现位于 `repos/UrbanManagement`
- 禁止使用 tuple；多值组合使用命名 `record`
- 不修改旧版 `POST /Api/Post` 入站契约
- 本 change 不处理 P2 设备字段透传、`VehicleType` 覆盖（留待后续）

## Goals / Non-Goals

**Goals:**

- 政府同步成功/失败判定与政府 API `code` 对齐
- 出站 payload 字段类型与联调验证格式一致（`snapImages[]`、`carType` 中文）
- 附件 Base64 正确写入 `snapImages`
- 使用 Core 层强类型 DTO 替代匿名 `object`，Refit 序列化行为可预测
- 单元测试覆盖响应判定与 payload 构建
- 对齐 `gov-sync-worker` 与 `urban-weighing-api` spec 中的 `carType` 描述

**Non-Goals:**

- 修改政府平台 API 或 `GovAddress` 配置方式
- 重构 `LegacyGovSyncAppService` / `GovSyncData` 历史链路
- 透传 `equipmentNumber`/`equipmentType`/`inOutType` 自 `UrbanWeighingRecord`（当前实体无对应字段）
- 用 `VehicleType` 覆盖重量阈值推导的 `carType`
- MaterialClient 侧变更

## Decisions

### D1: 成功判定以 `Code == 200` 为准

**选择**：在 `GovSyncManager.ProcessRecordAsync` 中，以 `response.Code == 200` 作为业务成功条件；失败为 `Code != 200` 或 HTTP/网络异常。

**理由**：联调响应仅有 `code`/`msg`/`data`；`Success` 属性无 JSON 映射，不可依赖。

**备选**：

- 保留 `Success` 并在反序列化后根据 `Code` 填充 — 增加间接层，不如直接读 `Code`
- 自定义 `JsonConverter` 合成 `Success` — 过度设计

**实现要点**：

- `GovResponseBase<T>` 保留 `Code`/`Msg`/`Data`；`Success` 可标记 `[JsonIgnore]` 或移除，避免误用
- 日志同时记录 `Code` 与 `Msg`

### D2: 出站 payload 使用 Core 层 `GovSyncWeightPayload` record

**选择**：在 `UrbanManagement.Core` 新增 `GovSyncWeightPayload` record（或等价命名 DTO），字段与 `GovRequestWeightDto` 对齐，含 `[JsonPropertyName]`。`BuildGovPayload` 返回该类型；`PostWeightAsync` 签名改为 `[Body] GovSyncWeightPayload payload`。

**理由**：

- `GovRequestWeightDto` 位于 App 层，Core 的 `GovSyncManager` 不宜依赖 App
- 强类型防止 `snapImages` 再次退化为 `string`
- 与 AGENTS「DTO 使用 record」一致

**字段映射**（与联调成功 payload 一致）：

| 字段 | 来源 |
|------|------|
| `carNo` | `record.PlateNumber` |
| `carColor` | `record.VehicleColor` |
| `carNoColor` | `record.PlateColor` |
| `buildLicenseNo` | `record.BuildLicenseNo` |
| `inOutType` | `0`（默认） |
| `equipmentNumber` / `equipmentType` | `""`（默认，本 change 不变） |
| `grossWeight` | `record.TotalWeight` |
| `tareWeight` | `0` |
| `snapTime` | `WeighingTime` 格式 `yyyy-MM-dd HH:mm:ss` |
| `snapImages` | `ReadAttachmentFilesAsync` → `string[]`（空则 `[]`） |
| `carType` | `TotalWeight > 4500 ? "大车" : "小车"` |
| `deviceID` | `record.DeviceId` |
| `siteType` | `record.SiteType` |
| `goodsWeight` | `record.TotalWeight.ToString()` |

### D3: Refit 使用 System.Text.Json 与 MVC 对齐

**选择**：在 `UrbanManagementAppModule` 注册 `IGovSyncHttpClient` 时配置 `RefitSettings`，使用 `System.Text.Json.JsonSerializerOptions`：

- `PropertyNamingPolicy = JsonNamingPolicy.CamelCase`
- `DefaultIgnoreCondition = WhenWritingNull`（与 MVC 一致，减少 `carColor: null` 不确定性）

**理由**：匿名 `object` + 默认 Refit 设置是联调字段不一致的诱因之一。

### D4: 单元测试放在 UrbanManagement 测试项目

**选择**：新增或扩展现有测试项目，覆盖：

1. `GovResponseBase` 反序列化：仅 `code:200` 时判定成功
2. `BuildGovPayload`：`snapImages` 为数组、`carType` 中文、重量阈值 4500 kg

**理由**：防止回归；政府 API 不可在 CI 中稳定调用。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 政府平台成功码非 200 | 将成功码提取为常量 `GovApiSuccessCode = 200`，文档注明；若平台变更可配置化 |
| 已错误标为 `SyncType=2` 的历史记录 | 运维可通过 Web 审批重置 `SyncType=0` 重新入队（现有 spec 已支持） |
| `GovResponseBase.Success` 移除影响其他调用方 | 搜索全仓库引用；本 change 仅 GovSyncManager 使用 |
| Refit JSON 配置影响其他 Refit 客户端 | 仅对 `IGovSyncHttpClient` 单独配置 `RefitSettings`，不动 `IBasePlatformProjectHttpClient` |

## Migration Plan

1. 合并代码至 `repos/UrbanManagement` 并部署
2. 观察 `GovSyncBackgroundWorker` 日志：`Code=200` 记录应出现 `SyncType=1`
3. 对因误判失败且 `RetryCount` 未耗尽的记录，可选批量将 `SyncType` 重置为 `0`（SQL/管理脚本，非本 change 必做）
4. 回滚：还原 `GovSyncManager` 与 Refit 注册；无 schema 迁移

## Open Questions

- 政府平台是否在无图片时强制要求非空 `snapImages`？当前联调 `[]` 已成功，按空数组实现。
- 是否存在除 `200` 以外的业务成功码？当前按联调日志仅处理 `200`。
