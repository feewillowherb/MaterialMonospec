# viewmodel-messagebus-communication

## ADDED Requirements

### Requirement: Common/Urban 业务事件到达 UI 不得因缺少桥接而静默失败

凡 ViewModel 通过 `MessageBus.Current.Listen<*Message>()` 消费、且对应发布端为 `ILocalEventBus.PublishAsync(*EventData)` 的业务通知，运行时 MUST 存在匹配的 `*EventToMessageBusBridge`。缺少桥接导致 UI 不刷新时，不得以「订阅代码已写 Listen」视为功能完成。

#### Scenario: 称重状态变更 UI 必须更新

- **WHEN** `WeighingStateManager`（或等价）发布 `StatusChangedEventData`
- **THEN** 经桥接后 `AttendedWeighingViewModel` / `UrbanAttendedWeighingViewModel` 的 `Listen<StatusChangedMessage>` MUST 收到消息
- **AND** UI 状态展示 MUST 随之更新

#### Scenario: 新建称重记录后列表必须刷新

- **WHEN** `WeighingRecordService` 发布 `WeighingRecordCreatedEventData`
- **THEN** 经桥接后 ViewModel `Listen<WeighingRecordCreatedMessage>` MUST 触发列表刷新（如 `RefreshAsync` / `ReloadRecordsAsync`）

#### Scenario: Urban UploadCompleted / ServerApprovalSynced 必须刷新列表

- **WHEN** 发布 `UploadCompletedEventData` 或 `ServerApprovalSyncedEventData`
- **THEN** 经对应桥接后 `UrbanAttendedWeighingViewModel` MUST 收到 `UploadCompletedMessage` / `ServerApprovalSyncedMessage` 并执行重载
