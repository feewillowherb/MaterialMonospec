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

## 禁止

- 将 Urban 实现为无 UI 的 Host/控制台程序（除非临时 spike，不交付）
- 添加 LoginWindow、LicenseWindow、多页面 Shell 导航
- BMAD Phase 4 任务清单；子仓库内建 openspec change

## 参考

- `prd.md`、`architecture.md`、`ui-layout-reference.md`
