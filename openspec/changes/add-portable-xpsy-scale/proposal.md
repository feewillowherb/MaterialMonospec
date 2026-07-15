## Why

现场便携式 XP-SY 仪表已在旧客户端（GovClient `DiBangScaleReceiver`）落地，但 MaterialClient 仅支持耀华 HEX、顶松 HEX 与测试模式，无法选用该协议读重。需在 MaterialClient 地磅链路中补齐 PortableXPSY，以便现场用同一套新客户端接 XP-SY 设备。

## What Changes

- 在 `ScaleType` 中新增便携式 XP-SY（PortableXPSY）枚举项，设置页地磅类型下拉可选
- `TruckScaleWeightService` 对该类型强制走 ASCII 帧路径：`=` 定界、8 字节载荷校验、低位先发反转后解析重量，不复用现有 `IsValidWeightFormat`（`±########X`）校验
- 初始化时按 `ScaleType` 选择协议，避免默认 `CommunicationMethod=TF0` 误入 HEX
- 补充单元测试覆盖手册样例帧与连续帧
- 不影响 TestMode HTTP 注重、耀华/顶松现有路径及称重业务对 `WeightUpdates` 的订阅

## Capabilities

### New Capabilities

- `portable-xpsy-scale`: MaterialClient 地磅类型 PortableXPSY 的配置暴露、串口帧同步与重量解析，以及经既有 `ITruckScaleWeightService.WeightUpdates` 对外输出

### Modified Capabilities

- （无）settings-ui / attended-weighing 等现有能力仅消费地磅类型与重量流，需求级行为不变；新增协议行为由 `portable-xpsy-scale` 覆盖

## Impact

- **子仓库**：`repos/MaterialClient`（Common + UI）
- **主要代码**：`ScaleType`、`SettingsWindowViewModel.ScaleTypeOptions`、`TruckScaleWeightService`、`TruckScaleWeightServiceTests`
- **配置**：用户在设置中选择「便携式XP-SY」；串口/波特率/地磅单位沿用现有字段
- **依赖**：无新 NuGet；协议对齐旧端 `DiBangScaleReceiver` 便携式 XPSY 实现
- **非范围**：UrbanManagement 服务端、DB 迁移、称重稳定判定与录单流水线改动
