## 1. 目录迁移（MaterialClient 子仓库）

- [x] 1.1 使用 `git mv` 将 `MaterialClient`、`MaterialClient.Common`、`MaterialClient.UI`、`MaterialClient.Urban`、`MaterialClient.Demo`、`MaterialClient.Toolkit` 移至 `src/`
- [x] 1.2 使用 `git mv` 将 `MaterialClient.Common.Tests` 移至 `tests/`
- [x] 1.3 更新所有 `.csproj` 中 `ProjectReference` 相对路径（尤其 `tests` → `src`）

## 2. 解决方案与构建脚本

- [x] 2.1 重写 `MaterialClient.sln`：添加 `src`/`tests` 解决方案文件夹与 `NestedProjects` 嵌套
- [x] 2.2 更新 `MaterialClient.iss` 中 `SourceDir`、`SetupIconFile` 等路径为 `src\MaterialClient\...`
- [x] 2.3 更新 `publish.cmd` 指向 `src/MaterialClient/MaterialClient.csproj`
- [x] 2.4 全仓库搜索并修复硬编码旧路径（`_build_verify`、文档、脚本）

## 3. Urban 安装包

- [x] 3.1 新建 `MaterialClient.Urban.iss`（参考 `MaterialClient.iss`，独立 AppId、Urban exe/路径/图标）
- [x] 3.2 新建 `publish-urban.cmd`（publish `src/MaterialClient.Urban/MaterialClient.Urban.csproj`）
- [x] 3.3 本地验证：`dotnet publish` + Inno Setup 生成 `Installer/MaterialClient.Urban_Setup_*.exe`

## 4. 验证

- [x] 4.1 `dotnet build MaterialClient.sln`（Debug/Release）
- [x] 4.2 `dotnet test tests/MaterialClient.Common.Tests/MaterialClient.Common.Tests.csproj`
- [x] 4.3 确认 Monospec/CI 文档无遗漏旧路径（主仓库 `monospecs.yaml` 若仅联接路径则通常无需改）
