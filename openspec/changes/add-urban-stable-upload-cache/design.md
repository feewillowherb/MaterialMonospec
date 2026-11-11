## Context

Urban 有人值守称重在 `WeightStabilized` 时建单，扩展行初始为 `SyncStatus.WeighingInProgress`。`WaitingForStability`、`WeightStabilized`、`WaitingForDeparture` 在 `weight < WeighingConfiguration.MinWeightThreshold` 时进入 `OffScale`。该边沿上的 `RewriteAndResetCycleAsync` 重写车牌、调用 `FinalizeWeighingCycleAsync`（`promoteWeighingInProgress: true`）把扩展升为 `Pending`，再清空选牌缓存并 `ResetCycle`。`weight == MinWeightThreshold` 不进入 `OffScale`。

`recordId` 已存在且 `weight > MinWeightThreshold` 时，状态被强制为 `WaitingForDeparture`，稳定边沿不会再次建单。选牌缓存 `PlateNumberService` 与本变更的已产生缓存不是同一份数据。建单读取推荐车牌发生在稳定后的 LPR 主动抓拍之前，晚到的识别不会改写这一笔已经快照的车牌。

`EnsureReadyForUploadAsync` 与 `FinalizeWeighingCycleAsync` 已共用同一套正式异常重算。扩展已是 `Pending` 时，该路径不会因为车牌变化再改一次同步状态；已 `Synced` / `Failed` 仅在异常标志变化时回到 `Pending`。

输入文档：`docs/2026-11-11-urban-stable-upload-cache/`。回放 `pipelines/graphs/materialclient/urban-stable-upload-cache-replay/runs/2026-11-11T141149` 用独立纯函数对齐了八个场景，没有引用 `repos/MaterialClient`。它不是产品验收。

## Goals / Non-Goals

**Goals:**

- 默认关闭的 `EnableUploadOnStable`。关闭时建单、下磅升 `Pending`、强制 `WaitingForDeparture` 与今天一致。
- 打开且当前是 Urban 称重路径时：第一次稳定建单后，用已保存的 `WeighingRecord.PlateNumber` 记下已产生车牌，并走现有 promote 路径升为 `Pending`。
- 现行 `OffScale` 边沿清除全部已产生条目。900 秒未下磅时释放本周期 `recordId`、清除条目、回到 `WaitingForStability`，之后只允许再生成一笔。
- 设置只在 Urban 宿主显示，并随现有称重 JSON 与设置保存刷新。

**Non-Goals:**

- 不把另一张车牌认成下一辆，也不实现 2026-11-10 的新稳态拆单。
- 不持久化已产生缓存，不处理进程重启后的续跑。
- 不把 `EnableMatchOnStable` 改成上传开关。Urban 继续跳过运单匹配。
- 不为已 `Pending` 或已 `Synced` 的行增加「只因下磅重写了车牌就再入队」。
- 不新增数据库外键，不把 2 分钟或 `StabilityWindowMs` 用作清除时间，不把 900 秒做成第二个配置项。

## Decisions

1. **开关名 `EnableUploadOnStable`，默认 `false`。** 放在 `WeighingConfiguration`，沿用现有 JSON。缺字段反序列化为 `false`。它只控制「稳定后升 Pending + 已产生缓存」。`EnableMatchOnStable` 仍只发布运单匹配。
   - 备选：复用 `EnableMatchOnStable`。否决，因为 Urban 跳过匹配，两个语义会绑死。

2. **只在 Urban 称重路径生效。** 判断使用现有的跳过运单匹配策略（Urban）。非 Urban 即使 JSON 为 `true` 也不建已产生缓存、不提前 promote、不做 900 秒回退。
   - 备选：任意宿主都执行缓存。否决，避免主流/再生路径被一份 Urban JSON 改变建单次数。

3. **已产生条目是命名 record，挂在现有有人值守称重单例的周期状态上。** 形状为 `ProducedPlateHold(string PlateNumber, DateTimeOffset CreatedAtUtc, long WeighingRecordId)`。车牌取建单完成后记录上的 `PlateNumber`（含空串），不在 LPR 抓拍之后再读一次推荐车牌。不新建 DI 服务，不把纯缓存注册为 Transient/Singleton，不用 tuple 作为该状态的类型。
   - 备选：新的 `IProducedPlateCacheService`。否决，它没有独立的 Repository 或外部 I/O，生命周期就是当前称重周期。

4. **提前上传调用 `EnsureReadyForUploadAsync`，不复制一套 promote。** 建单成功且开关生效时调用一次。下磅仍走 `RewriteAndResetCycleAsync` → `FinalizeWeighingCycleAsync`。已是 `Pending` 的行保持现行「车牌变化本身不改同步状态」。
   - 备选：在稳定边沿直接改 `SyncStatus` 字段。否决，变更必须留在现有扩展更新方法上。

5. **`OffScale` 始终清空全部 `ProducedPlateHold`。** 与选牌缓存的 `ClearCache()` 同一边沿，但是两份集合。不删除 `WeighingRecord`，不撤回已上传数据。等于 `MinWeightThreshold` 不清。
   - 备选：只删当前车牌那一条。否决，低于阈值时要清掉尚未下磅期间持有的全部已产生条目。

6. **900 秒是代码常量，时钟起点是该条 `CreatedAtUtc`。** 再次稳定不重置时钟。到期且仍未进入 `OffScale` 时：清空全部 hold，把最后建单 id 清掉，状态设为 `WaitingForStability`。不得调用 `RewriteAndResetCycleAsync`，否则会把这次回退做成下磅收口并清掉选牌缓存。清掉 `recordId` 之后，下一次「等待稳定且稳定且无记录」可以建恰好一笔，并写下新的 hold。不得在 `recordId` 仍被强制 Departure 时按 200ms 连续建单。
   - 备选：把 900 秒放进设置。否决，现场只确认了固定 15 分钟。
   - 备选：到期只清缓存、留下 `recordId`。否决，强制 Departure 会继续挡住新单，15 分钟重复就发生不了。

7. **同一车牌的拒绝发生在建单入口。** 开关生效且存在未过期 hold，且本次快照车牌与该 hold 的 `PlateNumber` 序数相同（空串也算相同），则不建第二笔。另一张车牌不算命中。`recordId` 仍在且重量高于阈值时，现行强制 Departure 继续挡住任何第二笔，包括另一张牌。
   - 备选：用缓存去拆叠车。否决，那是另一夹的范围。

8. **设置控件只在 Urban 宿主可见。** 称重参数区增加「稳定后上传」开关，可见性与现有 Urban 宿主判断一致。`SettingsSavedEventData` 刷新运行时配置时一并读取 `EnableUploadOnStable`。

## Risks / Trade-offs

- [稳定后立刻 promote，LPR 往往还没写回车牌] → 接受。第一笔上传使用建单快照车牌。下磅重写只更新本地记录；已 `Pending` / 已 `Synced` 不因车牌变化再入队。回放没有覆盖「已经进上传队列之后才改车牌」。
- [单次采样低于阈值会清缓存并允许新单] → 接受。这与现行 `OffScale` 是同一条件，不另加稳定或停留时间。
- [满 900 秒且重量仍稳定时，下一次稳定判定会再生成一笔] → 接受。新 `recordId` 立刻重新挡住后续采样，不会按检查间隔连建。
- [换牌叠车仍被强制 Departure 挡住，直到下磅或 900 秒] → 本变更不解决第二辆。文档保持在 2026-11-10 那夹。
- [回放 P2 通过不等于现场行为已验收] → apply 前仍要 Human `APPROVED`。本设计不把 `2026-11-11T141149` 写成产品通过，也不改写失败跑 `2026-11-11T141115`。

## Migration Plan

- 不增加表或外键。旧设置 JSON 没有该字段时视为 `false`，升级后上传时机不变。
- 回退：把开关关回 `false`。关后不再咨询 hold、不再提前 promote、不再做 900 秒释放。内存条目可随进程继续留着，但关闭路径不得读取它们来挡建单。
- 启用：只在要提前上传的 Urban 现场打开「稳定后上传」。

## Open Questions

- 无实现阻塞项。产品代码仍等待 Human `APPROVED`；本 change 的提案不代替该批准。
