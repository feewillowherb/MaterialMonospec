## Context

- **客户端（MaterialClient.Urban）**：列表行「审批」→ `WeighingRecordEditDialog`（车牌、重量；客户端另有 LRP/UrbanPhoto **只读预览**）→ `PlateNumberValidator` → `UpdateWeighingRecordAsync` → `PollingBackgroundService` 上云。Web 本期 **不对齐** 客户端图片预览，仅对齐车牌/重量审批语义。
- **服务端（UrbanManagement）**：`IUrbanWeighingRecordAppService` 仅有 `ReceiveAsync`、`GetListAsync`；`GovSyncBackgroundWorker` 扫描 `SyncType != 1` 且 `IsAnomaly == false` 的记录上送政府平台。Web 列表为 LayUI + `/api/app/urban-weighing-record`。
- **缺口**：服务端无审批 API、无异常检测服务、列表无审批入口。

## Goals / Non-Goals

**Goals:**

- Web 审批流程与客户端 **业务语义一致**：可改车牌/重量、车牌校验、重算异常、复位待同步、不即时政府 HTTP。
- 管理员在 UrbanManagement 修正已入库记录，无需依赖客户端重传才能改车牌/重量。
- 复用现有 LayUI / ABP 约定 API 风格（参考 `Project/Index.cshtml`、`GovProject` CRUD）。

**Non-Goals:**

- 不实现客户端 MaterialClient.Urban 的修改（已具备审批）。
- 不新增「客户端在线审批」或双向同步协议（审批仅改服务端 `UrbanWeighingRecord`）。
- 不在本 change 内实现审批历史审计表（可 follow-up）。
- 不修改 `GovSyncBackgroundWorker` 周期或政府 API 载荷格式（除非审批后发现必须清零 `RetryCount`，见决策 D4）。
- **不实现** 审批相关的图片查看、上传、替换、删除；**不实现** 审批弹层内的附件预览（见决策 D5 / TODO）。

## Decisions

### D1: 审批入口 — LayUI 表格操作列 + `layer.open` 弹层

**选择**：在 `UrbanWeighingRecord/Index.cshtml` 增加操作列，「审批」打开 LayUI 弹层（表单：**仅**车牌、重量；无图片区域）。

**理由**：与项目内 LayUI 列表 + 弹层模式一致；无需新 MVC 页面路由。

**备选**：独立 `/UrbanWeighingRecord/Approve/{id}` 页面 — 更重，与 iframe 子页风格不一致。

### D2: 服务端 API — `ApproveAsync` on `IUrbanWeighingRecordAppService`

**选择**：新增 `ApproveAsync(UrbanWeighingRecordApproveInputDto input)`，暴露为 ABP 约定 `POST .../approve`。

**输入**：`long id`（服务端 `UrbanWeighingRecord.Id`）、`string plateNumber`、`decimal totalWeight`。

**处理**（单 UOW）：

1. 加载 `UrbanWeighingRecord` by `id`。
2. 校验车牌（非空 + 中国车牌规则，与客户端一致）。
3. 校验 `totalWeight > 0`。
4. 更新 `PlateNumber`、`TotalWeight`。
5. 调用 `IUrbanAnomalyDetector.IsAnomaly(record, config)` 写回 `IsAnomaly`。
6. 设置 `SyncType = 0`（待同步）；可选 `RetryCount = 0`（见 D4）。
7. 返回 `UrbanWeighingRecordOutputDto`（或精简 Approve 输出）。

**禁止**：在 `ApproveAsync` 内直接调用 `IGovSyncHttpClient` 或同步触发政府上传。

### D3: 异常检测 — 服务端移植 `UrbanAnomalyDetector` 规则

**选择**：在 `UrbanManagement.Core` 新增 `IUrbanAnomalyDetector` / `UrbanAnomalyDetector`，规则与 `MaterialClient.Common.Services.UrbanAnomalyDetector` 相同：

- 车牌空 → 异常
- `TotalWeight > UpperLimit * (1 + Deviation%/100)` → 异常
- `TotalWeight < LowerLimit * (1 - Deviation%/100)` → 异常

配置：`appsettings.json` 节 `UrbanAnomalyDetection`（默认 UpperLimit=30、LowerLimit=2、DeviationPercentage=10，与客户端一致）。

**理由**：审批后列表「数据质量」列须与客户端重算结果一致。

**备选**：共享 `MaterialClient.Common` 程序集 — UrbanManagement 不应依赖 MaterialClient 桌面程序集。

### D4: 审批后 `RetryCount` 与 `SyncTime`

**选择**：审批时将 `SyncType = 0`；**同时将 `RetryCount` 置 0**（若此前同步失败），便于 `GovSyncBackgroundWorker` 重新尝试。

**不**清空 `SyncTime`/`LastErrorTime`（保留排障信息），除非产品要求隐藏失败痕迹。

### D5: 图片/附件 — 本期不做，预留 TODO

**选择**：本 change **不** 实现附件预览 API、弹层图片区，也 **不** 修改 `UrbanWeighingRecordAttachment` / `AttachmentFile`。

**预留**（实现时在 `Index.cshtml` 或 `UrbanWeighingRecordAppService` 顶部注释）：

```text
// TODO(approval-attachments): 审批弹层只读展示 LPR/现场图（GetApprovalAttachmentsAsync + 静态文件 URL），不对齐客户端图片编辑。
```

**理由**：产品确认审批仅需改车牌/重量；图片能力可后续单独 change 接入。

### D6: 车牌校验

**选择**：`UrbanManagement.Core` 内 `PlateNumberValidator`（或 `IPlateNumberValidator`），规则与客户端 `PlateNumberValidator.IsValidChinesePlateNumber` 对齐；无效时 API 返回 400 + 友好消息（与客户端「车牌号不符合规范请修改」一致）。

### D7: 与客户端数据流关系

| 场景 | 行为 |
|------|------|
| 客户端审批后上云 | `ReceiveAsync` 写入已含最新车牌/重量/IsAnomaly；Web 可再次审批覆盖 |
| 仅客户端上云、Web 审批 | 改服务端 `UrbanWeighingRecord`；**不**回写客户端 SQLite |
| Web 审批后政府同步 | `GovSyncBackgroundWorker` 拾取 `SyncType=0` 且 `IsAnomaly=false` |

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 客户端与服务端 `IsAnomaly` 阈值不一致 | 配置默认值与文档对齐；后续可统一配置源 |
| Web 改库后客户端仍显示旧数据 | 文档说明双端数据源；不在本 change 做回写 |
| 重量单位（kg vs 吨）与阈值比较 | 与现网客户端保持一致（同一 `TotalWeight` 字段语义）；实现时对照客户端 detector 单测 |

## Migration Plan

1. 实现 Core 服务 + API + 配置。
2. 更新 `Index.cshtml` 列表与弹层。
3. 本地验证：审批 → 列表 `IsAnomaly`/同步状态更新 → Worker 重新上送。
4. 回滚：隐藏操作列；API 保留但不调用。

## Open Questions

- 审批权限：是否需登录/角色（当前 UrbanManagement 内页多无细粒度 RBAC）— 默认与现有管理页相同，不新增角色。
- 是否需在审批弹层展示 `ClientRecordId` 只读 — 建议展示，便于对照客户端记录。
