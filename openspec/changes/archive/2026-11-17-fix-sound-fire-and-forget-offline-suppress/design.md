## Context

`AttendedWeighingService.ProcessStatusTransition` 对每次状态迁移 `EnqueueAsyncOperation` 调用 `ISoundDeviceService.PlayTextV2Async`。该调用与建单、抓拍、`RewriteAndResetCycle` 共用 `Subject<Func<Task>>` + `Merge(maxConcurrent: 5)`。

`PlayTextV2Async` 直连音柱 HTTP（`:8888`），`Timeout = 30s`，`maxRetries = 8`。设备离线时单条播报可占一个 Merge 槽数分钟；连续过车叠加「上磅 / 称重结束 / 下磅」导致排队，拖慢迟到的第二建单。

状态栏已有 `SharedDeviceStatusTracker` 每约 8s 调 `IsOnlineAsync()`，但播报路径不读该结果，仍盲目重试。

证据夹：`docs/2026-11-17-weighing-stable-weight-carryover/`。

## Goals / Non-Goals

**Goals:**

- 称重状态播报不占用称重 `EnqueueAsyncOperation` 槽位（fire-and-forget）。
- 最近已知离线时跳过生产播报（无 HTTP 重试）。
- 实际发起的播报最多重试 3 次；失败后抑制直至再次确认在线。
- 设置「测试音响」仍可主动试播并给出结果。

**Non-Goals:**

- 不修复双入队建单 / `CreateWeighingRecordAsync` 防重（另开 change）。
- 不把抓拍移出称重队列。
- 不引入新的外部依赖或改音柱协议。
- 不要求关停时排空旁路播报任务。

## Decisions

### Decision 1: 播报旁路 — 调度方 fire-and-forget，不经 Merge 队列

在 `ProcessStatusTransition`（及同类称重播报入口）中：

- **不再** `EnqueueAsyncOperation(() => PlayTextV2Async(...))`。
- 改为在确认有文案后 `_ = PlayAnnouncementFireAndForgetAsync(text)`（或等价：捕获异常的未等待 Task），日志记录未观察异常。

**备选**：独立 `Merge(1)` 音响队列 — 仍可能堆积旧文案。拒绝：用户要求发了就丢。  
**备选**：`ILocalEventBus` 发布播报事件 — 可做，但对本 change 过重；直接旁路 Task 即可满足解耦称重队列。若后续要跨模块订阅再升 EventBus。

### Decision 2: 离线抑制放在 `SoundDeviceService`（最近已知态）

在 `SoundDeviceService` 内维护 `bool? _lastKnownOnline`（或等价原子字段）：

| 事件 | 更新 |
|------|------|
| `IsOnlineAsync()` 返回 | 写入 `_lastKnownOnline` |
| `PlayTextV2Async` 最终失败（重试用尽） | 置 `false` |
| `PlayTextV2Async` 成功 | 置 `true`（可选，保持一致） |

`PlayTextV2Async` 开头：若 `_lastKnownOnline == false`，记录 Debug/Information「suppressed offline」并 **return**（不抛）。

`_lastKnownOnline == null`（尚未探测）：允许试播一次（避免启动窗口轮询前完全静音）。

不在每次播报前额外调用 `IsOnlineAsync()`（避免叠加 mgrserver 延迟）。

**备选**：Orchestrator 读 `SharedDeviceStatusTracker` — 引入 UI 层依赖，违反分层；拒绝。

### Decision 3: 生产重试上限 3；测试可绕过抑制

- `PlayTextV2Async`：`maxRetries = 3`（原 8）。
- `PlayTextV2TestAsync`：先将抑制解除或走「强制播放」路径（例如临时忽略 `_lastKnownOnline == false`，仍最多 3 次），保证设置页可验证接线；试播结果仍反映真实成败。

### Decision 4: 不改 `Merge(5)` 本身

本 change 只把音响移出；建单/抓拍/Reset 仍用现有队列。降并发或拆关键队列留给串重建单 change。

## Risks / Trade-offs

- [Risk] 旁路 Task 在进程退出时被截断 → 可接受（播报非关键）。  
- [Risk] 轮询间隔内设备刚掉线仍会最多 3 次超时 → 失败后熔断抑制；可接受。  
- [Risk] `_lastKnownOnline` 在多宿主/多实例未共享 → MaterialClient 单进程单例 Service，足够。  
- [Risk] 发了就丢导致文案重叠/乱序 → 现场离线为主；在线时音柱自身队列处理，产品可接受。  
- [Trade-off] 不经 EventBus，观测点仍在 SoundDeviceService 日志。

## Migration Plan

1. 仅 MaterialClient 代码变更；无 DB / 配置 schema 迁移。
2. 部署后观察：离线时不应再出现长间隔「attempt 1/8…8/8」占满称重时间线；应见 suppress 或最多 3 次失败后静默。
3. 回滚：恢复 Enqueue + maxRetries=8（不推荐长期）。

## Open Questions

- 无。强制试播 API 形状（独立参数 vs Test 专用路径）在实现时按现有 `PlayTextV2TestAsync` 最小改动选择。
