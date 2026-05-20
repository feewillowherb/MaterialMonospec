## Why

城市管理场景需要独立于 MaterialClient 主程序的轻量采集宿主：无 UI、无登录、专用 ProductCode/WeighingMode，且启动时通过静态授权文件占位校验。本 slice 建立 `MaterialClient.Urban` 项目骨架与配置体系，为后续称重与上传能力提供宿主。

## What Changes

- 在 MaterialClient 解决方案中新增 **`MaterialClient.Urban`** 可执行项目（.NET 10），引用现有 Core/Application/Infrastructure 层（按实际解决方案结构调整）。
- 新增 **`UrbanMode = 201`** 与默认 **`ProductCode = 5030`** 配置绑定。
- 实现 **`IStaticLicenseChecker`** 启动占位：读取 `Urban:LicenseFilePath`，存在/缺失仅写日志，不实现完整密码学校验。
- 提供 **Generic Host** 启动（非 Avalonia），注册 Urban 专用 `UrbanModule` / `appsettings.Urban.json`。
- **不**引入 Avalonia UI 项目引用；**不**注册登录/Session 模块。

## Capabilities

### New Capabilities

- `materialclient-urban-host`: MaterialClient.Urban 独立宿主、Urban 配置节、ProductCode 5030 / WeighingMode 201、静态授权启动日志占位。

### Modified Capabilities

- （可选）共享枚举/常量所在 capability：若 `WeighingMode` 在现有 spec 中定义，则 **Modified** 增加 `UrbanMode = 201` 的文档化要求（实施时定位具体 spec 名）。

## Impact

| 范围 | 说明 |
|------|------|
| **子仓库** | MaterialClient only |
| **目录** | 新 `src/MaterialClient.Urban/`（或同级命名）、解决方案文件、启动 `Program.cs` |
| **依赖** | 引用 MaterialClient 共享项目；**不**引用 Avalonia / ReactiveUI 视图层 |
| **风险** | 与主 MaterialClient 启动模块重复 — 通过独立 Module 类隔离 |
