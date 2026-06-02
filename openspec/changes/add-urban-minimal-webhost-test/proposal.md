## Why

`MaterialClient.Urban` 目前缺少可直接用于本地联调和验收的最小 WebHost 测试能力，导致服务端联通性与 API 兼容问题只能在完整流程中被动发现。需要新增一套可独立运行的测试入口，尽早验证 UrbanManagement 接口可用性。

## What Changes

- 在 `MaterialClient.Urban` 增加 `MinimalWebHostService.cs` 测试能力，用于本地最小化宿主与接口联通验证。
- `MinimalWebHostService.cs` 采用“直接复制现有可用功能”的实现方式，不做跨模块复用抽象。
- 提供可触发的测试流程与结果输出（成功/失败、错误信息），支持快速定位配置与接口问题。
- 补充与 UrbanManagement 服务地址配置协同的行为约定，确保测试入口读取同一配置来源。

## Capabilities

### New Capabilities

- `urban-minimal-webhost-test`: 为 `MaterialClient.Urban` 提供最小 WebHost 测试入口与执行反馈能力。

### Modified Capabilities

- `materialclient-urban-desktop`: 增加 Urban 客户端中的最小 WebHost 测试流程与配置联动要求。

## Impact

- 影响代码：`repos/MaterialClient/src/MaterialClient.Urban`（服务层、启动配置、可能的 UI 触发入口）。
- 影响配置：`MaterialClient.Urban` 的 `appsettings*.json`（UrbanManagement 服务地址）。
- 影响测试与联调：新增最小化 WebHost 测试路径，缩短 UrbanManagement API 联调反馈周期。
