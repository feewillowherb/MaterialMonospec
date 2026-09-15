## Context

上一 change `add-yaohua-tf1-continuous-query` 实现了听流；随后 `update-yaohua-tf1-periodic-query` 加了 10s 只写不收齐。现场日志确认：TX 成功，但依赖 DataReceived 碎片读导致无重量。Demo 能工作靠的是 **Discard → Write → 同步读到 ETX**。

约束：Mode B / `dev-truck-scale-weight`；`minimal-di`；禁止 tuple。

## Goals / Non-Goals

**Goals:**

- Yaohua Type1 对齐 Demo `Exchange`：周期（默认 10s）互斥执行 Discard→Write→读至 ETX（700ms）→解析→`PublishWeight`。
- `OnDataReceived` 对 Type1 **空实现**，避免与定时器抢串口。
- `OnStart` / `OnStop` 不在门面 `WriteLock` 内执行，避免首发锁冲突与关口死锁。
- 保留 Demo 组帧与应答解析（命令 `B`，地址来自 `CommunicationParameter`）。

**Non-Goals:**

- 200ms 高频 B/C/D 轮询（可后续加）。
- 非耀华 Type1；去皮/置零控制命令。
- UrbanManagement。

## Decisions

### D1 — I/O 模型 = Demo Exchange（非 DataReceived 听流）

**Decision：** 定时器 tick 内 `SemaphoreSlim` 互斥调用 `Exchange`（与 Demo 同构）；解析成功后发布重量。`OnDataReceived` 忽略。

### D2 — 周期与命令

**Decision：** 间隔 10s；命令 `B`；地址 `CommunicationParameter`（默认 A）。组帧 `STX+Adr+Cmd+XOR+ETX`。

### D3 — 门面锁与生命周期

**Decision：** Open 完成后释放 `WriteLock` 再 `OnStart`；关口前先在锁外 `OnStop` 再关串口。`ISerialPort.Write` 已提供。

## Risks / Trade-offs

- [Risk] 10s 实时感 → 用户要求；可后调。
- [Risk] Exchange 阻塞 Timer 线程最多 ~700ms → 可接受；跳过重叠 tick。
- [Risk] 关口时 Dispose Timer 等待 callback → 必须在 WriteLock 外 OnStop。

## Migration Plan

1. 重建 Urban，切 Type1，日志应见 `exchange TX` / `exchange RX` 或 `exchange timeout`。
2. Rollback：回退本协议文件与门面生命周期改动。

## Open Questions

- 周期是否配置化 — 本 change 仍写死 10s。
