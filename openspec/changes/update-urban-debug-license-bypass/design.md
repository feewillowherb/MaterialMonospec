## Context

MaterialClient.Urban 当前有两层授权门禁：

1. `MaterialClientUrbanModule.TryExecuteStartupLicenseCheckAsync` 在启动时先检查数据库 `LicenseInfo.IsExpired`，再由 `IStaticLicenseChecker` 校验 `LatestJwtToken` / `license.urban` 的格式、RS256 签名、issuer、audience、有效期、`proId`、`accessCode` 与 `machineCode`。失败后 `App.axaml.cs` 打开在线激活恢复窗口；未恢复则退出，且主窗口、SignalR、轮询和设备服务不启动。
2. `DeviceStatusSignalRClient.SyncProjectLicenseFromServerAsync` 在连接或重连后调用线上 `VerifyJwtAsync`。服务端返回 `DeviceChanged` 或 `Expired` 时会清理本地 JWT、发布 `LicenseDeviceRevokedEto` / `LicenseExpiredEto`；对应 Urban 事件处理器隐藏主窗口、要求重新激活，并在失败时退出。

因此只跳过 `StaticLicenseChecker` 的 machineCode 比对不足以让错误 license 在 Debug 下正常使用：数据库过期短路、JWT 的其他校验、启动恢复窗口和运行时线上撤销仍可能阻断程序。

本变更只影响 `repos/MaterialClient` 的 Debug 编译产物。Release 授权是安全边界，必须维持现状。

## Goals / Non-Goals

**Goals:**

- Debug 构建在 license 缺失、畸形、错误签名、过期、声明不完整或 machineCode 不匹配时仍进入 Urban 主窗口并启动正常服务。
- Debug 构建获得稳定且完整的开发授权上下文，使依赖 `ProjectId`、`ProName`、`AccessCode` 和 `AuthEndTime` 的本地业务路径可运行。
- Debug 运行期间不调用线上 JWT 反篡改核验，也不因授权过期或设备撤销事件进入重新激活/退出流程。
- Release 构建继续执行所有现有本地和线上授权检查。

**Non-Goals:**

- 不弱化 Release 校验，不提供可在 Release 打开的配置开关或环境变量。
- 不修改 UrbanManagement 的 JWT 签发、反篡改端点或服务端授权规则。
- 不保证 Debug 使用开发授权上下文时向真实生产服务提交的数据具有生产授权语义。
- 不清理现有授权架构、迁移数据库或替换既有在线激活流程。

## Decisions

### 1. 在 Urban 启动编排边界按编译配置选择授权流程

`MaterialClientUrbanModule` 在 `DEBUG` 编译时直接建立成功的开发授权结果，不进入数据库过期短路、license 文件读取、JWT 验签或 machineCode 校验；非 Debug 编译继续调用现有严格流程。

选择启动编排边界而不是仅修改 `StaticLicenseChecker`，因为启动失败还可能发生在调用 checker 之前的 `LicenseInfo.IsExpired`，并且错误 JWT 可能无法提供 `ProId`。`StaticLicenseChecker` 的严格行为因此可在 Release 和独立调用场景中保持清晰。

备选方案：仅在 `StaticLicenseChecker` 中 `#if DEBUG` 返回成功。未采用，因为 checker 无法可靠地从任意错误 license 得到完整业务上下文，也无法绕过 checker 之前的数据库过期判断。

### 2. Debug 使用单一、固定的开发授权上下文

新增不注册 DI 的 Debug 专用静态/record 数据源，集中提供稳定的 `ProjectId`、`ProName`、`AccessCode` 和 `AuthEndTime`；machineCode 继续由现有 `IMachineCodeService.GetMachineCode()` 取得本机真实值。启动时将该上下文写入或更新 `LicenseInfo`，但不把错误 JWT 保存为已验证的 `LatestJwtToken`。

该类型及其调用点使用 `#if DEBUG`，不进入 Release 二进制。默认值与现有 Urban pipeline 演示项目保持一致，避免配置缺失时再次阻塞；如保留 Debug 配置覆盖，也只能影响 Debug 编译块，不能成为 Release 旁路。

选择完整开发上下文而不是只返回 `IsAuthorized = true`，因为设备状态、附件上传及其他服务会读取 `LicenseInfo.ProjectId`、`ProName`、`AccessCode`。

### 3. Debug 跳过整个线上授权同步，而非只忽略结果

`DeviceStatusSignalRClient.SyncProjectLicenseFromServerAsync` 在 Debug 编译时直接返回，不调用 `VerifyJwtAsync`、不采用服务端新 JWT、不执行授权字段同步，也不发布过期/设备撤销事件。SignalR 连接、设备状态上传、日志和审批等非授权功能继续运行。

同时，Urban 的 `LicenseExpiredEto` 与 `LicenseDeviceRevokedEto` 处理器在 Debug 下不得打开恢复窗口或关闭应用，作为防御性边界，避免测试或其他发布源绕过同步入口。

备选方案：仍调用线上检查但忽略失败。未采用，因为服务端响应仍可能修改本地授权状态，且 Debug 调试不应依赖线上授权服务可达。

### 4. Release 行为通过编译边界和测试双重锁定

旁路仅使用 `#if DEBUG` / `#if !DEBUG`，不使用 `appsettings.json`、User Secrets、环境变量或 HTTP 诊断 API 作为 Release 开关。Release 测试或构建检查必须证明严格路径仍引用本地 JWT 校验和运行时线上撤销处理。

### 5. 测试覆盖“任意错误 license”而非单一 machineCode 场景

测试至少覆盖：没有 LicenseInfo/文件、畸形 token、错误签名、过期 token、缺失 `proId`、machineCode 不匹配、数据库记录已过期，以及运行时服务端 `Expired` / `DeviceChanged`。Debug 断言主启动结果成功且不触发恢复；Release 断言现有失败行为不变。

## Risks / Trade-offs

- [Debug 构建可能被误用于真实现场] → 窗口标题或日志明确记录 Debug 授权旁路；发布流程只分发 Release。
- [Debug 使用固定项目身份向真实服务器写入测试数据] → 文档标明仅连接测试环境；不改变现有服务器认证，服务端仍可拒绝请求。
- [条件编译造成 Debug/Release 分支漂移] → 为两种编译配置分别增加自动化测试，并保持严格实现为默认非 Debug 路径。
- [只屏蔽当前 SignalR 发布源，未来新增授权事件源再次退出] → Debug 下事件处理器也 no-op，形成运行时防御层。
- [错误 JWT 被误认为有效并持久化] → Debug 上下文不解析、不采用、不保存错误 JWT；使用独立固定数据填充 LicenseInfo。

## Migration Plan

1. 增加 Debug 开发授权上下文及启动分支。
2. 增加运行时线上授权同步和授权事件处理器的 Debug 边界。
3. 增加 Debug/Release 测试并验证 `MaterialClient.Urban` 两种配置可编译。
4. 更新 pipeline 文档，明确 Debug 旁路及 Release 不受影响。

回滚时删除 Debug 条件分支和开发上下文即可；无数据库迁移和服务端部署要求。

## Open Questions

无。默认开发授权上下文采用现有 Urban pipeline 的固定演示项目数据，但 machineCode 使用本机实时值；实现时不得把 JWT 私钥或新的生产密钥写入代码或配置。
