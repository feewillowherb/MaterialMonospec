# manual-data-sync-trigger

## MODIFIED Requirements

### Requirement: 手动触发完整同步流程

系统 SHALL 在用户点击"数据同步"按钮后，依次执行以下同步操作：

1. 物料数据同步（`SyncMaterialAsync`）
2. 物料类型数据同步（`SyncMaterialTypeAsync`）
3. 供应商数据同步（`SyncProviderAsync`）
4. 运单数据推送（`PushWaybillAsync`）
5. 运单附件上传（`SyncPendingAttachmentsAsync`，经 `FdSoft.Material.PublicApi` 上传待同步附件，手动触发不受夜间低峰窗口限制）

#### Scenario: 成功执行完整同步流程
- **WHEN** 用户点击"数据同步"按钮
- **THEN** 系统 SHALL 依次执行物料同步、物料类型同步、供应商同步、运单推送、经 `PublicApi` 的附件上传 5 个步骤

#### Scenario: 单个步骤失败不中断后续步骤
- **WHEN** 同步流程中某个步骤执行失败
- **THEN** 系统 SHALL 捕获该步骤的异常，继续执行后续同步步骤

#### Scenario: 不执行许可证验证
- **WHEN** 用户手动触发数据同步
- **THEN** 系统 SHALL NOT 执行许可证验证步骤（`VerifyAuthAsync`），仅执行数据同步相关步骤
