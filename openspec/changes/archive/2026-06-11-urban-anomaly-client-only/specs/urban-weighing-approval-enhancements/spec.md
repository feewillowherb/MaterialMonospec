## REMOVED Requirements

### Requirement: Anomaly flag update after approval

**Reason**: 审批后阈值型异常重算仅保留在 MaterialClient.Urban 本地路径；UrbanManagement Web/API 审批改由 `urbanmanagement-weighing-record-approval` 定义「格式校验通过即清除异常标」，不再调用 `UrbanAnomalyDetector`。

**Migration**: 删除 UrbanManagement 审批 AppService 中对 `IUrbanAnomalyDetector` / `UpdateAnomalyFlagAsync` 的调用；MaterialClient `UpdateWeighingRecordAsync` 中的本地重算逻辑保持不变。
