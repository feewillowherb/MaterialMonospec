# Project Context：materialclient-urban-epic

## 技术栈

| 区域 | 栈 |
|------|-----|
| MaterialClient.Urban | C# 13 / .NET 10 / **Avalonia UI 11** / **ReactiveUI** / ABP + EF Core SQLite |
| UI 草稿 | `MaterialClient.Demo/Views/WeighingSystemWindow.axaml` |
| UrbanManagement | ABP 10 / .NET 10 / EF Core / MVC + LayUI |

## 必须遵守

1. **MaterialClient.Urban 是桌面端**，不是 Generic Host / headless Worker。
2. **仅一个主界面**（称重系统窗）；**无登录页、无授权页**。
3. 静态授权：**启动时后台读文件 + 日志**；无授权 UI。
4. **WeighingMode = 201**、**ProductCode = 5030**；**无 waybill 匹对**。
5. 上传仅 **WeighingRecord**；OpenSpec 工件仅在主仓库 `openspec/`。
6. UI 布局遵循 `ui-layout-reference.md`。
7. **称重与记录落库**：复用 **`MaterialClient.Common` 的 AttendedWeighing 既有逻辑**；UrbanMode 通过配置/策略/守卫跳过 waybill；**禁止**在 Urban 中平行复制整套有人值守称重状态机；确需差异时在 Common **最小扩展**并回归有人值守。
8. **上云调度**：与 **`MaterialClient.Backgrounds.PollingBackgroundService`** 相同 — **`AsyncPeriodicBackgroundWorkerBase` + UOW** 周期上传 Pending；**禁止**以 UI 线程为主上传路径。
9. **设备 ID（OQ-3）**：实现 **`IDeviceIdentityProvider`**，首期 **仅**返回配置中的 **固定 `Guid`**；真实机器/注册策略见 PRD **未来缓解**，另 change。
10. **`Urban_WeighingRecord`（服务端）**：列定义 **OpenSpec 阶段对照 `repos/MaterialClient` 的 `WeighingRecord` + EF 配置** 定稿；BMAD 仅「同构/子集 + 元数据」原则。

## 禁止

- 将 Urban 实现为无 UI 的 Host/控制台程序（除非临时 spike，不交付）
- 添加 LoginWindow、LicenseWindow、多页面 Shell 导航
- BMAD Phase 4 任务清单；子仓库内建 openspec change
- 为 Urban 单独重写与 AttendedWeighing 等价的完整称重管线（除非 proposal 明确废弃本约束）
- 将 UrbanManagement 上传实现为 **UI 同步 HTTP 主路径**（与 Material 后台 Worker 模式冲突时以 PRD FR-4.3 为准）

## 参考

- `prd.md`、`architecture.md`、`ui-layout-reference.md`
