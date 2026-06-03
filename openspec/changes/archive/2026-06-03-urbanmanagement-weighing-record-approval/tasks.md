## 1. Core — 配置与校验

- [x] 1.1 在 `UrbanManagement` 增加 `UrbanAnomalyDetection` 配置类并绑定 `appsettings.json`（默认与 MaterialClient 一致）
- [x] 1.2 实现 `IUrbanAnomalyDetector` / `UrbanAnomalyDetector`（规则对齐 `MaterialClient.Common`）
- [x] 1.3 实现 `PlateNumberValidator`（或 `IPlateNumberValidator`），对齐客户端中国车牌校验

## 2. Core — DTO 与 AppService

- [x] 2.1 新增 `UrbanWeighingRecordApproveInputDto`（`Id`, `PlateNumber`, `TotalWeight`）
- [x] 2.2 在 `IUrbanWeighingRecordAppService` 增加 `ApproveAsync`
- [x] 2.3 实现 `ApproveAsync`：更新字段、重算 `IsAnomaly`、`SyncType=0`、`RetryCount=0`、UOW、不调用政府 HTTP
- [x] 2.4 确认 ABP 约定路由为 `POST /api/app/urban-weighing-record/approve`（Swagger 验证）
- [x] 2.5 在审批相关代码处添加 `TODO(approval-attachments)` 注释（预留 LPR/现场图只读预览，本期不实现）

## 3. Web UI — 列表与审批弹层

- [x] 3.1 `UrbanWeighingRecord/Index.cshtml` 表格增加「审批」操作列
- [x] 3.2 实现 LayUI `layer.open` 审批弹层：仅车牌、重量表单；只读展示 `Id`/`ClientRecordId`（可选）；不含图片区域
- [x] 3.3 打开弹层时从当前行填充车牌/重量（不请求附件接口）
- [x] 3.4 提交审批：调用 approve API；成功则关闭弹层并 `table.reload`
- [x] 3.5 前端校验：空车牌、非数字重量；展示 API 400 错误消息

## 4. 验证

- [x] 4.1 审批合法车牌/重量 → 列表「数据质量」「同步状态」更新正确
- [x] 4.2 审批非法车牌 → 400，数据不变
- [x] 4.3 审批后 `IsAnomaly=true` 的记录不被 `GovSyncBackgroundWorker` 上送；`IsAnomaly=false` 且项目启用时进入待同步队列
- [x] 4.4 与 MaterialClient.Urban 同一条 `ClientRecordId` 记录：客户端与 Web 审批语义对照（文档或手工用例）
