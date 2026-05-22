## Why

MaterialClient 解决方案当前将所有 `.csproj` 平铺在仓库根目录，与已采用的 UrbanManagement（`src/` + `tests/` + 解决方案文件夹分组）不一致，不利于多应用变体（主程序、Urban、Demo、Toolkit）的长期维护与 CI 路径约定。同时 Urban 变体已具备独立发布能力，但缺少与主程序 `MaterialClient.iss` 对等的 Inno Setup 安装包脚本，影响城管现场的正式交付。

## What Changes

- 将 MaterialClient 解决方案项目迁移至 `src/` 与 `tests/` 目录，对齐 UrbanManagement 布局
- 更新 `MaterialClient.sln`：添加 `src` / `tests` 解决方案文件夹，`NestedProjects` 嵌套各项目
- 更新所有 `ProjectReference` 相对路径、`MaterialClient.iss` 的 `SourceDir` / `SetupIconFile` 等路径
- 新增 `MaterialClient.Urban.iss`（参考 `MaterialClient.iss`）：打包 `MaterialClient.Urban` 单文件发布输出
- 视需要新增 `publish-urban.cmd` 或扩展 `publish.cmd` 支持 Urban 发布参数
- 更新 CI/文档/Monospec 中硬编码的旧项目路径（若有）

**BREAKING（对开发者本地习惯）：** 克隆后项目路径由 `MaterialClient/MaterialClient.csproj` 变为 `src/MaterialClient/MaterialClient.csproj`；IDE 需重新打开解决方案。

## Capabilities

### New Capabilities

- `materialclient-solution-layout`: MaterialClient 仓库 `src/`、`tests/` 目录结构与解决方案组织规范
- `materialclient-urban-installer`: MaterialClient.Urban 的 Inno Setup 安装程序脚本与发布路径约定

### Modified Capabilities

- `build-configuration`: 补充解决方案目录布局与 `.iss` 发布脚本路径须与 `src/` 布局一致的要求

## Impact

**受影响的代码（MaterialClient 子仓库）：**

- 目录移动：`MaterialClient/`、`MaterialClient.Common/`、`MaterialClient.UI/`、`MaterialClient.Urban/`、`MaterialClient.Demo/`、`MaterialClient.Toolkit/` → `src/`；`MaterialClient.Common.Tests/` → `tests/`
- `MaterialClient.sln`、`*.csproj` 项目引用、`MaterialClient.iss`、新建 `MaterialClient.Urban.iss`
- 根级 `Directory.Build.props` 保持不变（继续作用于 `src/**`、`tests/**`）
- `publish.cmd`、`_build_verify/`、脚本中的路径引用

**非目标：**

- 不重命名程序集或根命名空间
- 不合并/拆分现有项目（如 Demo、Toolkit 仍保留独立项目）
- 不修改 UrbanManagement 子仓库
- 不在本变更中实现自动 CI 上传到安装包服务器
