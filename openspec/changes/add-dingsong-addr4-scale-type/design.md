## Context

- 现有 `ScaleType.DingSong`（顶松，值 1）解析 12 字节帧：`02 [2B|2D] [8 ASCII digits] [marker] 03`。
- 现场 `_temp/H610.txt` / `_temp/H1320.txt` 为重复 17 字节帧：`02 2A 30 20 [12 ASCII digits] 0D`（`*` + 空格 + CR）。
- `DingSongScaleRejectTests` 已证明顶松路径对上述帧返回 `null`。
- 解析入口在 `TruckScaleWeightService` 串口 `DataReceived`：按 `ScaleType` 分支 `ReceiveHexDingSong` / `ReceiveHexDefault` / PortableXPSY。

## Goals / Non-Goals

**Goals:**

- 新增 `ScaleType.DingSongAddr4 = 4`，UI 描述「顶松Addr4」。
- `DingSongAddr4` + HEX（`TF0`）可稳定解析 H610/H1320 帧并输出 kg 重量（610 / 1330）。
- 顶松 `DingSong` 行为不变。

**Non-Goals:**

- 不修改顶松 12 字节协议以“兼容” `2A…0D`。
- 不引入新 NuGet / 独立 parser 程序集（解析仍放在 `TruckScaleWeightService`，与现有秤型一致）。
- 不自动迁移旧客户配置到 `DingSongAddr4`。
- 不处理 Toledo 或其他未抓包协议。

## Decisions

### D1: 枚举成员命名

**选择**：`[Description("顶松Addr4")] DingSongAddr4 = 4`

**理由**：与 `DingSong` 命名族一致；值 `4`；显示名「顶松Addr4」区分协议。

**备选**：仅用 `Addr4` — 语义偏弱，已否决。

### D2: 帧格式与重量算法（对齐 H610/H1320）

**帧（定长 17）**：

| Offset | 值 | 含义 |
|--------|-----|------|
| 0 | `0x02` | STX |
| 1 | `0x2A` | `*` |
| 2 | `0x30` | ASCII `0`（状态/前缀，解析时跳过非重量数字区） |
| 3 | `0x20` | 空格 |
| 4–15 | 12× ASCII 数字 | 重量载荷 |
| 16 | `0x0D` | CR |

**重量**：取载荷 **前 6 位** ASCII 解析为整数 **kg**（无小数除法）。

- H610：`000610……` → **610**
- H1320：`001330……` → **1330**

随后走现有 `ConvertWeight`（`ScaleUnit` kg/t）。

**备选**：整段 12 位 /100 或 /1000 — 与文件名语义（610、1320）不符，否决。

### D3: 接收缓冲策略

**选择**：`ReceiveHexDingSongAddr4`（或等价私有方法）：在缓冲中扫描 `02 … 0D`，凑满 17 字节再解析；非法帧丢弃并继续扫下一 `02`。

**理由**：抓包为连续粘包；与 DingSong 固定读 12 字节类似，但结束符为 CR。

**备选**：复用 `ReceiveHexDefault` — 其假设 ETX=`03` 与 `+`/`-`，不适合。

### D4: 路由

在现有 HEX 分支中：

```
if (scaleType == ScaleType.DingSongAddr4) ReceiveHexDingSongAddr4();
else if (scaleType == ScaleType.DingSong) ReceiveHexDingSong();
else ReceiveHexDefault();
```

PortableXPSY / TestMode / String 路径不变。

### D5: 设置 UI

依赖 `ScaleType.GetDescription()` 的下拉会自动出现「顶松Addr4」。若代码中有硬编码 `Enum.GetValues` 过滤列表，补上 `DingSongAddr4`。不改 XAML 结构。

## Risks / Trade-offs

- [前 6 位 kg 假设与其它顶松 Addr4 仪表小数位不一致] → 以 H610/H1320 为契约；若现场有小数再开 change 扩展。
- [粘包/半包] → 缓冲扫描直至完整 17 字节帧；单测覆盖单帧与双帧拼接。
- [用户误选顶松] → 保持 Reject 测试；文档/设置描述区分「顶松」与「顶松Addr4」。

## Migration Plan

1. 发布含 `DingSongAddr4` 的客户端。
2. 现场设置 → 秤类型选「顶松Addr4」，通信方式 HEX/`TF0`。
3. 回滚：改回顶松或其他类型即可；无需 DB migration。

## Open Questions

- 无阻塞项。若后续确认重量含小数位，再修订 D2。
