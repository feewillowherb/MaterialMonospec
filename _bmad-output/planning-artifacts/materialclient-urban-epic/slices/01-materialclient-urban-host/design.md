## Context

MaterialClient 主程序为 Avalonia + 完整授权与 UI。Urban 宿主需共享 Domain/基础设施但剥离 UI 与登录。

## Goals / Non-Goals

**Goals**

- 可独立 `dotnet run` 的 Urban 宿主
- 配置与主客户端风格一致（`appsettings.json` + 环境变量）
- 启动日志可见授权文件检查结果

**Non-Goals**

- UI 页面、托盘、登录窗
- 真实授权算法
- 称重、上传（后续 slice）

## Decisions

1. **宿主类型**：`Microsoft.Extensions.Hosting` + `BackgroundService` 占位，替代 Avalonia `App.axaml`。
2. **模块**：`UrbanAppModule : AbpModule`，DependsOn 共享 `MaterialClientApplicationModule` 等，**排除** UI/Auth 模块。
3. **配置类** `UrbanOptions`：`ProductCode`、`WeighingMode`、`LicenseFilePath`、`ServerBaseUrl`（上传 slice 使用）。
4. **StaticAuthChecker**：`CheckOnStartup()` 同步读文件；`FailFast` 默认 `false`。
5. **枚举**：在共享 `WeighingMode` 增加 `UrbanMode = 201`；常量类 `UrbanProductCodes.Code5030 = 5030`。

## Risks / Trade-offs

| 风险 | 权衡 |
|------|------|
| ABP 模块依赖过重 | 仅引用 Urban 所需模块，避免拉入 Waybill UI |
| 双宿主维护成本 | 共享 Directory.Build.props，文档化差异 |
