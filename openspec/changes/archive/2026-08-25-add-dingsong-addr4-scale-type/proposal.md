## Why

现场 H610 / H1320 抓包为连续帧 `02 2A … 0D`（STX + `*` + 空格分隔数字 + CR），与现有顶松 `ScaleType.DingSong`（12 字节 `02 2B/2D … 03`）不兼容，导致重量无法解析。需要新增独立秤型「顶松Addr4」（`DingSongAddr4`）以按该帧格式解析，且不破坏现有顶松（`DingSong`）行为。

## What Changes

- 在 `ScaleType` 枚举新增 **`DingSongAddr4 = 4`**，显示名 **「顶松Addr4」**（`Description`）
- `TruckScaleWeightService`：当 `ScaleType == DingSongAddr4` 且通信方式为 HEX（如 `TF0`）时，按 H610/H1320 帧格式解析重量
- 设置页秤类型列表经 `GetDescription()` 自动出现「顶松Addr4」，无需单独硬编码列表（若有显式枚举列表则补上 `DingSongAddr4`）
- 单元测试：H610（**610 kg**）、H1320（**1320 kg**）在 `DingSongAddr4` 下可解析；在 `DingSong` 下仍拒绝（沿用现有 `DingSongScaleRejectTests`）
- **非 BREAKING**：旧配置仍使用 `0–3`；缺省不会自动切到 `DingSongAddr4`

## Capabilities

### New Capabilities

- `dingsong-addr4-scale`: 顶松Addr4（`DingSongAddr4`）秤型枚举、H610/H1320 帧解析与设置可选性

### Modified Capabilities

- （无）现有 `settings-ui` / `weighing-device-capture` 需求不因本变更修改措辞；秤类型扩展由新 capability 覆盖

## Impact

- **MaterialClient.Common**：`ScaleType`、`TruckScaleWeightService`（路由 + 新解析）、相关测试
- **MaterialClient.UI**：设置窗秤类型下拉（Description / 若有显式 `ScaleType` 列表）
- **Urban / Attended**：共用 `ITruckScaleWeightService`，选「顶松Addr4」后即可读该协议
- 无服务端 / OpenSpec 子仓库工件变更
