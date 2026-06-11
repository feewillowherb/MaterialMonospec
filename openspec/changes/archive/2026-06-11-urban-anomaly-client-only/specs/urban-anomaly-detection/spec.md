## ADDED Requirements

### Requirement: 异常判定权威源为 MaterialClient

Urban 称重记录的 `IsAnomaly` 业务含义 SHALL 由 MaterialClient.Urban 在创建与本地审批时判定；UrbanManagement MUST NOT 使用阈值规则（上下限、偏差百分比）重新计算或覆盖该标志，接收上传路径除外下的审批清除逻辑见 `urbanmanagement-weighing-record-approval`。

#### Scenario: 客户端创建时判定异常
- **WHEN** MaterialClient.Urban 创建 Urban 模式称重记录
- **THEN** MUST 调用 `IUrbanAnomalyDetector` 并写入本地 `UrbanWeighingExtension.IsAnomaly`
- **AND** 上传 DTO MUST 携带相同 `IsAnomaly` 值

#### Scenario: 服务端不得阈值重算
- **WHEN** UrbanManagement 接收上传或处理审批以外的写路径
- **THEN** MUST NOT 调用基于 `UpperLimit`/`LowerLimit`/`DeviationPercentage` 的检测器覆盖 `IsAnomaly`

## REMOVED Requirements

### Requirement: UrbanManagement 服务端异常检测配置（千克）

**Reason**: 异常判定职责收回客户端；服务端不再维护独立阈值配置。

**Migration**: 从 UrbanManagement `appsettings` 删除 `UrbanAnomalyDetection` 节；移除 `UrbanAnomalyDetectionOptions` 与相关 DI 注册。
