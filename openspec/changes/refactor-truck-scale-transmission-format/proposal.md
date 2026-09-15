## Why

生产路径上的 `TruckScaleWeightService` 把多种 `ScaleType` 解析堆在 `Services/Hardware` 单文件内，且字符串 `CommunicationMethod` 未成为协议选择一等公民，导致无法按「设备类型 × 传输格式」隔离扩展。需要先建立可分类的目录与接口骨架，再迁出现网 tf0 行为；耀华 tf1 留待后续 Phase。

## What Changes

- 新增枚举 `TransmissionFormatType`（`TransmissionFormatType0` / `TransmissionFormatType1`，Description `(tF0)` / `(tF1)`）。
- **BREAKING（配置）**：停用 `ScaleSettings.CommunicationMethod`；改用 `TransmissionFormatType`（默认 Type0）；旧 JSON 键忽略、不映射。
- 设置页「通讯方式」改为绑定 `TransmissionFormatType` 的选择项；本 Phase **不提供可用的耀华 tf1**（UI 不启用 Type1；绕过配置则协议层抛不支持/未实现）。
- 引入门面仍对外暴露 `ITruckScaleWeightService`；内部增加 `ITruckScaleProtocolRouter` + `IScaleTransmissionProtocol`。
- **目录分类**：地磅协议相关类型迁出扁平的 `Services/Hardware/`，放入按职责/设备分类的 `Services/TruckScale/`（及子目录）；相机/打印等其它硬件仍留在 `Hardware`。
- 本 Phase：迁出并接线各 `ScaleType` 的 **tf0** 真实（或 TestMode 模拟）协议；**不实现** `Yaohua` × `TransmissionFormatType1` 生产解析（显式未实现/不支持路径，禁止假重量）。
- Mode B：合入目标为 initiative 基线 **`dev-truck-scale-weight`**（MaterialClient + MaterialMonospec）；change 分支自该基线切出。

## Capabilities

### New Capabilities

- `truck-scale-transmission-format`: ScaleType × TransmissionFormatType 协议路由、目录分层、配置/UI 选择项、tf0 迁出与 Type1 明确未实现/不支持行为。

### Modified Capabilities

- （无）现有 openspec specs 无对等「生产地磅门面传输格式」需求块；本变更以新 capability 覆盖。

## Impact

- **仓**：MaterialClient（Common 服务/枚举/配置；UI Settings）；MaterialMonospec（OpenSpec + 调研文档已对齐）。
- **调用方**：`AttendedWeighingService` / `DeviceManagerService` 等继续依赖 `ITruckScaleWeightService` 门面，理想无感。
- **非本 Phase**：耀华 tf1 真实指令应答、候选新 ScaleType、UrbanManagement / 上云报文、毛重皮重净重生产记账。
- **Git**：Mode B — squash 合入 `dev-truck-scale-weight`，不直接 squash 进 trunk。
