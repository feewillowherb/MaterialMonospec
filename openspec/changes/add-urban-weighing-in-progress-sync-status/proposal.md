## Why

Urban 称重在 **WeightStabilized**（车往往仍在磅上）即创建扩展并置为 `SyncStatus.Pending`，且异常判定延迟为占位 `IsAnomaly=false`。轮询可能在下磅与正式异常回写之前把「正常」上传到 UrbanManagement；之后客户端判为空车牌等异常却不再重传，导致 **客户端异常、UM 正常**。

## What Changes

- 在 MaterialClient 的 `SyncStatus` 枚举中新增 **`WeighingInProgress`（称重中）**。
- Urban 称重扩展在稳定建单时初始化为 **`WeighingInProgress`**（不再直接 `Pending`），配合既有延迟异常占位。
- **仅 `Pending` 参与上云轮询**；`WeighingInProgress` 不得上传。
- 称重周期就绪后（下磅 / 正式异常评估完成等，见 design）将状态提升为 **`Pending`**，再由既有轮询上传。
- 既有库中已是 `Pending` 的未同步行保持可上传语义，**不做批量改写**。
- 列表/描述文案对 `WeighingInProgress` 给出可读说明（如「称重中」）。
- **兜底（UM）**：`ReceiveAsync`（含幂等重复接收）时，若 `PlateNumber` 为空/空白，**无论客户端上报的 `IsAnomaly` 是否为 false**，服务端 MUST 将记录标为异常并写入空车牌原因；**不**重跑重量上下限阈值规则。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-weighing-extension`: 建扩展默认同步态改为 `WeighingInProgress`；定义提升为 `Pending` 的条件；worker 查询仍只取 `Pending`。
- `urban-polling-background-service`: 明确不得上传 `WeighingInProgress`（仅 `Pending`）。
- `urban-anomaly-detection`: 延迟占位期间不得上云；正式评估后与同步态提升协同；明确 UM 空车牌兜底为 client-only 阈值规则的例外。
- `urban-weighing-api`: Receive 持久化时增加空车牌服务端兜底，强制 `IsAnomaly`。

## Impact

- **Repos**：MaterialClient（`SyncStatus`、扩展生命周期、侧效应、轮询/列表）；UrbanManagement（`ReceiveAsync` / `FromReceive` / `ApplyDuplicateReceive` 空车牌兜底）；两仓单测。
- **弱影响**：UM 不新增「称重中」业务态；Passage 不使用本枚举值。
- **模式**：Mode A（自 `main` 切 change 同名分支；合入 squash 回 `main`）。涉及 MaterialMonospec + MaterialClient + UrbanManagement。
- **兼容**：SQLite 存 int；旧 `Pending=0` 行不变。新增枚举值使用未占用数值。

### Known limitation（本 change 不修）

- **称重中关软件 / 进程退出**：`WeighingInProgress` 扩展已写入本地 SQLite，**本地数据不会丢失**；但轮询仍只上传 `Pending`，重启后**不会自动**把残留的「称重中」提升为 `Pending`。
- **后果**：该车次可一直停在本地「称重中」、不上云，直到再次触发提升路径（下磅 `FinalizeWeighingCycleAsync`、上传前 `EnsureReadyForUploadAsync`、或人工编辑置 `Pending`）。
- **范围**：本 change **不**做启动扫描 / 超龄自动提升等补救；若需闭环，另开 change（见 design Risks / Open Questions）。
