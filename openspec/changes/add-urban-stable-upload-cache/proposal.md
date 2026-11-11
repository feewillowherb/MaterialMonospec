## Why

繁忙过磅时，同一车牌会在仍压在地磅上时再次触发稳定。现行 Urban 只在进入 `OffScale` 后把 `WeighingInProgress` 升为 `Pending`，稳定当时已经生成的称重记录若被再次建单，就会再产生一条称重或再上传一次。需要一条默认关闭的 Urban 配置：第一次稳定即可上传，并用内存缓存挡住这张已经产生过的车牌，直到现行下磅条件成立，或自称重记录生成起满 15 分钟。

## What Changes

- 在 `WeighingConfiguration` 增加 Urban 专用布尔开关，默认 `false`。关闭时保持现行行为：稳定时建单仍为 `WeighingInProgress`，进入 `OffScale` 后才升 `Pending`；不启用已产生缓存，也不做 15 分钟回退。
- 开关打开后，第一次 `WeightStabilized` 仍按现行顺序建单，并把**建单当时**快照到的车牌写入进程内已产生缓存；随后按现行异常重算把该扩展从 `WeighingInProgress` 升为 `Pending`。不复用 `EnableMatchOnStable`。Urban 仍跳过运单匹配。
- `recordId` 仍被持有且 `weight > MinWeightThreshold` 时，现行状态机继续禁止第二次稳定建单。已产生缓存只在再次走到建单时挡住**同一张建单快照车牌**。另一张车牌不由该缓存挡住。
- 清除沿用现行进入 `OffScale` 的条件：`WaitingForStability` / `WeightStabilized` / `WaitingForDeparture` 且 `weight < WeighingConfiguration.MinWeightThreshold`（可配置，默认 0.5 吨）。等于阈值不进入 `OffScale`。不另写离开概念，不要求离开前再稳定，也不使用 `StabilityWindowMs` 当离开计时。该边沿清除全部尚未下磅的已产生缓存条目。已写入的称重记录和已上传数据不删除。
- 自称重记录生成起满 900 秒仍未进入 `OffScale`：清除已产生缓存并释放本周期 `recordId`，状态回到 `WaitingForStability`（不是 `OffScale`），允许下一次稳定再生成一笔。时钟不因后来的稳定边沿重计。之后的重复称重或重复上传接受。2 分钟不是清除时间。回退只打开一次新单，不得按采样间隔连续建单。
- 已产生缓存只在内存，不落盘。软件重启不在本变更范围。
- 设置项仅 Urban 宿主可见，随现有称重配置 JSON 保存。保存设置后运行时配置与现有三个称重开关一并刷新。

不在本变更内：

- 叠车第二辆、换牌后用新稳态拆成下一笔（留在 `docs/2026-11-10-urban-busy-weighing-upload-on-stable/`，该夹仍挂起）
- 道闸时序、缓存落盘、重启后续跑
- 已是 `Pending` 的记录仅因下磅重写车牌而重新入上传队列。回放未覆盖该时序；现行 `Finalize` 不会只因车牌变化把已 `Pending` 的行再入队，本变更保持该行为

## Capabilities

### New Capabilities

- `urban-stable-upload-cache`: Urban 稳定后上传开关、建单车牌的已产生缓存、现行 `OffScale` 清空，以及 900 秒兜底后允许一笔重复

### Modified Capabilities

- `urban-weighing-extension`: 开关打开时，第一次稳定后即可把 `WeighingInProgress` 升为 `Pending`；开关关闭时仍只在下磅（或既有手工编辑）升 `Pending`
- `attended-weighing`: 开关打开且满 900 秒仍未下磅时，释放 `recordId` 并回到 `WaitingForStability`，作为「有记录且重量仍高于阈值则强制 `WaitingForDeparture`」的例外；设置保存时刷新该新开关

## Impact

- **子仓库**：仅 `repos/MaterialClient`（`WeighingConfiguration`、有人值守称重状态与建单、Urban 称重副作用、Urban 宿主设置页）。不改 UrbanManagement，不加数据库外键，不把缓存写入表。
- **分支**：Mode A — `add-urban-stable-upload-cache`
- **输入**：[`docs/2026-11-11-urban-stable-upload-cache/`](../../../docs/2026-11-11-urban-stable-upload-cache/00-调研总览.md)。回放 Run identity：`pipelines/graphs/materialclient/urban-stable-upload-cache-replay/runs/2026-11-11T141149`（`result=pass`，P2 与 fixture 一致，P3 未判定）。该 Run 不注入 `repos/MaterialClient`，不是产品验收。`runs/2026-11-11T141115` 为失败跑，不得覆盖或当作当前证据。
- **人闸**：本提案只建立变更工件。文档与 Pipeline 结论进入产品代码前仍要 Human `APPROVED`。本文件不宣称该批准已经给出。
