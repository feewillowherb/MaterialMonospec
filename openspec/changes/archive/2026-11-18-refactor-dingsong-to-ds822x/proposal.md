## Why

现场 DS822-X 仪表按手册连续发送 `Adr=3`（`C` 显示帧）或可配置为 `Adr=1`（`A` 称量帧），与现有 `ScaleType.DingSong` 所认的 12 字节 `02 ± 8位数字 标记 03` 帧完全不同，导致选「顶松」时重量无法解析。需要把 DingSong 路径改为与 DS822-X 手册一致，以便现场仪表可直接对接。

## What Changes

- **BREAKING**：`ScaleType.DingSong`（顶松）HEX 连续接收改为仅解析 DS822-X 帧（`02`…`03`，带地址与命令字母、`CHK = xor|0x40`）；**不再**解析旧 12 字节 `02 2B/2D … 03` 帧。
- 连续发送同时支持 **`Adr=1`（`A`/`a` 称量帧）** 与 **`Adr=3`（`C`/`c` 显示帧）**，按帧内命令字母自动识别，无需新增秤型枚举。
- `A` 帧：从净重字段 + 小数位发布当前重量（`WeightUpdates` 仍为单个 `decimal`）。
- `C` 帧：从 6 组显示位重建当前显示重量后发布。
- `ScaleType.DingSongAddr4`（顶松Addr4）及 `Yaohua` / 其它秤型行为不变。
- 更新 / 替换依赖旧 12 字节契约的 DingSong 单测；补充 DS822-X 金标（含 `_tmp/text.txt` 的 `C` 帧与手册 `A` 帧样例）。
- 协议说明已落在 `docs/Device/顶松DS822-X_串口通讯协议.md`；本 change 不改该文档结构，实现以该文档为准。

## Capabilities

### New Capabilities

- `dingsong-ds822x-scale`: `ScaleType.DingSong` 按 DS822-X 连续帧（`Adr=1` / `Adr=3`）解析校验与发布重量；旧 12 字节顶松帧必须拒绝。

### Modified Capabilities

- （无）`dingsong-addr4-scale` 需求保持不变：Addr4 仍解析 `02 2A … 0D`；DingSong 路径仍不得按 Addr4 规则接受 H610/H1320。

## Impact

- **仓库**：仅 `MaterialClient`（`TruckScaleWeightService`、DingSong 相关测试）；编排仓 OpenSpec 工件。
- **设置 UI**：秤型仍显示「顶松」；选 DingSong + HEX（如 `TF0`）即走新协议。现场须将仪表 `modE` 设为连续发送、`Adr` 为 1 或 3。
- **BREAKING**：已依赖旧 12 字节「顶松」帧的现场配置将读不到重量，需改仪表通讯参数或改用其它秤型。
- **不改**：`DingSongAddr4`、耀华、PortableXPSY、业务过磅流程、DI 注册形态。
