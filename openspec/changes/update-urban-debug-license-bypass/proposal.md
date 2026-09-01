## Why

MaterialClient.Urban 的 Debug 构建目前与 Release 一样强制执行本地 JWT、机器码和服务端授权状态检查，导致使用缺失、损坏、过期、签名错误或绑定其他机器的 license 时无法进入或持续使用程序，阻塞本地 UI、设备和诊断管线调试。需要建立仅在 Debug 编译产物中生效的完整授权旁路，同时保证 Release 授权边界不变。

## What Changes

- Debug 构建启动时不再因 `LicenseInfo` 已过期、license 文件缺失/损坏、JWT 签名或声明错误、JWT 过期、机器码不匹配、`ProId` 缺失而进入在线激活恢复或阻止主窗口与后台服务启动。
- Debug 构建使用稳定的开发授权上下文为依赖 `ProjectId`、`ProName`、`AccessCode`、`AuthEndTime` 的正常业务路径提供数据，不要求错误 license 本身可解析，也不信任其声明。
- Debug 构建运行期间跳过 SignalR `VerifyJwtAsync` 授权在线核验，并忽略服务端授权过期、设备变更撤销所触发的重新激活和应用退出；设备状态连接及其他非授权功能保持运行。
- Release 构建继续执行现有本地 JWT、机器码、有效期、在线反篡改、过期及设备撤销检查，不提供运行时配置开关绕过授权。
- 增加 Debug/Release 边界测试，覆盖缺失、畸形、过期、错误签名、机器码不匹配 license，以及服务端过期/撤销事件。

## Capabilities

### New Capabilities

<!-- None. -->

### Modified Capabilities

- `urban-license-startup-gate`: 将“所有构建配置都强制授权门禁”调整为 Release 强制、Debug 使用开发授权上下文并继续正常启动。
- `jwt-anti-tamper-sync`: Debug 构建不执行线上 JWT 核验，也不因服务端过期或设备撤销进入恢复/退出流程；Release 行为保持不变。

## Impact

- 受影响仓库：`repos/MaterialClient`。
- 主要代码：`MaterialClientUrbanModule` 启动授权编排、`StaticLicenseChecker` 或其 Debug 调用边界、`DeviceStatusSignalRClient` 在线授权同步、Urban 授权过期/设备撤销处理，以及相关测试。
- 安全边界：旁路必须由 `DEBUG` 编译符号决定；Release 二进制不得通过配置、环境变量或错误 license 启用旁路。
- 不改变 UrbanManagement 服务端授权协议、JWT 签发规则、数据库结构及公开 API。
