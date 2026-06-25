# UrbanManagement 迁移提案 V2

## Why

当前 UrbanManagement 服务端存在两个关键的技术债务：(1) `GovProject.BuildLicenseNo` 字段语义不清晰，应为 `AccessCode`（城管接入码），且缺少 `MachineCode` 和 `AuthToken` 字段；(2) JWT 授权令牌由 UrbanManagement 本地签发，存在密钥管理风险且无法与 BasePlatform 授权体系统一。

**现状更新**：BasePlatform PublicApi 已完成相关基础设施建设（见 BasePlatform 仓库的 `2026-06-24-add-access-token-support` 和 `2025-06-25-baseplatform-jwt` 归档提案），包括：
- `JC_ProductAuthority` 表已新增 `AccessCode` 列，与 `MachineCode` 分列存储
- PublicApi `/Api/ProjectCatalog/ListProjects` 已返回 `accessCode`、`machineCode`、`fdBuildLicenseNo` 字段
- PublicApi `/api/auth/license-file` 已支持 GET 方法，可签发 ProductCode=5001 JWT
- PublicApi `/api/auth/activate-urban` 已实现在线激活功能

此迁移旨在利用 BasePlatform 已实现的能力，优化 UrbanManagement 数据语义并下线本地 JWT 签发，委托 BasePlatform 统一管理。

## Execution Status

**当前状态：✅ 可以执行**

### 前置依赖检查

- ✅ **BasePlatform PublicApi AccessCode/MachineCode 分列**：已完成（`2026-06-24-add-access-token-support` 提案）
- ✅ **BasePlatform PublicApi JWT 签发基础设施**：已完成（`2025-06-25-baseplatform-jwt` 提案）
- ✅ **BasePlatform ProjectCatalog API**：已返回 `accessCode`、`machineCode` 字段
- ✅ **BasePlatform Auth License File API**：已支持 GET 方法，可签发 ProductCode=5001 JWT
- ✅ **BasePlatform Activate Urban API**：已实现在线激活功能

### UrbanManagement 执行准备

- ✅ **提案规格文档**：已完成（proposal.md、design.md、tasks.md）
- ✅ **API 对接规格**：已明确 BasePlatform API 端点和响应格式
- ⏳ **代码迁移**：待执行（见 tasks.md 任务清单）
- ⏳ **EF 迁移脚本**：待生成和测试
- ⏳ **集成测试**：待编写和验证

### 执行建议

1. **可立即开始**：所有 BasePlatform 依赖已满足，可按 tasks.md 任务清单开始执行
2. **建议顺序**：
   - 第 1 阶段：EF 实体与数据库迁移（tasks.md §1）
   - 第 2 阶段：拉取同步逻辑更新（tasks.md §2）
   - 第 3 阶段：JWT 委托逻辑实现（tasks.md §3）
   - 第 4 阶段：Feature Flag 与配置（tasks.md §4）
3. **灰度策略**：使用 Feature Flag 控制迁移启用，确保可快速回滚

### 风险提示

- ⚠️ **数据库迁移**：需在生产环境执行前充分测试 EF 迁移脚本
- ⚠️ **BasePlatform API 可用性**：需确保 BasePlatform PublicApi 在 UrbanManagement 迁移期间保持可用
- ⚠️ **客户端兼容性**：MaterialClient 的 `LicenseInfo.BuildLicenseNo` 属性暂不重命名，保持兼容

## What Changes

### §A AccessCode 数据语义迁移

- **BREAKING**：`GovProject.BuildLicenseNo` 字段重命名为 `AccessCode`（EF 迁移）
- 新增 `GovProject.MachineCode` 和 `GovProject.AuthToken` 可空字符串字段
- 更新 `GovProjectPullManager` 映射：从 BasePlatform PublicApi 的 `accessCode`、`machineCode` 字段拉取（不再读 `buildLicenseNo`）
  - BasePlatform API 端点：`GET /Api/ProjectCatalog/ListProjects?pageIndex={}&pageSize={}`
  - 响应字段：`ProId`, `ProName`, `ProductCode`, `ProAddress`, `ShigongUnitName`, `AccessCode`, `MachineCode`, `FdBuildLicenseNo`, `AuthEndTime`
  - 筛选条件：`ProductCode = 5001`（已在 BasePlatform 实现）
- 政府平台出站协议保持 `payload.buildLicenseNo = govProject.AccessCode`（协议名不变）
- 实施脏数据修复脚本：以 BasePlatform 拉取结果覆盖本地 `AccessCode`

### §B JWT 签发下线与代理

- **BREAKING**：删除 `UrbanLicenseGenerator` 本地 JWT 签发逻辑（移除 RSA 私钥依赖）
- 新增代理 API：`GET /api/urban/auth/license-file` → 调用 BasePlatform PublicApi `/api/auth/license-file` 透传 JWT
  - BasePlatform API 端点：`GET /api/auth/license-file?productCode={}&machineCode={}&proId={}&authEndDate={}&format={}`
  - 请求参数：
    - `productCode`: 5001（固定值，Urban 产品）
    - `machineCode`: 机器码（从 GovProject.MachineCode 获取）
    - `proId`: 项目 ID（Guid）
    - `authEndDate`: 授权截止日期
    - `format`: 返回格式（`json` 或 `stream`，默认 `json`）
  - 响应格式：
    ```json
    {
      "success": true,
      "msg": "签发成功",
      "data": {
        "jwtToken": "eyJhbGc...",
        "proId": "...",
        "proName": "...",
        "authEndDate": "2026-12-31"
      }
    }
    ```
- 新增代理 API（可选）：`POST /api/urban/auth/activate-urban` → 调用 BasePlatform PublicApi `/api/auth/activate-urban` 代理在线激活
  - BasePlatform API 端点：`POST /api/auth/activate-urban`
  - 请求体：`{productCode, code, machineCode}`
  - 功能：验证 Redis 授权码、回写 MachineCode、签发 JWT
- 更新 `DeviceStatusHub.GetClientProjectLicenseInfo` 和 SignalR 推送：JWT 由 BasePlatform 签发，Urban 仅转发
- 移除 `appsettings.json` 中 `Jwt:PrivateKey` 配置
- 保留 Feature Flag（`UseBasePlatformJwtIssuer`）支持灰度回退

### 影响范围

- **UrbanManagement**（`repos/UrbanManagement/`）：
  - `UrbanManagement.Core/Entities/GovProject.cs`：字段重命名+新增
  - `UrbanManagement.Core/Services/GovProjectPullManager.cs`：映射字段调整
  - `UrbanManagement.Core/Services/UrbanLicenseGenerator.cs`：删除或标记 `[Obsolete]`
  - `UrbanManagement.Core/Services/GovProjectLicenseAppService.cs`：改为代理调用 BasePlatform
  - `UrbanManagement.Core/Services/JwtAntiTamperService.cs`：验签后转发 BasePlatform JWT
  - `UrbanManagement.Core/Hubs/DeviceStatusHub.cs`：推送 JWT 来自 BasePlatform
  - `UrbanManagement.Core/Api/IBasePlatformProjectHttpClient.cs`：`ProjectCatalogItemResponse` 新增 `AccessCode`、`MachineCode` 字段
  - `UrbanManagement.Core/EntityFrameworkCore/`：EF 迁移脚本

- **BasePlatform PublicApi**（已实现，本提案仅对接）：
  - `/Api/ProjectCatalog/ListProjects`：已返回 `accessCode`、`machineCode`、`fdBuildLicenseNo` 字段（见 BasePlatform `2026-06-24-add-access-token-support` 提案）
  - `/api/auth/license-file`：已支持 GET 方法，可签发 ProductCode=5001 JWT（见 BasePlatform `2025-06-25-baseplatform-jwt` 提案）
  - `/api/auth/activate-urban`：已实现在线激活功能（见 BasePlatform `2025-06-25-baseplatform-jwt` 提案）

- **MaterialClient**（`repos/MaterialClient/`）：
  - `MaterialClient.Common/Entities/LicenseInfo.cs`：字段 `BuildLicenseNo` 保持不变（客户端属性重命名可后续单独立项）
  - 客户端以本地 JWT 验签为准，无需 verify API 门禁

## Capabilities

### New Capabilities

- `urban-accesscode-migration`：`GovProject.BuildLicenseNo` → `AccessCode` 字段重命名与数据迁移
- `urban-jwt-delegation`：JWT 签发委托 BasePlatform，本地下线 `UrbanLicenseGenerator`

### Modified Capabilities

- `gov-project-baseplatform-pull-sync`：拉取映射字段从 `buildLicenseNo` 改为 `accessCode`、`machineCode`
- `jwt-anti-tamper`：验签后不再使用 `UrbanLicenseGenerator` 重新签发，直接返回 BasePlatform JWT

## Code Change Table

| 仓库 | 文件路径 | 变更类型 | 变更原因 | 影响范围 |
|------|---------|---------|---------|---------|
| **UrbanManagement** | `src/UrbanManagement.Core/Entities/GovProject.cs` | **BREAKING** 字段重命名+新增 | 数据语义优化 | EF 实体、数据库迁移 |
| **UrbanManagement** | `src/UrbanManagement.Core/Services/GovProjectPullManager.cs` | 修改映射逻辑 | 对接 BasePlatform 新字段 | 拉取同步服务 |
| **UrbanManagement** | `src/UrbanManagement.Core/Services/UrbanLicenseGenerator.cs` | **BREAKING** 删除或标记 Obsolete | 下线本地 JWT 签发 | 授权生成服务 |
| **UrbanManagement** | `src/UrbanManagement.Core/Services/GovProjectLicenseAppService.cs` | 改为代理调用 | 委托 BasePlatform 签发 | 授权文件下载 API |
| **UrbanManagement** | `src/UrbanManagement.Core/Services/JwtAntiTamperService.cs` | 修改验签后行为 | 转发 BasePlatform JWT | JWT 防篡改服务 |
| **UrbanManagement** | `src/UrbanManagement.Core/Hubs/DeviceStatusHub.cs` | SignalR 推送 JWT 来源 | 推送 BasePlatform JWT | 客户端 JWT 同步 |
| **UrbanManagement** | `src/UrbanManagement.Core/Api/IBasePlatformProjectHttpClient.cs` | 新增响应字段 | 接收 `AccessCode`、`MachineCode` | BasePlatform HTTP 客户端 |
| **UrbanManagement** | `src/UrbanManagement.Core/EntityFrameworkCore/` | 新增 EF 迁移 | 数据库字段变更 | SQLite 数据库结构 |
| **BasePlatform** | `PublicApi/ProjectCatalogController.cs` | 已实现 | 已返回 `accessCode`、`machineCode`、`fdBuildLicenseNo` | 目录 API（已实现，见 `2026-06-24-add-access-token-support` 提案） |
| **BasePlatform** | `PublicApi/AuthController.cs` | 已实现 | 已支持 GET `/api/auth/license-file`，ProductCode=5001 | 授权 API（已实现，见 `2025-06-25-baseplatform-jwt` 提案） |
| **BasePlatform** | `PublicApi/AuthController.cs` | 已实现 | 已支持 POST `/api/auth/activate-urban` | 在线激活 API（已实现，见 `2025-06-25-baseplatform-jwt` 提案） |

## Interaction Flow

```mermaid
sequenceDiagram
    participant BP as BasePlatform
    participant UM as UrbanManagement
    participant Client as MaterialClient.Urban

    Note over UM,BP: §A AccessCode 拉取流程
    UM->>BP: GET /Api/ProjectCatalog/ListProjects
    BP-->>UM: {accessCode, machineCode, ...}
    UM->>UM: GovProjectPullManager 映射字段
    UM->>UM: EF 更新 GovProject.AccessCode/MachineCode

    Note over UM,BP: §B JWT 代理流程
    Client->>UM: GET /api/urban/auth/license-file
    UM->>BP: GET /api/auth/license-file (ProductCode=5001)
    BP-->>UM: JWT token (BasePlatform 签发)
    UM-->>Client: license.urban 文件

    Note over UM,Client: SignalR 推送流程
    UM->>Client: Hub.UpdateClientLicense (JwtToken 来自 BasePlatform)
    Client->>Client: 本地 JWT 验签
```

## Migration Strategy

### §A AccessCode 迁移步骤

1. **EF 迁移**：生成 `BuildLicenseNo → AccessCode` 重命名脚本 + 新增 `MachineCode`、`AuthToken` 列
2. **Pull Worker 更新**：`GovProjectPullManager.ApplyRemoteFieldsIfChanged` 改为映射 `AccessCode`、`MachineCode`
3. **脏数据修复**：执行 SQL 脚本以 BasePlatform 拉取结果覆盖本地 `AccessCode`（可后台任务执行）
4. **依赖条件**：
   - ✅ BasePlatform PublicApi 已输出 `accessCode`、`machineCode` 字段（`2026-06-24-add-access-token-support` 提案已完成）
   - ✅ BasePlatform 已实现 AccessCode 与 MachineCode 分列存储（`JC_ProductAuthority` 表）

### §B JWT 下线步骤

1. **BasePlatform HTTP 客户端**：新增 `IBasePlatformAuthHttpClient.GetLicenseFileAsync` 调用
2. **代理 API**：`GovProjectLicenseAppService.GenerateAsync` 改为调用 BasePlatform 并透传 JWT
3. **SignalR 更新**：`DeviceStatusHub` 推送的 `JwtToken` 字段来自 BasePlatform 签发
4. **Feature Flag**：`UseBasePlatformJwtIssuer=true` 启用新路径，灰度验证后移除旧代码
5. **依赖条件**：
   - ✅ BasePlatform `/api/auth/license-file` 已支持 GET 方法，可签发 ProductCode=5001 JWT（`2025-06-25-baseplatform-jwt` 提案已完成）
   - ✅ BasePlatform `/api/auth/activate-urban` 已实现在线激活功能（`2025-06-25-baseplatform-jwt` 提案已完成）
   - ✅ BasePlatform 已有 `ILicenseFileAppService` 签发服务和 `BasePlatformJwtTokenGenerator` 签发器

### Rollback 策略

- **§A**：保留 `BuildLicenseNo` 列只读别名一版（EF 兼容属性），便于数据回滚
- **§B**：`UseBasePlatformJwtIssuer=false` 恢复 Urban 本地签发（P4 验证完成前）

## Non-Goals

- **不包含**：BasePlatform 表结构变更、授权后台 UI（见 02、03 提案）
- **不包含**：客户端 `LicenseInfo.BuildLicenseNo` 属性重命名（可后续单独立项）
- **不包含**：政府平台协议字段改名（仍叫 `buildLicenseNo`）
- **不包含**：`POST /api/urban/auth/verify` 在线激活代理（见 05-联合发版说明）
