## Context

`align-solidwaste-weights-ui-f2` 已让导出/打印与 UI F2 通道对齐，但净仍独立 Round，破坏 `毛−皮=净`。Human 确认要逻辑恒等、不追求库净显示精确性；范围仅固废。

## Goals / Non-Goals

**Goals:**

- 固废 UI（主界面净重块 + 详情）、Excel、小票：`毛′−皮′=净′`。
- 单一 Displayed 口径：`Round(..., 2, AwayFromZero)`。

**Non-Goals:**

- 标准 / Recycle / Urban 行为变更（Recycle 主界面净重块保持原样）。
- 回写库净；改超差/计划重量。

## Decisions

### D1: 净 = Displayed(毛) − Displayed(皮)

不用 `JoinWeight − OutWeight`（发料时进/出场语义对调）。权威毛皮仍是 `OrderTotalWeight` / `OrderTruckWeight`。

### D2: `MaterialMath.DeriveDisplayedNetTon`

集中派生，导出与 UI 共用；打印用 kg 相减保证整数恒等。

### D3: 详情仅 SolidWaste 覆盖

基类仍 `GoodsWeight = AllWeight - TruckWeight`；`SolidWasteWeighingDetailViewModel` 追加订阅：`GoodsWeight = Round(All) − Round(Truck)`，避免改标准模式。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 对外净与库净差 0.01 | 产品已接受 |
| 详情双订阅竞态 | SolidWaste 后注册，后写覆盖为派生值 |
