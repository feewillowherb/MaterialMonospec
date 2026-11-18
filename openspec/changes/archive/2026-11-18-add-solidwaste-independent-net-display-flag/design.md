## Context

`align-solidwaste-derived-net` 强制 `净′ = 毛′ − 皮′`。历史单在独立 Round 下可出现 `8.28/6.22/2.07`。Human 要求 ExtraProperties bool 启用旧显示。

## Goals / Non-Goals

**Goals:**

- 按 Waybill 开关：独立 Round 库净 vs 派生净。
- 导出 / 小票 / 主界面净重块 / 固废详情同一判断。

**Non-Goals:**

- 配置白名单；表结构 migration；自动识别不等式单；改入库公式。

## Decisions

### D1: 键名 `SolidWasteInfo.UseIndependentDisplayedNet`

与其它 `SolidWasteInfo.*` 一致；缺省/false = 派生。

### D2: 投影到 `WeighingListItemDto.UseIndependentDisplayedNet`

主界面与详情不读 DbContext；详情独立模式净重用 `Round(OrderGoodsWeight)`，不用 `Round(All−Truck)`。

### D3: 打标在仓外

OpenSpec 只交付代码能力；三条样例数据用 SQLite/工具更新 ExtraProperties JSON。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 详情编辑毛皮后独立模式净仍跟库净 | 仅历史完成单；可接受 |
| ExtraProperties bool 反序列化 | 缺省 false；单测覆盖 true |
