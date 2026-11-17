## Why

现场音响离线时，称重状态迁移仍把 `PlayTextV2Async` 送进与建单/抓拍共用的 `EnqueueAsyncOperation`（`Merge(5)`），单次播报最长约 8×30s 占槽，连续过车会堆积并拖慢判稳建单，放大「闭包旧重量」迟到落库。需要把播报改成旁路、离线直接抑制。

证据：`docs/2026-11-17-weighing-stable-weight-carryover/`（本日志约 53 次 `Audio playback ultimately failed` vs ~14 次判稳建单）。

## What Changes

- 称重状态播报改为 **发了就丢**：不再经 `EnqueueAsyncOperation` / `Merge(5)`；调度方不等待、不占称重关键槽位。
- **离线抑制**：`PlayTextV2Async`（称重路径）在设备最近已知为离线时立即跳过，不发起 HTTP 重试。
- 播报 HTTP **最多重试 3 次**（由现行 8 次下调）；失败后将最近已知状态记为离线以抑制后续播报，直至状态轮询恢复在线。
- 设置页「测试音响」仍允许试播并报告结果（可绕过离线抑制或强制探测），不改变测试入口语义。

## Capabilities

### New Capabilities

- `sound-device-playback`: 生产路径播报策略——离线抑制、有限重试、最近在线态缓存与失败熔断。

### Modified Capabilities

- `attended-weighing`: 状态迁移播报改为 fire-and-forget，MUST NOT 经称重异步操作队列入队。
- `sound-device-test`: 对齐 `PlayTextV2Async` 最多 3 次重试；测试按钮可在离线抑制下仍执行试播。

## Impact

- 子仓库：`MaterialClient`（`AttendedWeighingService`、`SoundDeviceService`；相关单测）。
- 称重关键路径（建单 / Reset / 抓拍）不再被播报超时拖尾；离线现场日志噪声下降。
- 不解决双入队建单根因（另见 `docs/2026-11-17-weighing-stable-weight-carryover/04-修复方向与开放问题.md`）；本 change 仅降低音响放大面。
