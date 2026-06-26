# MaterialClient.Urban AccessCode 与 JWT 验权迁移 — 设计文档

## Context

### 背景与现状

MaterialClient.Urban 授权链路仍基于 UrbanManagement 本地签发时代的设计：

| 组件 | 现网行为 | 目标行为 |
|------|----------|----------|
| `LicenseInfo` | `BuildLicenseNo`、`FdBuildLicenseNo`、`AuthToken` | `AccessCode`；**删除** `FdBuildLicenseNo`、`AuthToken` |
| `StaticLicenseChecker` | `iss=UrbanManagement`；读 `buildLicenseNo` / `fdBuildLicenseNo` | `iss=BasePlatform`；读 `accessCode`；校验 `machineCode` |
| 启动验权 | bootstrap 成功**不写回** `LatestJwtToken` | bootstrap 成功**写回** `LatestJwtToken` |
| 在线激活 | **无** Urban 专用激活 | `POST /api/urban/auth/activate` |
| SignalR 同步 | 同步 `FdBuildLicenseNo` | **不同步** `FdBuildLicenseNo`；`buildLicenseNo` → `AccessCode` |

UrbanManagement V2 已归档（`2026-06-25-urbanmanagement-migration-draft-proposal-v2`），JWT 委托 BasePlatform 签发。Urban **尚未上线**，客户端无需兼容 `iss=UrbanManagement` 或旧 claim 组合。

### 约束条件

- **子仓库**：实现仅在 `repos/MaterialClient`
- **架构**：ViewModel 不得直接使用 Repository；Service 写操作须 `[UnitOfWork]`
- **多值类型**：禁止 tuple；使用命名 `record`
- **Wire 名不变**：Hub JSON / 政府协议仍用 `buildLicenseNo`；域内属性为 `AccessCode`
- **无灰度**：不配置 `Jwt:LegacyIssuers`；拒绝非 BasePlatform issuer
- **不在范围**：BasePlatform、MaterialClient 主程序（5000/5010）

### 利益相关者

- **MaterialClient 团队**：实体迁移、验权、激活 UI、SignalR 适配
- **UrbanManagement 团队**：`activate` 代理、Hub JWT 来源（V2 已规格化）
- **联调**：与 Urban V2 + BasePlatform 同期首发

## Goals / Non-Goals

**Goals:**

1. `LicenseInfo.BuildLicenseNo` → `AccessCode`；**彻底删除** `FdBuildLicenseNo` 与 `AuthToken`
2. `StaticLicenseChecker` 仅接受 `iss=BasePlatform`；`accessCode` + `machineCode` 校验
3. 实现 `activate` 在线激活与 Urban 专用授权 UI
4. 启动 bootstrap 回写 `LatestJwtToken`；SignalR 字段映射对齐 Urban V2
5. 可选：`UpdateClientLicense` Hub 订阅

**Non-Goals:**

1. BasePlatform 表结构或 JWT 签发实现
2. MaterialClient 主程序（5000/5010）授权逻辑
3. 政府平台出站协议字段改名（仍 `buildLicenseNo`）
4. `iss=UrbanManagement` 或 `fdBuildLicenseNo` claim 兼容分支
5. REST `POST /api/urban/auth/verify`（启动仍纯本地 JWT）

## Decisions

### 决策 1：EF Core 列重命名 + 列删除

**决策**：`BuildLicenseNo` → `AccessCode` 使用 Migration `RenameColumn`；`FdBuildLicenseNo`、`AuthToken` 使用 `DropColumn`。

**理由**：SQLite 支持 RENAME COLUMN；删除无用列避免后续误用。`FdBuildLicenseNo` 在 BasePlatform JWT 与 Urban V2 Hub 中均已废弃，保留仅增加混淆。

**替代方案**：保留 `FdBuildLicenseNo` 可空列不写入 — **拒绝**：用户明确要求删除无用字段。

### 决策 2：JWT claim 仅读 `accessCode`

**决策**：`StaticLicenseChecker` 从 claim `accessCode` 提取接入码；若 JWT 仅含 `buildLicenseNo` / `fdBuildLicenseNo` 而无 `accessCode`，**拒绝**。

**理由**：与 BasePlatform 03 提案及 Urban V2 一致；避免双轨 claim 语义。

### 决策 3：Issuer 硬切换，无 LegacyIssuers

**决策**：`TokenValidationParameters.ValidIssuer = "BasePlatform"`；不引入 `Jwt:LegacyIssuers` 配置。

**理由**：Urban 未上线，无生产旧 token；减少配置与测试矩阵。

### 决策 4：Hub wire 名与域内名分离

**决策**：`JwtAntiTamperResult.BuildLicenseNo`、`ClientProjectLicenseInfoDto.buildLicenseNo` 等 DTO **保留 JSON 属性名**；映射层写入 `LicenseInfo.AccessCode`。

**理由**：与 Urban V2、政府协议一致；域内语义清晰。

### 决策 5：Urban 激活走 Urban 代理，禁止直连 BasePlatform

**决策**：5001 产品通过 `IUrbanAuthApi.ActivateAsync` → Urban `activate`；**禁止** `VerifyAuthorizationCodeAsync` 直连 BasePlatform。

**理由**：与联合发版架构一致；Urban 作为 BFF 统一入口。

### 决策 6：`UpdateClientLicense` 为可选阶段

**决策**：P-Client-3 实现 Hub handler；P-Client-1/2 不阻塞发版。

**理由**：Urban Hub 推送能力可晚于核心验权上线。

### 决策 7：激活 UI 为 Urban 专用新窗口

**决策**：新建 Urban 授权对话框（输入接入码 + 机器码展示）；不复用主程序 `AuthCodeWindow`。

**理由**：Urban 无登录流；激活参数与 5000 不同（无 ProId）。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| EF Migration 在已有现场库执行失败 | 开发环境充分测试；回滚上一 Migration |
| BasePlatform 公钥配置错误导致全体拒签 | 联调 checklist 验证 `Jwt:PublicKey`；启动日志明确报错 |
| Urban `activate` 未就绪阻塞 P-Client-2 | P-Client-1 可独立交付；离线 `license.urban` 仍可用 |
| 遗漏 `FdBuildLicenseNo` 引用导致编译错误或运行时空引用 | 全仓 grep 清理；spec 与测试清单覆盖 |
| `machineCode` 与本机不一致导致激活后无法启动 | UI 展示本机 machineCode；激活请求自动填充 |

## Migration Plan

### 部署步骤

| 阶段 | 工作 | 预估 |
|------|------|------|
| 1 | `LicenseInfo` + Migration；全引用 `AccessCode`；删除 `FdBuildLicenseNo` / `AuthToken` | 1d |
| 2 | `StaticLicenseChecker`（iss / claims / machineCode） | 0.5d |
| 3 | 启动回写 `LatestJwtToken` | 0.25d |
| 4 | `activate` + Service + UI | 1.5d |
| 5 | `DeviceStatusSignalRClient` + DTO 映射 | 0.5d |
| 6 | Urban 上传服务 `AccessCode` | 0.25d |
| 7 | 与 Urban V2 + BasePlatform 联调 | 1d |

### 回滚

| 故障 | 回滚 |
|------|------|
| Migration | EF 回滚上一版本 |
| JWT/激活逻辑 | 回退客户端版本；联调环境重新下发新 JWT / `.urban` |
| 无旧 token 义务 | **不**回滚到 `iss=UrbanManagement` 验签 |

### 涉及文件（主要）

| 路径 | 改动 |
|------|------|
| `MaterialClient.Common/Entities/LicenseInfo.cs` | `AccessCode`；删 `AuthToken` / `FdBuildLicenseNo` |
| `MaterialClient.Common/Migrations/*` | 新 Migration |
| `MaterialClient.Common/Services/StaticLicenseChecker.cs` | iss、claims、machineCode |
| `MaterialClient.Common/Services/IStaticLicenseChecker.cs` | `LicenseCheckResult.AccessCode` |
| `MaterialClient.Common/Services/Authentication/LicenseService.cs` | `ActivateAsync`；Store/Sync 签名 |
| `MaterialClient.Common/Services/DeviceStatusSignalRClient.cs` | DTO 映射；可选 `UpdateClientLicense` |
| `MaterialClient.Urban/MaterialClientUrbanModule.cs` | 启动写 `LatestJwtToken` |
| `MaterialClient.Common/Api/IUrbanAuthApi.cs` | `activate` |
| `MaterialClient.Urban/Services/UrbanServerUploadService.cs` | `AccessCode` |
| Urban 授权 UI（新） | 在线激活 |
| `appsettings.json` | `Jwt:PublicKey` |

## Open Questions

1. **激活 UI 入口位置**：未授权时是否除对话框外增加「输入授权码」入口，还是仅通过设置/独立菜单触发？（建议：未授权对话框增加「在线激活」按钮。）
2. **`UpdateClientLicense` 优先级**：Urban Hub 推送是否在首发版本必须上线？（当前标为 P-Client-3 可选。）
