## Why

现场仪表在经典 `tF=1` 下作为从机**不会主动推流**；当前生产 `YaohuaTf1Protocol` 按「只听不写」实现后串口无入站数据，界面无重量。需要按地址周期性下发查询帧以触发仪表应答。

## What Changes

- **BREAKING（相对听流约定）**：生产耀华 Type1 改为 Demo 对齐的 **B→C→D** 周期 Exchange（命令间隔 **200ms**）。
- 每次 Exchange：`Discard → Write → 同步读至 ETX（~700ms）→ 解析`。
- **存储** B=毛重、C=皮重、D=净重，并经分量流发布；`B` 同时更新实时重量。
- Type1 **不**依赖 `OnDataReceived`；门面 `OnStart`/`OnStop` 在 `WriteLock` 外。
- `ISerialPort.Write` 已补齐。

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
