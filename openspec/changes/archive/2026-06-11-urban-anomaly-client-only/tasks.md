## 1. 移除 UrbanManagement 服务端异常检测基础设施

- [x] 1.1 删除 `IUrbanAnomalyDetector`、`UrbanAnomalyDetector` 及 UrbanManagement 侧相关单元测试
- [x] 1.2 删除 `UrbanAnomalyDetectionOptions`、模块 DI 注册与 `appsettings` 中 `UrbanAnomalyDetection` 配置节
- [x] 1.3 全局检索 UrbanManagement 中对服务端异常检测器的引用并清理（含 Receive、审批以外的写路径）

## 2. 接收上传：信任客户端 IsAnomaly

- [x] 2.1 确认 `ReceiveAsync`（或等价创建路径）将 DTO `IsAnomaly` 原样写入 `UrbanWeighingRecord`，移除任何服务端重算调用
- [x] 2.2 补充/调整接收路径测试：客户端上报 `true`/`false` 均按原值持久化

## 3. Web/API 审批：格式校验通过即清除异常并待同步

- [x] 3.1 修改 `ApproveAsync`：仅 `IsAnomaly == true` 可审批；车牌 `PlateNumberValidator` + 有效正重量通过后设置 `IsAnomaly = false`；已正常记录返回业务错误
- [x] 3.2 移除审批保存路径对 `IUrbanAnomalyDetector` 的调用
- [x] 3.3 保持审批成功后 `SyncType`/`RetryCount` 重置逻辑，确保 `GovSyncBackgroundWorker` 可拾取
- [x] 3.4 补充审批 API 测试：异常记录有效值 → `IsAnomaly=false`；正常记录 → 400 拒绝；无效车牌 → 不更新

## 4. 审批页 UI：仅异常可审 + 保存前确认

- [x] 4.1 审批列表仅对 `IsAnomaly == true` 行渲染可用「审批」按钮；审批成功后刷新列表不再显示审批入口
- [x] 4.2 审批弹窗在车牌/重量校验通过后、调用 API 前增加 LayUI 二次确认；取消则不提交
- [x] 4.3 手测：异常行审批 → 确认 → 变正常且不可再审；取消确认 → 数据不变

## 5. 回归与验收

- [x] 5.1 验证政府同步 Worker 仍跳过 `IsAnomaly == true` 且审批清除后可被拾取
- [x] 5.2 验证 MaterialClient 本地创建/审批/上传行为未改动（冒烟：异常记录上传后服务端保持客户端标志）
- [x] 5.3 更新部署说明：移除 UrbanManagement `UrbanAnomalyDetection` 运维配置项
