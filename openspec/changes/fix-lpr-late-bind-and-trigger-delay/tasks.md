## 1. 配置与设置 UI

- [x] 1.1 在 `SystemSettings` 增加 `TriggerLprCaptureDelayMs`（int，默认 0）及注释
- [x] 1.2 `SettingsWindowViewModel`：Reactive 属性、加载、保存时 `Math.Max(0, …)`
- [x] 1.3 `SettingsWindow.axaml`：在「启用 LPR 主动抓拍」下新增延迟行，RowDefinitions 与后续行顺延

## 2. 抓拍延迟生效

- [x] 2.1 `WeighingCaptureService.TriggerLprCaptureForAllAsync`：开关通过后，若 `TriggerLprCaptureDelayMs > 0` 则 Delay 再抓拍并打日志

## 3. 周期候选与择优

- [x] 3.1 新增 `CycleLprCandidate` record（RelativePath / HasPlate / ReceivedAt）
- [x] 3.2 `WeighingStateManager`：候选存取、`TryAcceptLprCandidate`（有车牌优先、同级较新覆盖）、`ResetCycle` 清空候选
- [x] 3.3 `AttendedWeighingService` LPR 订阅：按事件组装候选并 TryAccept；接受且存在 `LastCreatedWeighingRecordId` 时调用 Upsert

## 4. 全模式落盘与建单/补绑

- [x] 4.1 放宽 `HikvisionLprService` / `VzvisionLprService` 落盘门禁：有图即保存，不限 UrbanMode / CameraConfigs
- [x] 4.2 `IWeighingRecordService` / 实现：`UpsertLprAttachmentAsync`（无则插、有则换；无相机仍双挂 `UnmatchedEntryPhoto`；仅有 Urban 扩展时重算异常）
- [x] 4.3 `CreateWeighingRecordAsync`：有候选即挂接 `AttachType.Lpr`（去掉 `UrbanMode || CameraConfigs.Count == 0` 门禁）；`hasLrp` / Urban 扩展创建仍仅 UrbanMode
- [x] 4.4（推荐）`OnWeightStabilizedAsync`：先建单再 `CaptureOnWeightStabilized`（仍依赖补绑兜底异步图）

## 5. 测试与验证

- [x] 5.1 先建单后 LPR 事件（有路径）→ 记录存在 Lpr 附件（含非 Urban 模式）
- [x] 5.2 先无车牌图后有车牌图 → 附件升级；有车牌后无车牌不降级
- [x] 5.3 `ResetCycle` 后晚到事件不绑上一笔
- [x] 5.4 延迟配置：>0 时触发前等待；0 时行为与现网一致
- [x] 5.5 补绑后 Urban `IsAnomaly` 因缺图变为有图时被刷新（如适用）
- [x] 5.6 Standard/Recycle 在有 `CameraConfigs` 时仍落盘并挂接 Lpr；UI 可不展示
- [x] 5.7 建单推迟 Urban 异常判定；LPR Upsert 同步车牌后重算；周期重置最终重算；Urban 列表订阅 `UpdatePlateNumberMessage` 刷新
