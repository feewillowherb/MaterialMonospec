## Context

现场确认 Demo Exchange 可用后，用户要求生产 Tf1 与 Demo 连续查询一致：**B→C→D，命令间隔 200ms**，并保存 C/D（皮/净）供分量过磅。

约束：Mode B / `dev-truck-scale-weight`；`minimal-di`；禁止 tuple。

## Goals / Non-Goals

**Goals:**

- Yaohua Type1：Demo `Exchange`（Discard→Write→读至 ETX）；轮询 **B→C→D**，命令间 **200ms**。
- 存储 B=毛重、C=皮重、D=净重（吨）；经 `PublishComponentWeights` 发布；`B` 同时更新实时 `WeightUpdates`。
- `OnDataReceived` 空实现；`OnStart`/`OnStop` 在门面 WriteLock 外。

**Non-Goals:**

- 握手 `A`、去皮 `T`、置零 `Z`。
- 非耀华 Type1；UrbanManagement。

## Decisions

### D1 — I/O = Demo Exchange + B/C/D poll

**Decision：** 后台 `Task` 循环发 B→C→D，每次 Exchange 后 `Delay(200ms)`（与 Demo `PollLoop` 同构）。

### D2 — 存储 C/D（及 B）

**Decision：** 协议实例字段保存 `_grossTon` / `_tareTon` / `_netTon`；每次成功应答更新对应字段并 `PublishComponentWeights(new(gross, tare, net))`。三者齐全时 `AllValid` 供过磅优先路径。

### D3 — 实时重量

**Decision：** 仅 `B` 应答驱动 `PublishWeight`（实时显示跟毛重）；C/D 只进分量存储。

## Risks / Trade-offs

- [Risk] 串口占用高于 10s 单查 → 与 Demo 一致，可接受。
- [Risk] 关口等待 poll task → `OnStop` Cancel + Wait(3s)，且须在 WriteLock 外。

## Migration Plan

1. 重建 Urban；日志应见交替 `Command=B/C/D` 的 TX/RX。
2. Rollback：回退本协议轮询逻辑。
