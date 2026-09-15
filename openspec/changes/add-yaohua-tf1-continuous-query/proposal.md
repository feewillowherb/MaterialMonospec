## Why

Phase 1（`refactor-truck-scale-transmission-format`）已建立 `ScaleType × TransmissionFormatType` 路由与 Type0 迁出，但 **`Yaohua × TransmissionFormatType1` 仍走 Unsupported**，设置页也不开放 `(tF1)`。现场与调研已拍板生产 Type1 形态：**连续查询听流（不向设备发查询命令）**，并约定重量 **优先皮/毛/净（三者全有效），任一无效则降级旧稳定模式**。需要落地该能力，否则枚举与 UI 无法表达真实生产路径。

## What Changes

- 实现生产路径 **`YaohuaTf1Protocol`（连续查询听流）**：经 `OnDataReceived` / 等价连续读解析到达帧；**禁止** Demo 式写串口查询命令轮询。
- Router：仅 `ScaleType.Yaohua × TransmissionFormatType1` 解析到真实协议；**其它 ScaleType × Type1** 仍 Unsupported（抛错，禁止假重量）。
- Settings UI：当 `ScaleType == Yaohua` 时 **启用** `(tF1)`；非耀华仍不可选。
- 新增通用不透明配置槽 **`ScaleSettings.CommunicationParameter`**（`string?`）：**每次切换 TransmissionFormatType 时重置**为当前 ScaleType × 新 TF 默认；耀华默认地址语义 **`A`**；解析归属协议实现方（非门面统一 Parse）。
- 重量取值：**持续推送实时重量流**（保证旧稳定模式可用）；过磅优先采用连续查询解析的 **皮/毛/净**——**三者全部有效**才用；**任一无效即降级**现网稳定窗口路径（同一实时流，非第二条串口会话）。
- Mode B：合入目标为 initiative 基线 **`dev-truck-scale-weight`**（MaterialClient + MaterialMonospec）；change 分支自该基线切出。

## Capabilities

### New Capabilities

- （无）本轮在既有 capability 上扩展，不另开平行 capability 名。

### Modified Capabilities

- `truck-scale-transmission-format`: 解锁 `Yaohua × Type1` 连续查询真实协议与 UI；补充 `CommunicationParameter`；明确 Type1 重量优先皮毛净 / 任一无效降级稳定模式；非耀华 Type1 仍 Unsupported。

## Impact

- **仓**：MaterialClient（`Services/TruckScale` 协议/路由/门面、`ScaleSettings`、Settings UI、相关单测；称重业务消费皮毛净或稳定降级处）；MaterialMonospec（本 OpenSpec）。
- **调用方**：`ITruckScaleWeightService` 门面保持；实时 `WeightUpdates` 在 Type1 下仍可用。若增加皮毛净只读表面，须命名 `record`（禁止 tuple），尽量让 `AttendedWeighing` / 稳定窗口无感降级。
- **非本 change**：Demo 指令应答写端口模型进生产；非耀华 Type1 真协议；UrbanManagement / 上云报文；候选新 ScaleType。
- **Git**：Mode B — squash 合入 `dev-truck-scale-weight`，不直接 squash 进 trunk。
- **依据**：`docs/2026-09-15-truck-scale-transmission-format-refactor/`（尤其 [06 §10 / §10.3.1](../../../docs/2026-09-15-truck-scale-transmission-format-refactor/06-耀华tf1与连续模式是否足够.md)）。
