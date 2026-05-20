# Implementation Readiness：materialclient-urban-epic

**日期**: 2026-05-20（v0.2 修订）  
**结论**: ✅ **可交给 OpenSpec**

## 检查清单

| 项 | 状态 | 说明 |
|----|------|------|
| PRD | ✅ | v0.6：OQ-4 表结构对齐 MaterialClient WeighingRecord 原则；v0.5 OQ-3 |
| 架构 | ✅ | Avalonia 单窗口；非 Host |
| UI 参考 | ✅ | `ui-layout-reference.md` ← Demo `WeighingSystemWindow.axaml` |
| Epic 切片 | ✅ | 4 slices；slice 01 更名为 desktop |
| 无 BMAD tasks | ✅ | — |
| UX | ✅ | 以 Demo 草稿为准，非从零 UX workflow |

## 已闭合

- **OQ-1**：UrbanManagement 上传走与 **`MaterialClient.Backgrounds.PollingBackgroundService`** 相同的 **ABP 周期性 Background Worker + UOW** 模式；非「仅 UI 实时直传」主路径。
- **OQ-2**：复用 **`MaterialClient.Common` 的 AttendedWeighing 既有逻辑**实现称重与记录；主界面绑定重量与列表；UrbanMode 下可扩展/分支（如无 waybill）；非 headless 平行实现。
- **OQ-3**：首期 **`IDeviceIdentityProvider` → 配置固定 `Guid`**；未来真实设备标识与平台注册另 change。
- **OQ-4**：`Urban_WeighingRecord` 列级在 OpenSpec 对照 **MaterialClient `WeighingRecord`** 定稿；BMAD 仅原则。

## 下一步

```bash
openspec create add-materialclient-urban-desktop
```

将 `slices/01-materialclient-urban-desktop/proposal.md` 导入 propose；附 `design.md` 与 `ui-layout-reference.md`。
