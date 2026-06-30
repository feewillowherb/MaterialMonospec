## Context

Urban V2（`urbanmanagement-migration-draft-proposal-v2`）已完成 JWT 委托（`GetLicenseFileAsync` → BasePlatform `license-file`）与 `GovProject.AccessCode` / `MachineCode` 字段迁移，但将 **`POST /api/urban/auth/activate` 在线激活代理标为非目标**，留待联合发版阶段。

当前状态（2026-06-26）：

```
MaterialClient.Urban --POST /api/urban/auth/activate--> [缺失] UrbanManagement --POST /api/auth/activate-urban--> BasePlatform ✅
```

- MaterialClient：`IUrbanAuthApi.ActivateAsync` 已指向 `/api/urban/auth/activate`
- BasePlatform：`AuthController.ActivateUrban` 验证 Redis 授权码、回写 `JC_ProductAuthority.MachineCode`、签发 `iss=BasePlatform` JWT
- Urban：`IBasePlatformAuthHttpClient` 仅有 `GetLicenseFileAsync`；无对外 `activate` 路由

约束：遵循 `repos/UrbanManagement/AGENTS.md`（AppService + DTO、命名 `record`、禁止 tuple、`[UnitOfWork]` 写操作、Refit 客户端独立文件）。

## Goals / Non-Goals

**Goals:**

- 暴露 **`POST /api/urban/auth/activate`**，与 MaterialClient Refit 契约一致
- 内部调用 BasePlatform **`POST /api/auth/activate-urban`**（Refit 方法 `ActivateAsync`）
- 激活成功后更新匹配 `proId` 的 **`GovProject.MachineCode`**（及响应中可映射的 `AccessCode` / 授权截止日期等）
- 失败时透传 BasePlatform 错误消息，不写入 `GovProject`
- 单元测试覆盖主路径

**Non-Goals:**

- 修改 BasePlatform / MaterialClient
- `license-file` REST 路径别名、`UpdateClientLicense` Hub、`FdBuildLicenseNo` 清理
- 联调执行（用户负责，见 vault 07 §7）

## Decisions

### 决策 1：对外路径固定为 `/api/urban/auth/activate`

**决策**：Urban 对外 HTTP 路径为 `POST /api/urban/auth/activate`（**不是** `activate-urban`）。

**理由**：与 EPIC、vault 06/07、`update-materialclient-urban-accesscode-jwt` 及 MaterialClient Refit 已对齐；`activate-urban` 仅保留为 Urban → BasePlatform 内部路径。

### 决策 2：Refit / Service 方法名为 `ActivateAsync`

**决策**：`IBasePlatformAuthHttpClient.ActivateAsync` 与 `IUrbanAuthActivateAppService.ActivateAsync`（或等价）统一命名；DTO 可保留 `ActivateUrbanRequest` / `ActivateUrbanResponseData` 类型名。

**理由**：与客户端 OpenSpec 及 vault 07 命名收口一致；与 BasePlatform 控制器动作名 `ActivateUrban` 区分。

### 决策 3：业务逻辑放在 AppService，非标准路由用 Controller 暴露

**决策**：

1. `UrbanAuthActivateAppService`（`UrbanManagement.Core`）承载：校验入参 → 调 BasePlatform → 更新 `GovProject` → 返回 DTO
2. `UrbanAuthController`（`UrbanManagement.App`）`[Route("api/urban/auth")]` + `[HttpPost("activate")]` 委托 AppService

**理由**：ABP 自动 API 默认前缀为 `/api/app/...`，无法直接生成 `/api/urban/auth/activate`；AGENTS 要求业务在 AppService，Controller 仅作薄路由层（`[RemoteService(IsEnabled = false)]` 或等价禁用自动暴露）。

**备选**：纯 AppService + `ConventionalControllers` 自定义路由——配置分散，不采用。

### 决策 4：BasePlatform 响应透传 + 本地 GovProject 按 proId 同步

**决策**：BasePlatform 成功 `data` 原样映射到 Urban 对外响应；随后用 `data.proId` 查询 `GovProject` 并更新：

- `MachineCode` ← 请求 `machineCode`
- `AccessCode` ← `data.accessCode`（若非空且与本地不同）
- `AuthEndTime` ← 解析 `data.authEndDate`（若可解析）

若本地无匹配 `GovProject`，**仍透传 JWT**（客户端可激活），记录 Warning 日志，不阻断 200。

**理由**：BasePlatform 已更新中心库 `MachineCode`；Urban 本地库用于 Hub / 离线签发，应尽力一致；现场可能尚未 Pull 到该项目。

### 决策 5：复用 `BasePlatformApiResponse<T>` 包装

**决策**：在 `IBasePlatformAuthHttpClient` 增加：

```csharp
[Post("/api/auth/activate-urban")]
Task<BasePlatformApiResponse<ActivateUrbanResponseData>> ActivateAsync(
    [Body] ActivateUrbanRequestDto request,
    CancellationToken cancellationToken = default);
```

新增 `ActivateUrbanResponseData`（`UrbanManagement.Core.Models`），字段：`JwtToken`、`ProId`、`ProName`、`AccessCode`、`AuthEndDate`（与 BasePlatform JSON camelCase 对齐）。

**理由**：与现有 `GetLicenseFileAsync` / `ListProjectsAsync` 响应模式一致。

### 决策 6：入参校验与产品码

**决策**：Urban 代理层校验 `productCode == 5001`、`code` 非空、`machineCode` 非空；其它产品码返回 400 及明确消息（与 BasePlatform 行为一致）。

**理由**：避免无效流量打到 BasePlatform；客户端已固定 5001。

### 决策 7：写操作事务

**决策**：`UrbanAuthActivateAppService.ActivateAsync` 使用 `[UnitOfWork]`。

**理由**：符合 ABP 与 Monospec AGENTS 事务边界要求。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 本地无 `GovProject` 导致 Hub 后续查不到项目 | 透传 JWT 仍允许客户端启动；日志提示执行 Pull；联调 checklist 覆盖 |
| BasePlatform Redis 授权码一次性消费，Urban 重试失败 | 不向客户端掩盖错误；记录 ProId/Code 哈希（非明文） |
| 路由与 ABP 自动 API 冲突 | Controller 显式 `[Route]`；集成测试验证 404 → 200 |
| `accessCode` 在 MaterialClient DTO 未声明 | 客户端从 JWT claims 取 `accessCode`；Urban 仍按 BasePlatform 透传完整 `data` |

## Migration Plan

| 步骤 | 工作 |
|------|------|
| 1 | 扩展 Refit 客户端 + DTO |
| 2 | 实现 `UrbanAuthActivateAppService` + Controller |
| 3 | 单元测试 |
| 4 | 更新 `BasePlatform-JWT-Endpoints.md` |
| 5 | 部署 Urban；用户执行 vault 07 §7 联调 |

**回滚**：移除 Controller / AppService 注册或 Feature Flag `UrbanAuth:EnableActivateProxy=false`（可选，默认 true）；客户端可继续使用离线 `license.urban`。

## Open Questions

1. **匿名访问**：`activate` 是否允许匿名（客户端未登录）？——**建议允许**（与 MaterialClient 无登录流一致）；实现时 `[AllowAnonymous]` 于 Controller action。
2. **GovProject 不存在**：是否强制 404？——**当前设计：仍 200 透传**（见决策 4）；若联调要求强制存在，可在 tasks 中追加校验。
