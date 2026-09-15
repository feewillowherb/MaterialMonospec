## Why

现场仪表在经典 `tF=1` 下作为从机**不会主动推流**；当前生产 `YaohuaTf1Protocol` 按「只听不写」实现后串口无入站数据，界面无重量。需要按地址周期性下发查询帧以触发仪表应答。

## What Changes

- **BREAKING（相对上一约定）**：撤销「生产耀华 Type1 禁止为取重写查询命令」；改为 Demo 对齐的周期 **Exchange**。
- `YaohuaTf1Protocol`：每 10 秒（启动立即一次）执行 Demo 同构流程：`Discard → Write(B) → 同步读至 ETX（~700ms）→ 解析 → PublishWeight`；地址取自 `CommunicationParameter`（默认 `A`）。
- Type1 **不**依赖 `OnDataReceived` 碎片读取应答（该路径空实现，避免与定时器抢串口）。
- `ISerialPort` / `SerialPortWrapper` 补齐 `Write`。
- 门面：`OnStart` / `OnStop` 在 `WriteLock` 外执行，避免首发锁冲突与关口死锁。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `truck-scale-transmission-format`: Yaohua Type1 改为 Demo 对齐的周期 Exchange（Discard→Write→同步收齐→解析），`CommunicationParameter` 用于组帧寻址。

## Impact

- **Repos**：MaterialClient（`MaterialClient.Common` 协议 / 硬件抽象 / 门面；单测）。
- **Initiative**：Mode B，基线 `dev-truck-scale-weight`。
- **非影响**：UrbanManagement、FdSoft.BasePlatform；非耀华 Type1 仍 Unsupported。
- **文档**：与 `docs/2026-09-15-.../06` 旧拍板冲突处以本 change 为准（另可补注）。
