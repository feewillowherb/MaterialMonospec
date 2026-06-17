## Context

MaterialClient.Urban 在 `MaterialClientUrbanModule.OnApplicationInitializationAsync` 中执行 JWT 离线授权检查（`IStaticLicenseChecker`），优先级为 `LicenseInfo.LatestJwtToken` > `license.urban`。当前实现将失败视为非阻塞：记录 Warning 后继续 SignalR、轮询上传与主界面。`ProId` 仅在 JWT 验签成功时写入 `LicenseInfo.ProjectId`；无授权文件初始化时通常不存在有效 `ProId`。

约束：
- 授权算法与 claims 结构不变（RS256、`Jwt:PublicKey`、issuer/audience）
- ViewModel 不得直接访问 Repository（门禁逻辑放在 Module/App 层）
- OpenSpec 工件仅存在于 MaterialMonospec 主仓库

## Goals / Non-Goals

**Goals:**
- 所有构建配置下，启动时 JWT 校验失败或无法得到有效 `ProId` 时，阻止进入称重主界面
- 向用户显示「软件未授权」对话框，说明需部署 `license.urban`（或联系管理员）
- 用户确认后干净退出应用（`desktop.Shutdown()`）
- 授权成功路径保持不变：写入 `LicenseInfo` 后正常打开 `UrbanAttendedWeighingWindow`

**Non-Goals:**
- 不修改 JWT 签发、UrbanManagement 服务端逻辑
- 不新增在线「输入授权码」UI（仍依赖 `license.urban` / `LatestJwtToken` 文件化引导）
- 不修改主程序 MaterialClient 的登录/授权流程
- 不在本变更中处理授权过期后的「运行中踢出」（仅启动门禁）

## Decisions

### D1: 以启动时 JWT 校验结果为门禁依据（非单独读 DB ProId）

**选择**：复用现有 `OnApplicationInitializationAsync` 中的 `LicenseCheckResult`（`IsSuccess` + `ProId`），门禁条件为 `result.IsSuccess && result.ProId != Guid.Empty`。

**理由**：与 JWT 防篡改模型一致；避免仅篡改 DB `ProjectId` 即可绕过。DB 仅在验签成功后写入。

**备选**：`GetCurrentLicenseAsync()` 查库。未采用——可能残留历史无效行。

### D2: 通过启动结果服务向 App 层传递授权状态

**选择**：新增 `IUrbanStartupAuthorizationResult`（或等效 record + singleton），Module 初始化末尾写入 `IsAuthorized` / `FailureMessage`；`App.axaml.cs` 在 `InitializeAsync` 之后读取并分支。

**理由**：`App.axaml.cs` 已负责创建主窗口；对话框需在 UI 线程、ABP 初始化完成后展示。避免 Module 直接引用 Avalonia Window。

**备选**：在 Module 内抛异常触发 App catch。未采用——异常语义不清，且与「ABP 初始化失败」混淆。

### D3: 未授权 UI 为轻量 Avalonia 对话框

**选择**：新增 `UnauthorizedDialog`（Window 或 `MessageBox` 风格），标题/正文为中文固定文案 + 可选详情（`LicenseCheckResult.Message`）。

**理由**：符合用户「软件未授权」表述；不引入登录壳或新导航。

**备选**：仅 `Console` / 日志。未采用——现场操作员看不到。

### D4: 未授权时不启动设备与 SignalR

**选择**：授权失败时 App 不打开主窗口、不调用 `Initialize()` / `StartDevicesAndStatusMonitoringAsync`；Module 内 SignalR 与 `PollingBackgroundService` 注册仅在授权成功时执行（或将注册保留但 App 立即退出——优先**条件注册**以减少副作用）。

**理由**：避免无 `ProId` 时无意义上传与连接。

## Risks / Trade-offs

- **[首次部署必须先有 license.urban]** → 对话框文案明确路径；实施文档补充
- **[仅有历史 DB 无 JWT 文件]** → 启动 JWT 失败即拦截，不依赖陈旧 DB
- **[与旧 spec「不显示授权窗口」冲突]** → 本变更 MODIFIED `materialclient-urban-desktop` 明确允许未授权对话框
- **[Debug 环境无法无授权测硬件]** → 实施调试须部署有效 `license.urban` 或使用已授权数据库

## Migration Plan

1. 部署新版本前，确认各站点已有有效 `license.urban` 或已完成在线同步的 `LatestJwtToken`
2. 升级后首次启动：有授权则行为不变；无授权则弹窗退出
3. 回滚：还原上一版本 exe（旧版非阻塞启动）

## Open Questions

- 授权**已过期**（JWT `exp` 过去）是否与「从未授权」使用同一文案？（建议：是，统称未授权/授权无效）
- 是否需要在对话框中显示机器码供管理员签发授权？（建议：首期不加，可后续 change）
