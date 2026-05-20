# Project Context：materialclient-urban-epic

供 OpenSpec `/opsx:apply` 时加载的实现约束（从 BMAD 规划提取）。

## 技术栈

| 区域 | 栈 |
|------|-----|
| MaterialClient.Urban | C# 13 / .NET 10 / 与 MaterialClient 相同的 ABP + EF Core SQLite + 分层 |
| UrbanManagement | ABP 10 / .NET 10 / EF Core SQLite / MVC + LayUI |
| 规范仓库 | MaterialMonospec `openspec/` only |

## 必须遵守

1. **OpenSpec 工件**只写在主仓库 `openspec/changes/<change-id>/`。
2. **代码**写在 `repos/MaterialClient` 或 `repos/UrbanManagement`，提交在各自子仓库。
3. **tasks.md** 仅由 OpenSpec 生成，不从 BMAD 拷贝任务列表。
4. Urban 宿主 **无 Avalonia UI**（首期）；**无登录**；**无 waybill 匹对**。
5. 常量：**ProductCode = 5030**，**WeighingMode = 201（UrbanMode）**。
6. 静态授权：**启动时读文件 + 日志**；完整校验留接口占位。
7. 上传范围：仅 **WeighingRecord** 相关 DTO。
8. 遵循现有命名：英文标识符、ABP 模块、`Entity<T>`、应用服务 + DTO。

## 禁止

- 在 `repos/` 下创建 `openspec/` 变更目录
- 使用 BMAD `bmad-dev-story` / `bmad-sprint-planning` 生成实施任务
- 在 MaterialClient 主宿主默认启用 UrbanMode（除非显式配置）
- 首期实现完整授权密码学或登录页

## 测试建议

- MaterialClient.Urban：集成测试 — 内存 SQLite + Mock Urban API
- UrbanManagement：WebApplicationFactory 测试 API 写入与查询

## 参考

- PRD: `_bmad-output/planning-artifacts/materialclient-urban-epic/prd.md`
- 架构: `architecture.md`
- 操作手册: `docs/operation-manual.md`
