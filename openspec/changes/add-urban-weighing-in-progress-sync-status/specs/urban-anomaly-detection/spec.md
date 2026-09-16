## ADDED Requirements

### Requirement: Deferred anomaly create must not become cloud-normal early

When Urban weighing creates an extension with deferred anomaly evaluation, the client MUST keep the extension out of the upload queue (`SyncStatus.WeighingInProgress`) until formal evaluation has run and the cycle promotes the row to `Pending`. UrbanManagement MUST NOT re-run weight upper/lower/deviation threshold rules on receive; empty-plate server fallback is specified under `urban-weighing-api`.

#### Scenario: Deferred create uses WeighingInProgress

- **WHEN** MaterialClient.Urban creates an Urban weighing extension with deferred anomaly evaluation
- **THEN** it MUST apply the deferred anomaly placeholder (`IsAnomaly = false` until formal evaluation)
- **AND** MUST set `SyncStatus` to `WeighingInProgress`
- **AND** MUST NOT upload that record while still `WeighingInProgress`

#### Scenario: Formal evaluation before first eligible upload

- **WHEN** the extension is promoted to `Pending` for the first upload after deferred create
- **THEN** formal `IUrbanAnomalyDetector` evaluation MUST already have been applied to `IsAnomaly` / `AnomalyReason`
- **AND** the upload DTO MUST carry that evaluated `IsAnomaly` value

#### Scenario: Empty plate after formal evaluation uploads as anomaly

- **WHEN** formal evaluation finds an empty plate (`EmptyPlate`) and the extension is `Pending`
- **THEN** the next successful upload MUST send `IsAnomaly = true` with the empty-plate reason to UrbanManagement

## MODIFIED Requirements

### Requirement: 异常判定权威源为 MaterialClient

Urban 称重记录的 `IsAnomaly` 业务含义 SHALL 主要由 MaterialClient.Urban 在创建与本地审批时判定。UrbanManagement MUST NOT 使用阈值规则（上下限、偏差百分比）重新计算或覆盖该标志。**例外：** 接收上传路径上对 **空/空白车牌** 的服务端兜底（见 `urban-weighing-api`）可将记录强制标为异常。审批清除逻辑见 `urbanmanagement-weighing-record-approval`。

#### Scenario: 客户端创建时判定异常

- **WHEN** MaterialClient.Urban 创建 Urban 模式称重记录（正式评估路径）
- **THEN** MUST 调用 `IUrbanAnomalyDetector` 并写入本地 `UrbanWeighingExtension.IsAnomaly`
- **AND** 上传 DTO MUST 携带相同 `IsAnomaly` 值（在提升为可上传之后）

#### Scenario: 服务端不得阈值重算

- **WHEN** UrbanManagement 接收上传或处理审批以外的写路径
- **THEN** MUST NOT 调用基于 `UpperLimit`/`LowerLimit`/`DeviationPercentage` 的检测器覆盖 `IsAnomaly`

#### Scenario: 服务端空车牌兜底为例外

- **WHEN** UrbanManagement `ReceiveAsync` 收到车牌为空或空白的称重记录
- **THEN** 服务端 MUST 将该记录标为异常（即使客户端 `IsAnomaly` 为 false）
- **AND** MUST NOT 因此启用重量阈值重算
