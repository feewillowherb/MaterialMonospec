## Context

Phase 1（`refactor-truck-scale-transmission-format`）已合入 initiative **`dev-truck-scale-weight`**：`Services/TruckScale/` 门面 + Router + 各 `*Tf0Protocol`；任意 `TransmissionFormatType1`（含耀华）→ `UnsupportedTransmissionFormatProtocol`；Settings 不启用 `(tF1)`。

调研拍板见 `docs/2026-09-15-truck-scale-transmission-format-refactor/`（尤其 06 §10 / §10.3.1）：

- 生产耀华 Type1 = **连续查询听流**，**不**向设备发查询命令（≠ Demo/手册写指令应答）。
- 重量：**优先**连续查询皮/毛/净（**三者全部有效**）；**任一无效** → **降级旧稳定模式**；Type1 下实时重量流仍必须可用。
- `CommunicationParameter`：不透明 `string?`；切 TF 即重置；耀华默认 **`A`**；实现方解析。

约束：`minimal-di`、`type-owned-methods`、`strategic-fallback`（禁止假重量）、跨仓 C# **禁止 tuple**、ViewModel 不碰 Repository。

## Goals / Non-Goals

**Goals:**

- 落地 `YaohuaTf1Protocol` 连续查询解析，并接到 Router / 门面 `OnDataReceived`。
- 耀华 Settings 可选 `(tF1)`；非耀华仍不可选且协议 Unsupported。
- 引入 `CommunicationParameter`（切 TF 重置；耀华默认 `A`）。
- 持续发布实时重量；皮毛净全有效时优先供过磅；任一无效走现网稳定路径。

**Non-Goals:**

- 把 Demo `Build` + 写端口轮询拷进生产门面。
- 非耀华 Type1 真协议；新 ScaleType。
- UrbanManagement / 上云报文形状改造。
- 大范围重做有人值守过磅 UI（仅接线优先/降级策略）。

## Decisions

### D1 — 生产 Type1 = 连续查询听流（禁止写查询）

**Decision：** `YaohuaTf1Protocol` 仅通过门面已有的串口到达数据路径（`OnDataReceived` / 等价连续读）解析帧；**MUST NOT** 为取重调用写串口查询/控制命令。`PollAsync` 若保留于接口亦不得用于生产 Type1 写查询。

**Alternatives：** 跟 Demo 指令应答 — 与已拍板冲突；否决。

### D2 — Router 仅解锁耀华 Type1

**Decision：**

| 组合 | Resolve |
|------|---------|
| `Yaohua` × Type0 | `YaohuaTf0Protocol`（不变） |
| `Yaohua` × Type1 | **`YaohuaTf1Protocol`（本 change）** |
| 其它 ScaleType × Type1 | `UnsupportedTransmissionFormatProtocol` |
| 其它 × Type0 | 既有 `*Tf0Protocol` |

**Alternatives：** 所有 Type1 开空壳 — 违反 strategic-fallback；否决。

### D3 — `CommunicationParameter` 通用槽

**Decision：** `ScaleSettings` 增加 `string? CommunicationParameter`。Settings / 门面在 **每次** `TransmissionFormatType` 变更时重置为默认：

- 耀华（Type0 或 Type1）：默认 `"A"`（地址枚举语义，实现方解释）。
- 其它 ScaleType：默认可为 `null` 或空（本 change 不强制业务使用）。

解析：**仅**协议实现方 `TryParse` / 过滤；门面不统一 Parse。生产 Type1 **不得**用该参数组帧写查询。

**Alternatives：** 属性名 `CommunicationAddress` — 非通用；否决。切 TF 保留旧值 — 与拍板冲突；否决。

### D4 — 重量表面：实时流 + 皮毛净 record

**Decision：**

1. 门面继续 `IObservable<decimal> WeightUpdates`（或等价）发布**实时显示重量**，保证稳定窗口可用。
2. 新增命名 `record`（示意）承载连续查询分量，例如：

```csharp
public sealed record YaohuaComponentWeights(
    decimal? Gross,
    decimal? Tare,
    decimal? Net,
    bool AllValid);
```

   （具体属性名以实现为准；**禁止 tuple**。）由 `YaohuaTf1Protocol` 解析后经 context 回调或门面只读表面暴露；`AllValid` 为真 **当且仅当** 皮、毛、净三者均有效。

3. 称重消费（`AttendedWeighingService` 或紧邻适配层）：
   - `AllValid == true` → **优先**用仪表皮/毛/净记账；
   - 否则 → **降级**现网「实时重量 + 稳定窗口」路径（二次过磅毛→皮→净）。

**Alternatives：** 仅替换 `WeightUpdates` 语义为净重 — 破坏稳定模式与 UI；否决。为降级另开串口会话 — 否决。

### D5 — UI

**Decision：** Settings 在 `ScaleType == Yaohua` 时选项含 `(tF0)` + `(tF1)`；切换 TF 时重置 `CommunicationParameter`。非耀华（含 TestMode）不出现或禁用 `(tF1)`。若用户绕过 JSON 写入非耀华 Type1，Initialize / EnsureSupported 仍抛错。

### D6 — 帧语义与 strategic-fallback

**Decision：** 连续查询帧布局以设备文档 + 可验证样帧 / Demo **听流侧**对照为准；**不以** Demo 写指令路径为准。若皮毛净字段语义在实现前仍无法验证：按 strategic-fallback **显式挂起**分量路径（保持实时流 + 稳定降级可用），**禁止**假分量或改回写指令冒充。

### D7 — DI / Git

**Decision：** `YaohuaTf1Protocol` 无状态优先由 Router `new`；不为纯解析注册 Transient。Mode B：Apply 自 `dev-truck-scale-weight` 切 `add-yaohua-tf1-continuous-query`；验证后 squash 回该基线。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 连续查询帧与手册「经典 tF=1」混淆 | 文档与代码注释标明生产 Type1 ≠ Demo 写指令；单测覆盖「无写端口」 |
| 皮毛净字段不全导致长期落在稳定模式 | 可接受；L2 为正式降级路径，不视为失败 |
| `CommunicationParameter` 被误用于写命令 | Spec + 设计禁止；代码审查拒写查询帧 |
| 称重服务接线面扩大 | 优先最小适配（record + 分支），不重做过磅 UI |
| 切 TF 重置丢用户地址 | 已拍板；UI 可提示「切换格式将重置通讯参数」 |

## Migration Plan

1. 合入 `dev-truck-scale-weight` 后发版客户端。
2. 旧盘无 `CommunicationParameter` → 耀华默认 `A`（或缺省后首次选 TF 写入）。
3. 默认仍可保持 Type0；用户显式选 Type1 才走连续查询。
4. Rollback：Router 将 Yaohua Type1 指回 Unsupported，或回退该 squash。

## Open Questions

1. 皮毛净 `record` 挂在门面只读属性 / 独立 `IObservable` / 称重服务内协议回调——实现时选对调用方侵入最小者（tasks 允许微调，须仍用命名 record）。
2. 连续查询样帧若现场与文档不一致：本 change 内挂起分量（D6）还是另开 intake？默认 **本 change 内挂起分量、保留实时+稳定**。
