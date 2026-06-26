# MaterialClient.Urban AccessCode 与 JWT 验权迁移

## Why

MaterialClient.Urban 现网授权模型与 UrbanManagement V2 / BasePlatform 委托签发契约不一致：`StaticLicenseChecker` 仍接受 `iss=UrbanManagement`，读取 `buildLicenseNo` / `fdBuildLicenseNo` claim；`LicenseInfo` 仍使用 `BuildLicenseNo`、`FdBuildLicenseNo`、`AuthToken` 等过时字段；且缺少 Urban 在线激活（`activate`）能力。UrbanManagement **尚未上线**，不存在需兼容的旧 JWT，可与服务端同期切换到 BasePlatform 统一签发。

## What Changes

### §A AccessCode 实体迁移

- **BREAKING**：`LicenseInfo.BuildLicenseNo` 重命名为 **`AccessCode`**
- **BREAKING**：**删除** `LicenseInfo.FdBuildLicenseNo`（无用字段，JWT 不再携带、Hub 不再同步、全代码引用清理）
- **BREAKING**：**删除** `LicenseInfo.AuthToken`（Urban 5001 不走 BasePlatform 直连激活）
- EF Core Migration 生成列变更
- Hub / 政府协议 **wire 名**仍为 `buildLicenseNo`，客户端映射到本地 **`AccessCode`**

### §B JWT 本地验权

- **BREAKING**：`StaticLicenseChecker` **仅**接受 `iss=BasePlatform`；拒绝 `UrbanManagement` 及其它 issuer
- JWT claim **`accessCode`** → 本地 `AccessCode`；**不读** `buildLicenseNo` / `fdBuildLicenseNo` claim
- 新增 **`machineCode`** claim 校验（须与本机一致）
- `LicenseCheckResult.BuildLicenseNo` 改名为 **`AccessCode`**
- `Jwt:PublicKey` 更新为 BasePlatform 签发公钥

### §C 在线激活与离线导入

- 新增 Refit **`POST /api/urban/auth/activate`**（`ProductCode=5001`、`Code`、`MachineCode`）
- 新增 `ILicenseService.ActivateAsync` 与 Urban 专用授权 UI
- **禁止** 5001 走 `VerifyAuthorizationCodeAsync` 直连 BasePlatform
- 启动从 `license.urban` bootstrap 成功时**回写** `LatestJwtToken`

### §D SignalR 对齐 Urban V2

- 保留 `VerifyJwtAsync`；`ServerJwt` 来自 BasePlatform
- `GetClientProjectLicenseInfo`：JSON `buildLicenseNo` → `AccessCode`；**移除** `fdBuildLicenseNo` 同步
- **可选**：订阅 `UpdateClientLicense` Hub 推送

### 首发约束（无灰度兼容）

- **不**配置 `Jwt:LegacyIssuers`
- **不**为 `iss=UrbanManagement` 或旧 claim 组合留分支

## Capabilities

### New Capabilities

- `materialclient-license-accesscode`：`LicenseInfo` 实体 `AccessCode` 迁移；删除 `FdBuildLicenseNo`、`AuthToken`；EF Migration 与引用清理
- `materialclient-urban-activation`：Urban 在线激活（`activate` API、Service、专用 UI）

### Modified Capabilities

- `jwt-offline-license`：`iss=BasePlatform`、`accessCode` claim、`machineCode` 校验；移除 `fdBuildLicenseNo` 读取
- `jwt-anti-tamper-sync`：Hub DTO 映射 `buildLicenseNo` → `AccessCode`；移除 `FdBuildLicenseNo` 同步；可选 `UpdateClientLicense`
- `urban-license-startup-gate`：bootstrap 成功回写 `LatestJwtToken`；持久化 `AccessCode`
- `materialclient-urban-desktop`：静态授权检查字段更新；Urban 激活 UI 入口

## Impact

| 范围 | 影响 |
|------|------|
| **子仓库** | `repos/MaterialClient`（`MaterialClient.Common`、`MaterialClient.Urban`） |
| **实体** | `LicenseInfo`、EF Migration |
| **服务** | `StaticLicenseChecker`、`LicenseService`、`DeviceStatusSignalRClient` |
| **API** | `IUrbanAuthApi` 新增 `activate` |
| **UI** | Urban 专用授权对话框（新建） |
| **配置** | `appsettings.json` → `Jwt:PublicKey`（BasePlatform 公钥） |
| **依赖** | UrbanManagement V2（`urban-jwt-delegation`、`jwt-anti-tamper` 已归档）；BasePlatform JWT 签发 |
| **不在范围** | BasePlatform 实现、MaterialClient 主程序（5000/5010） |

**发版顺序**（与 vault `05-联合发版说明` 一致）：

| 阶段 | 交付 | 阻塞 |
|------|------|------|
| P-Client-1 | AccessCode 实体 + `iss=BasePlatform` + machineCode | 可与 Urban 并行 |
| P-Client-2 | `activate` + UI | Urban JWT 委托已启用 |
| P-Client-3 | `UpdateClientLicense` handler | Urban Hub 推送就绪（可选） |

**参考文档**：vault `docs/2026-06-24-buildlicenseno-machinecode-confusion/06-MaterialClient.Urban迁移拟稿提案.md`；Urban V2 归档 `2026-06-25-urbanmanagement-migration-draft-proposal-v2`
