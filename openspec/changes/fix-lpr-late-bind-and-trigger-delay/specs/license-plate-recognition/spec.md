## ADDED Requirements

### Requirement: 本周期 LPR 候选择优

系统 SHALL 在单个称重周期内维护至多一个当前 LPR 图片候选。当新的带图片路径的 `LicensePlateRecognizedEventData` 到达时，系统 MUST 按以下优先级决定是否接受该路径：有车牌结果（非空且通过车牌校验的 `PlateNumber`）的优先级 MUST 高于无车牌；同优先级时 MUST 接受较新到达的候选。被拒绝的候选 MUST NOT 覆盖当前候选。

#### Scenario: 无车牌后被有车牌升级

- **GIVEN** 本周期当前 LPR 候选来自无车牌（或空车牌）事件且已保存路径
- **WHEN** 随后收到带有效车牌与新 LPR 路径的识别事件
- **THEN** 系统 MUST 将当前候选更新为该新路径
- **AND** MUST 将候选标记为有车牌

#### Scenario: 有车牌不被无车牌降级

- **GIVEN** 本周期当前 LPR 候选已有车牌
- **WHEN** 随后收到无有效车牌但带 LPR 路径的事件
- **THEN** 系统 MUST NOT 用该路径覆盖当前候选

### Requirement: LPR 附件绑定与建单时序解耦

系统 SHALL 支持在称重记录创建之前或之后完成本周期 LPR 附件关联，且 MUST 对所有称重模式（含 Standard、SolidWaste、Recycle、UrbanMode）生效。当创建称重记录时若已有接受的候选路径，MUST 挂接 `AttachType.Lpr`；当无 `CameraConfigs` 时 MUST 仍按既有规则同步挂接同路径的 `UnmatchedEntryPhoto`。当本周期已存在最近创建的称重记录标识且新候选被接受时，系统 MUST 将该路径 Upsert 到该记录的 LPR 附件，而 MUST NOT 要求重新创建称重记录。非 Urban 客户端 MAY 不在业务 UI 中展示或消费该附件。

#### Scenario: 先建单后图（任意模式）

- **GIVEN** 称重已稳定并已创建 `WeighingRecord`（任意 `WeighingMode`），本周期尚无 LPR 附件
- **WHEN** 本周期内晚到的 LPR 识别事件携带图片路径且候选被接受
- **THEN** 系统 MUST 为该记录创建或更新 `AttachType.Lpr` 附件指向该路径

#### Scenario: 先图后建单（任意模式）

- **GIVEN** 本周期已接受带路径的 LPR 候选
- **WHEN** 创建称重记录且存在该候选路径
- **THEN** 系统 MUST 在创建流程中将当前候选路径挂接为 LPR 附件
- **AND** MUST NOT 因非 `UrbanMode` 或存在 `CameraConfigs` 而跳过挂接

#### Scenario: 下磅后不再补绑

- **GIVEN** 系统已执行周期重置，上一笔记录的最近创建标识已清空
- **WHEN** 随后收到带 LPR 路径的识别事件
- **THEN** 系统 MUST NOT 将路径绑定到已重置的上一笔称重记录

### Requirement: 全模式 LPR 图片落盘

Hikvision/Vzvision 等 LPR 服务在回调中收到有效图片缓冲时，SHALL 将图片落盘到 LPR 目录并在事件中携带相对路径，MUST NOT 仅因 `WeighingMode` 非 `UrbanMode` 或已配置 `CameraConfigs` 而跳过落盘。

#### Scenario: Standard 有相机仍落盘

- **WHEN** `WeighingMode` 为 `Standard` 且 `CameraConfigs` 非空
- **AND** LPR 回调携带图片数据
- **THEN** SHALL 写入 `Lpr/` 目录下的 jpg 文件
- **AND** SHALL 在 `LicensePlateRecognizedEventData.LprImagePath` 中提供路径

#### Scenario: Recycle 有相机仍落盘并挂接

- **WHEN** `WeighingMode` 为 `Recycle` 且 `CameraConfigs` 非空
- **AND** 本周期有已接受的 LPR 候选路径并创建称重记录
- **THEN** SHALL 挂接 `AttachType.Lpr`
- **AND** Recycle UI MAY 不展示该附件

### Requirement: 晚到补绑后刷新 Urban 异常

当对已有 Urban 称重记录补绑或升级 LPR 附件成功后，若该记录存在 `UrbanWeighingExtension`，系统 SHALL 使用与记录编辑后相同的异常检测路径重算并持久化 `IsAnomaly` 与 `AnomalyReason`。无 Urban 扩展的记录 MUST NOT 因此路径创建 Urban 扩展。

#### Scenario: 缺图异常因补绑清除

- **GIVEN** 记录创建时因无 LPR 附件被标为异常，且其它条件未触发异常
- **WHEN** 本周期晚到 LPR 补绑成功
- **THEN** 系统 MUST 重算异常标志
- **AND** 若检测结果为非异常，MUST 将 `IsAnomaly` 更新为 `false` 并清除相应原因

## MODIFIED Requirements

### Requirement: CreateWeighingRecord 调用 LPR 保存

`WeighingRecordService.CreateWeighingRecordAsync` SHALL 在存在本周期已接受的 LPR 候选路径时调用 LPR 附件保存逻辑，MUST NOT 将保存条件限制为 `WeighingMode.UrbanMode` 或 `CameraConfigs` 为空。创建完成后若本周期仍收到更优候选，SHALL 由补绑路径 Upsert，而 MUST NOT 仅依赖创建瞬间的一次性快照作为唯一绑定机会。无 `CameraConfigs` 时的 `UnmatchedEntryPhoto` 双挂接行为保持既有规则。

#### Scenario: Recycle 有相机创建记录仍挂接 LPR

- **WHEN** 在 Recycle 模式创建称重记录
- **AND** `CameraConfigs` 非空
- **AND** 存在已接受的本周期 LPR 候选路径
- **THEN** SHALL 挂接 LPR 附件

#### Scenario: Recycle 无相机创建记录

- **WHEN** 在 Recycle 模式创建称重记录
- **AND** `CameraConfigs` 为空
- **AND** 存在已接受的本周期 LPR 候选路径
- **THEN** SHALL 挂接 LPR 附件
- **AND** SHALL 按既有规则同步挂接 `UnmatchedEntryPhoto`

#### Scenario: 创建时无路径不阻止晚到补绑

- **WHEN** 创建称重记录时本周期尚无 LPR 候选路径
- **AND** 创建后、周期重置前收到可接受的 LPR 路径事件
- **THEN** SHALL 仍能通过补绑挂接 LPR 附件
