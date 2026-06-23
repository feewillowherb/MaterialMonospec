## Why

当前 Urban 异常判定在客户端（MaterialClient.Urban）与服务端（UrbanManagement）各有一套阈值逻辑，审批后服务端会重新计算 `IsAnomaly`，可能导致客户端已审批通过的数据在服务端仍被标为异常、无法进入政府同步。业务上异常应仅在称重现场由客户端判定；服务端审批职责是校验车牌与重量格式有效性，通过后即视为可同步。

## What Changes

- **UrbanManagement 移除服务端异常重算**：删除或停用 `IUrbanAnomalyDetector` 在接收上传、审批保存等路径上的调用；`IsAnomaly` 以客户端上报值为准，服务端不再覆盖。
- **审批通过条件收紧为格式校验**：服务端（Web 审批页）修改后车牌通过 `PlateNumberValidator`、重量为有效正数，即完成审批并将 `IsAnomaly` 置为 `false`、同步状态重置为待同步；不再依据上下限偏差重新打异常标。
- **审批一次性**：仅 `IsAnomaly == true` 的记录可发起审批；审批成功后变为正常值，列表/API 不得再次对该记录提供审批入口。
- **审批前确认修改**：Web 审批弹窗在输入校验通过后、持久化前 MUST 弹出二次确认，操作员确认后才提交；取消则保持原数据不变。
- **政府同步门禁保持 `IsAnomaly` 字段**：`IsAnomaly == true` 的记录仍跳过政府同步，但该标志仅由客户端产生并在上传时写入，服务端只读存储。
- **配置清理**：移除 UrbanManagement 侧 `UrbanAnomalyDetection` 配置节及相关 Options/DI 注册（**BREAKING**：运维配置项减少）；MaterialClient 侧阈值配置与本地判定逻辑保持不变。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-anomaly-detection`: 明确异常判定仅发生在 MaterialClient；移除 UrbanManagement 服务端检测配置与服务要求。
- `urbanmanagement-weighing-record-approval`: 仅异常可审批、审批后不可再审、保存前二次确认；有效车牌+重量即清除异常并触发待同步。
- `urban-weighing-api`: 接收客户端上传时持久化客户端提交的 `IsAnomaly`，服务端不得在上传接收路径重算。
- `urban-weighing-approval-enhancements`: 移除或限定「审批后重算异常标志」为仅客户端行为（若该 spec 仍涵盖服务端则同步修改）。

## Impact

- **UrbanManagement.Core / App**：`UrbanAnomalyDetector`、`UrbanAnomalyDetectionOptions`、审批 AppService 中的异常重算逻辑；`appsettings` 配置节。
- **UrbanManagement 审批页**：仅异常行显示可用「审批」；保存前增加确认框；审批后 `IsAnomaly=false` 且审批入口禁用/隐藏。
- **MaterialClient.Urban**：本地 `UrbanAnomalyDetector`、设置项、创建/审批时异常判定、上传 DTO 中的 `IsAnomaly` 保持不变。
- **政府同步 Worker**：继续跳过 `IsAnomaly == true`；无需改动门禁条件，仅数据来源变为客户端唯一。
- **测试**：删除或调整 UrbanManagement 侧异常检测单元测试；补充「审批有效值不重算异常」「上传保留客户端 IsAnomaly」测试。
