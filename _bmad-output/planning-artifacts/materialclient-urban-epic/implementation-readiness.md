# Implementation Readiness：materialclient-urban-epic

**日期**: 2026-05-20（v0.2 修订）  
**结论**: ✅ **可交给 OpenSpec**

## 检查清单

| 项 | 状态 | 说明 |
|----|------|------|
| PRD | ✅ | v0.2：桌面端 + 单界面 + UI 草稿引用 |
| 架构 | ✅ | Avalonia 单窗口；非 Host |
| UI 参考 | ✅ | `ui-layout-reference.md` ← Demo `WeighingSystemWindow.axaml` |
| Epic 切片 | ✅ | 4 slices；slice 01 更名为 desktop |
| 无 BMAD tasks | ✅ | — |
| UX | ✅ | 以 Demo 草稿为准，非从零 UX workflow |

## 已闭合

- **OQ-2**：通过主界面重量区 + 设备事件触发称重（非 headless）。

## 下一步

```bash
openspec create add-materialclient-urban-desktop
```

将 `slices/01-materialclient-urban-desktop/proposal.md` 导入 propose；附 `design.md` 与 `ui-layout-reference.md`。
