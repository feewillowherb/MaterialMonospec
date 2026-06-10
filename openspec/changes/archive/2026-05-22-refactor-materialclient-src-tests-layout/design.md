## Context

**UrbanManagement 参考布局：**

```
UrbanManagement/
├── UrbanManagement.sln
├── Directory.Build.props
├── Directory.Packages.props
├── src/
│   ├── UrbanManagement.Core/
│   └── UrbanManagement.App/
└── tests/
    └── UrbanManagement.Core.Tests/
```

**MaterialClient 当前布局（扁平）：**

```
MaterialClient/
├── MaterialClient.sln
├── MaterialClient.iss
├── MaterialClient/
├── MaterialClient.Common/
├── MaterialClient.UI/
├── MaterialClient.Urban/
├── MaterialClient.Demo/
├── MaterialClient.Toolkit/
└── MaterialClient.Common.Tests/
```

`MaterialClient.iss` 假定发布输出在 `MaterialClient/bin/Release/net10.0/win-x64/publish`，图标在 `MaterialClient/Assets/fd-ico.ico`。Urban 使用相同单文件发布模式（`PublishSingleFile`、`win-x64`），exe 名为 `MaterialClient.Urban.exe`。

## Goals / Non-Goals

**Goals:**

- 采用 `src/` + `tests/` 标准布局，与 UrbanManagement 及常见 .NET 解决方案实践一致
- 解决方案内通过 Solution Folder 可视化分组
- 提供 `MaterialClient.Urban.iss`，可生成城管变体 Windows 安装包
- 迁移后 `dotnet build` / `dotnet test` / `dotnet publish` 与现有发布流程仍可用

**Non-Goals:**

- 引入 `Directory.Packages.props`（若当前不存在，不在本变更强制添加）
- 为 Demo/Toolkit 单独创建 `.iss`（仅 Urban + 更新主程序 `.iss` 路径）
- 修改 Monospec 主仓库 `repos/` 联接机制

## Decisions

### 决策 1：目标目录映射

| 当前路径 | 新路径 |
|---------|--------|
| `MaterialClient/` | `src/MaterialClient/` |
| `MaterialClient.Common/` | `src/MaterialClient.Common/` |
| `MaterialClient.UI/` | `src/MaterialClient.UI/` |
| `MaterialClient.Urban/` | `src/MaterialClient.Urban/` |
| `MaterialClient.Demo/` | `src/MaterialClient.Demo/` |
| `MaterialClient.Toolkit/` | `src/MaterialClient.Toolkit/` |
| `MaterialClient.Common.Tests/` | `tests/MaterialClient.Common.Tests/` |

根目录保留：`MaterialClient.sln`、`MaterialClient.iss`、`MaterialClient.Urban.iss`（新）、`Directory.Build.props`、`publish.cmd`、`AGENTS.md` 等。

### 决策 2：使用 `git mv` 保留历史

**选择：** 对各项目目录执行 `git mv`，避免删除+新增导致 blame 断裂。

**理由：** 大型目录结构变更时历史可追溯性重要。

### 决策 3：解决方案文件结构

**选择：** 仿照 `UrbanManagement.sln` 添加两个 solution folder（`src`、`tests`），`GlobalSection(NestedProjects)` 嵌套项目 GUID。

**ProjectReference 更新规则：**

- `src` 内项目互引：`..\MaterialClient.Common\` 等同层相对路径不变
- `tests` 引用 `src`：`..\..\src\MaterialClient.Common\`（一层 `tests`，一层项目名）

### 决策 4：MaterialClient.Urban.iss

**选择：** 新建 `MaterialClient.Urban.iss`，从 `MaterialClient.iss` 复制并调整：

| 宏 | Urban 值 |
|----|----------|
| `MyAppName` | `MaterialClient.Urban` 或中文显示名「凡东城管地磅系统」 |
| `MyAppExeName` | `MaterialClient.Urban.exe` |
| `SourceDir` | `src\MaterialClient.Urban\bin\Release\net10.0\win-x64\publish` |
| `SetupIconFile` | `src\MaterialClient.Urban\Assets\fd-ico.ico` |
| `AppId` | 新 GUID（与主程序安装包区分） |
| `OutputBaseFilename` | `MaterialClient.Urban_Setup_{version}` |

主程序 `MaterialClient.iss` 同步更新 `SourceDir`、`SetupIconFile` 为 `src\MaterialClient\...`。

### 决策 5：发布脚本

**选择：** 新增 `publish-urban.cmd`（或 `publish.cmd urban`）：

```cmd
dotnet publish src/MaterialClient.Urban/MaterialClient.Urban.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true
```

主程序 `publish.cmd` 改为显式项目路径 `src/MaterialClient/MaterialClient.csproj`。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 遗漏硬编码旧路径（脚本、文档、CI） | 全仓库 `rg` 搜索旧路径；`dotnet build` 全解决方案 |
| IDE 用户打开旧 `.sln` 报项目缺失 | 一次性迁移提交说明 BREAKING |
| 两个 `.iss` AppId 冲突 | Urban 使用独立 `AppId` GUID |
| `_build_verify` 等辅助目录路径失效 | 任务中一并更新或删除过时验证目录 |

## Migration Plan

1. `git mv` 所有项目目录到 `src/`、`tests/`
2. 批量更新 `.sln`、`.csproj` ProjectReference
3. 更新 `MaterialClient.iss`、新增 `MaterialClient.Urban.iss`、`publish*.cmd`
4. `dotnet build MaterialClient.sln` + `dotnet test`
5. `dotnet publish` + Inno Setup 编译验证（本地）

**回滚：** 反向 `git mv` 并恢复 `.sln`/`.iss` 路径。

## Open Questions

- 安装包显示名称：使用 `MaterialClient.Urban` 还是「凡东城管地磅系统」（实现时默认中文显示名 + 英文文件夹名）
- `MaterialClient.Demo` / `Toolkit` 是否纳入 `src` 但在解决方案中标记为可选构建（默认全部迁入 `src`）
