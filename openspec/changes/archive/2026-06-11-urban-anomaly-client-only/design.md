## Context

Urban 称重链路存在双端异常判定：

- **MaterialClient.Urban**：创建记录与本地审批时调用 `IUrbanAnomalyDetector`（车牌空、上下限偏差），写入 `UrbanWeighingExtension.IsAnomaly` 并随上传 DTO 传给服务端。
- **UrbanManagement**：接收上传与 Web 审批保存时再次调用服务端 `IUrbanAnomalyDetector`（独立 kg 阈值配置），可能覆盖客户端标志，导致现场已修正的数据在服务端仍无法进入 `GovSyncBackgroundWorker`。

业务要求：**异常仅由客户端在称重现场判定**；服务端只负责格式校验与同步编排。

## Goals / Non-Goals

**Goals:**

- 移除 UrbanManagement 全部阈值型异常检测（`UrbanAnomalyDetector`、`UrbanAnomalyDetectionOptions`、相关配置与测试）。
- 客户端上传时 `IsAnomaly` 原样持久化，接收路径不重算。
- 服务端审批：车牌通过 `PlateNumberValidator`、重量为有效正数 → 视为审批通过，将 `IsAnomaly` 置为 `false` 并重置政府同步为待同步。
- 保持政府同步 Worker 对 `IsAnomaly == true` 的跳过逻辑不变。
- 审批页与 API 仅允许 `IsAnomaly == true` 的记录进入审批；成功后变为正常，不可再次审批。
- Web 审批在校验通过后、写库前弹出确认框，与 MaterialClient 二次确认交互对齐。

**Non-Goals:**

- 不修改 MaterialClient 本地阈值配置、设置页、`UrbanAnomalyDetector` 实现。
- 不改变客户端审批后本地重算 `IsAnomaly` 的行为。
- 不新增服务端基于重量的异常规则（包括「软校验」或告警）。

## Decisions

### 1. 服务端审批通过即清除异常标

**选择**：Web/API 审批成功且车牌、重量校验通过时，显式设置 `IsAnomaly = false`，而非调用阈值检测器。

**理由**：用户表述「有效值即为审批通过进行同步」；审批是人工纠正入口，通过即表示可上云。

**备选**：审批不改 `IsAnomaly`，仅依赖同步门禁——被拒绝，无法保证修正后可同步。

### 2. 上传接收路径信任客户端 `IsAnomaly`

**选择**：`ReceiveAsync` 将 DTO 中的 `IsAnomaly` 写入实体，不调用任何检测服务。

**理由**：异常唯一来源为客户端；避免双端不一致。

**备选**：接收时若车牌为空强制 `IsAnomaly=true`——属于服务端判定，与需求冲突。

### 3. 删除 UrbanManagement 检测基础设施

**选择**：移除 `IUrbanAnomalyDetector` 实现、Options 绑定、`appsettings` 节及 DI 注册；删除专属单元测试。

**理由**：无调用方后保留只会造成误用。

**备选**：保留死代码「以备将来」——增加维护成本且易被误接入。

### 4. 客户端行为不变

**选择**：`weighing-record-approval`、`urban-polling-background-service` 等客户端 spec 不在本 change 修改。

**理由**：本 change 范围仅限服务端；客户端已是异常判定权威源。

### 5. 审批一次性（仅异常可审）

**选择**：列表与 `ApproveAsync` 双重门禁——`IsAnomaly == false` 时 UI 不展示可用审批操作，API 返回业务错误拒绝重复审批。

**理由**：审批即人工纠正异常；通过后即为正常数据，不应反复修改。

**备选**：正常记录仍可审批——与「审批后即为正常值」冲突。

### 6. 保存前二次确认

**选择**：LayUI 审批弹窗点击「确定」且车牌/重量校验通过后，先弹出确认框（如「确认提交本次修改？」），确认后才调用 `ApproveAsync`。

**理由**：降低误操作；与客户端 `urban-approval-confirmation` 体验一致。

**备选**：仅依赖弹窗一次确定——不符合用户明确要求。

## Risks / Trade-offs

- **[风险] 恶意客户端上报 `IsAnomaly=false` 的异常数据** → 服务端不再二次拦截；接受为业务权衡，依赖现场客户端与审批人工复核。
- **[风险] 历史服务端配置依赖** → 部署时移除 `UrbanAnomalyDetection` 配置节；文档与运维说明同步更新。
- **[风险] 双端审批语义差异** → 客户端审批仍可能重算异常；服务端 Web 审批仅格式校验。在 `urbanmanagement-weighing-record-approval` spec 中明确，避免实现混用检测器。

## Migration Plan

1. 部署 UrbanManagement：移除检测服务与配置，更新审批 AppService 与审批页。
2. 从环境配置中删除 `UrbanAnomalyDetection` 节（已无服务端读取方）。
3. 无需 MaterialClient 同步发版（行为不变）；建议同迭代或稍后部署均可。
3. 回滚：恢复检测器调用与配置（若已删除代码需从 git 还原）。

## Open Questions

（无）
