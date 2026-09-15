## Context

现状：`TruckScaleWeightService`（~1300 行）与其它硬件服务并列于 `MaterialClient.Common/Services/Hardware/`，按 `ScaleType` / 内部 `ReceType` 分支解析；`ScaleSettings.CommunicationMethod` 字符串对协议选择作用弱。调研结论见 `docs/2026-09-15-truck-scale-transmission-format-refactor/`。

本 change 是 initiative **`dev-truck-scale-weight`** 的第一 Phase：建立接口与目录分类，迁出 **tf0**，**不实现**耀华 tf1。

约束：`minimal-di`（纯解析不硬注册 Transient）、`strategic-fallback`（禁止假重量/假在线）、跨仓 C# **禁止 tuple**（多值用 `record`）、ViewModel 不碰 Repository。

## Goals / Non-Goals

**Goals:**

- 强类型 `TransmissionFormatType` 成为配置与路由键。
- 地磅类型按目录分类，不再扁平堆在 `Hardware`。
- Router 对每个已进枚举的 `ScaleType × TransmissionFormatType` 有确定协议实例。
- 各 ScaleType 的 **Type0** 行为与现网等价迁出；Type1（含耀华）本 Phase 明确失败路径。
- 对外 `ITruckScaleWeightService` 契约保持，称重业务尽量无感。

**Non-Goals:**

- 实现 `Yaohua` × `TransmissionFormatType1` 指令应答解析（下一 Phase）。
- 新增候选 ScaleType（柯力/Toledo 等）。
- 改 UrbanManagement / 上云 / 毛皮净生产记账。
- 把相机、小票打印等非地磅类型迁入 `TruckScale`。

## Decisions

### D1 — 目录与命名空间分类（非平坦 Hardware）

**Decision：** 新建 `Services/TruckScale/` 树；地磅门面与协议迁入。其它硬件留在 `Hardware/`。

```text
Services/TruckScale/
  Facade/
    ITruckScaleWeightService.cs
    TruckScaleWeightService.cs
  Routing/
    ITruckScaleProtocolRouter.cs
    TruckScaleProtocolRouter.cs
  Protocols/
    IScaleTransmissionProtocol.cs
    ScaleProtocolContext.cs          // record，非 tuple
    Unsupported/
      UnsupportedTransmissionFormatProtocol.cs
    Yaohua/
      YaohuaTf0Protocol.cs
      // YaohuaTf1Protocol — OUT OF SCOPE Phase 1
    DingSong/
      DingSongTf0Protocol.cs
    DingSongAddr4/
      DingSongAddr4Tf0Protocol.cs
    PortableXpsy/
      PortableXpsyTf0Protocol.cs
    TestMode/
      TestModeTf0Protocol.cs
```

`SerialPortFactory` / `SerialPortWrapper` 仍可留在 `Hardware/`（多设备共用）；门面注入使用。

命名空间与文件夹对齐，例如 `MaterialClient.Common.Services.TruckScale.Protocols.Yaohua`。

**Alternatives：** 仅在 `Hardware/TruckScale/` 下分子夹 — 仍把地磅与 USB/打印视觉混在 Hardware 根语义下；否决，改独立 `TruckScale` 根。

### D2 — 门面 + Router + Protocol

**Decision：** 保留 `ITruckScaleWeightService` 为唯一业务入口；门面持有串口生命周期、锁、`WeightUpdates` Subject、当前 `ScaleSettings`；`ITruckScaleProtocolRouter.Resolve(ScaleType, TransmissionFormatType)` 返回 `IScaleTransmissionProtocol`。

协议职责：帧解析 /（未来）轮询；`EnsureSupported` 在不支持时 **MUST throw**（含 ScaleType + TransmissionFormatType 元数据）。禁止返回 0 重量假装在线。

**Alternatives：** 拆多个 `IYaohuaScaleService` 给业务 — 调用方爆炸；否决。

### D3 — Phase 1 对 Type1（含耀华）的行为

**Decision：**

| 组合 | Router 结果 | UI |
|------|-------------|-----|
| 任意 ScaleType × Type0 | 对应 `*Tf0Protocol` | 可选 `(tF0)` |
| 任意 ScaleType × Type1（**含 Yaohua**） | `UnsupportedTransmissionFormatProtocol`（或同名 Deferred stub） | **不启用** `(tF1)` |
| JSON 绕过写入 Type1 | Initialize / EnsureSupported **抛不支持或未实现** | — |

下一 Phase 仅将 `Yaohua × Type1` 换成真实 `YaohuaTf1Protocol`，并开放耀华 UI 选项。

**Alternatives：** Phase 1 就开放耀华 Type1 UI 但 Initialize 失败 — 易造成现场误选；否决。

### D4 — 配置迁移

**Decision：** 删除 `CommunicationMethod`；新增 `TransmissionFormatType` 默认 `TransmissionFormatType0`；反序列化忽略旧键、不映射。设置页删除 `ScaleCommunicationMethod` TextBox，改为 ComboBox。`IsValid()` 不再要求通讯方式字符串非空。

详文对齐 `docs/.../03-旧通讯方式与枚举兼容.md`。

### D5 — DI

**Decision：** Router 可作为轻量可注入组件（若需可测试替换）；各 `*Tf0Protocol` 优先无状态类型，由 Router 持有/创建实例，**不**为纯解析注册一堆 Transient。符合 `minimal-di`。

### D6 — Git Mode B

**Decision：** Apply 时自 **`dev-truck-scale-weight`** 切出同名分支 `refactor-truck-scale-transmission-format`（MaterialClient 有代码；monospec 有 OpenSpec）。验证后 squash 回 `dev-truck-scale-weight`，不直接进 trunk。

### D7 — 回退

**Decision：** Phase 1 迁移巨石时可保留短期功能开关回退旧类（strategic-fallback Pattern A）；默认路径为新目录实现。开关删除留待后续 Phase。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 迁出 tf0 时帧解析回归 | 对照现网样帧 + 现有测试；功能开关可回退 |
| 命名空间/DI 注册路径变更漏改 | 全仓搜 `Hardware.TruckScale` / `ITruckScaleWeightService` |
| 现场旧 JSON 曾依赖非 TF0 旁路 | 升级后默认 Type0；靠正确 ScaleType（如 PortableXPSY）表达 |
| 目录搬迁 diff 大 | 先搬接口与空壳再迁解析，便于审查 |

## Migration Plan

1. 合入 `dev-truck-scale-weight` 后发版客户端。
2. 旧盘忽略 `CommunicationMethod` → 默认 Type0。
3. 用户保存设置一次后 JSON 写入 `TransmissionFormatType`。
4. Rollback：功能开关回旧巨石类，或回退该 squash（initiative 基线上）。

## Open Questions

1. 功能开关是否本 Phase 必须带上，还是迁出后直接切新路径、靠 git 回退？（建议：有开关更安全，tasks 中列为可选勾选项。）
2. `ITruckScaleWeightService` 文件是否保留旧路径 type-forward 一版过渡？建议 **直接迁文件并修 using**，不留永久转发。
