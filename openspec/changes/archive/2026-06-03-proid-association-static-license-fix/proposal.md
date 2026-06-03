## Why

MaterialClient.Urban 的 `StaticLicenseChecker` 当前是空实现（始终返回成功但不携带任何授权数据），导致 ProId、ProName、BuildLicenseNo、FdBuildLicenseNo 在整个数据管线中为空。测试流程无法正常进行，因为称重记录上传到 UrbanManagement 服务端时缺少项目关联信息。当前阶段不需要实现真实的授权加载逻辑，只需硬编码固定值打通测试链路。

## What Changes

- **MaterialClient.Urban 硬编码测试授权数据**: 在 `StaticLicenseChecker` 中返回包含固定 ProId、ProName、BuildLicenseNo、FdBuildLicenseNo 以及硬编码授权过期时间（AuthEndTime）的授权信息，写入 `LicenseInfo` 实体持久化到本地数据库。
- **扩展 `LicenseInfo` 实体**: 新增 `ProName`、`BuildLicenseNo`、`FdBuildLicenseNo` 字段，使项目关联信息可在本地持久化。
- **扩展 `LicenseCheckResult`**: 携带解析后的授权数据（ProId、ProName、BuildLicenseNo、FdBuildLicenseNo），供启动流程使用。
- **修复称重记录上传数据流**: `UrbanServerUploadService` 从 `LicenseInfo` 读取项目关联信息填充到 `UrbanWeighingRecordSubmitDto`，替代当前的 null 硬编码。
- **补全 `UrbanWeighingRecordSubmitDto`**: 新增缺失的 `FdBuildLicenseNo` 字段。
- **设备管理标识从 ClientId 改为 ProId/ProName**: `DeviceStatusMessage` 新增 `ProId` (string) 和 `ProName` (string) 字段。服务端以 ProId 作为设备管理的主键（聚合、缓存、筛选的标识），ProName 作为面向用户的展示名称。替代原有 ClientId 维度。

## Capabilities

### New Capabilities

- `static-license-test-data`: MaterialClient.Urban 硬编码测试授权数据的能力，包括固定的 ProId/ProName/BuildLicenseNo/FdBuildLicenseNo 以及硬编码的授权过期时间（AuthEndTime），以及将数据写入 LicenseInfo 的流程。
- `proid-data-pipeline`: ProId 项目关联信息从本地 LicenseInfo → 称重记录 DTO → 服务端的完整数据流，确保称重记录上传时携带正确的项目关联数据。
- `device-status-proname-association`: 设备状态消息新增 ProId（主键）和 ProName（展示名称），服务端以 ProId 为聚合和缓存主键，管理页面以 ProName 展示，替代原有 ClientId 维度。

### Modified Capabilities

- `materialclient-urban-desktop`: 静态授权检查需求变更 — 从"仅记录日志"变为"解析授权数据（含过期时间）并写入 LicenseInfo 持久化"。
- `urban-weighing-api`: 称重记录提交 DTO 需求变更 — 新增 FdBuildLicenseNo 字段，且 ProId/ProName/BuildLicenseNo 不再为 null。
- `signalr-device-status-upload`: 设备状态消息需求变更 — DeviceStatusMessage 新增 ProId（主键）和 ProName（展示名称）字段，客户端从 LicenseInfo 读取填充，服务端按 ProId 聚合，页面按 ProName 展示。

## Impact

### Code Change Map

| File Path | Repo | Change Type | Change Reason | Impact Scope |
|-----------|------|-------------|---------------|--------------|
| `MaterialClient.Common/Entities/LicenseInfo.cs` | MaterialClient | Modify | 新增 ProName, BuildLicenseNo, FdBuildLicenseNo 字段 | 实体结构变更，需 EF 迁移 |
| `MaterialClient.Common/Services/IStaticLicenseChecker.cs` | MaterialClient | Modify | `LicenseCheckResult` 携带授权数据 | 接口返回类型扩展 |
| `MaterialClient.Common/Services/StaticLicenseChecker.cs` | MaterialClient | Modify | 硬编码返回固定测试授权数据 | 核心逻辑变更 |
| `MaterialClient.Urban/MaterialClientUrbanModule.cs` | MaterialClient | Modify | 启动时将授权数据写入 LicenseInfo | 启动流程变更 |
| `MaterialClient.Urban/Dtos/UrbanWeighingRecordSubmitDto.cs` | MaterialClient | Modify | 新增 FdBuildLicenseNo 字段 | DTO 结构扩展 |
| `MaterialClient.Urban/Services/UrbanServerUploadService.cs` | MaterialClient | Modify | 从 LicenseInfo 读取项目信息填充 DTO | 数据流修复 |
| `MaterialClient.Common/Api/Dtos/LicenseInfoDto.cs` | MaterialClient | Modify | 新增 ProName, BuildLicenseNo, FdBuildLicenseNo | DTO 扩展 |
| `UrbanManagement.Core/Models/DeviceStatusMessage.cs` | UrbanManagement | Modify | 新增 ProId + ProName 字段，ProId 作为主键，ProName 作为展示名称 | 消息协议变更 |
| `UrbanManagement.Core/Services/DeviceStatusService.cs` | UrbanManagement | Modify | 缓存和广播逻辑以 ProId 为主键 | 服务逻辑变更 |
| `UrbanManagement.Core/Models/DeviceStatusQueryDto.cs` | UrbanManagement | Modify | 新增 ProId + ProName 字段，ProId 用于聚合，ProName 用于展示 | 查询 DTO 变更 |
| `UrbanManagement.Core/Models/DeviceStatusListRequestDto.cs` | UrbanManagement | Modify | 筛选字段从 ClientId 改为 ProId | 请求 DTO 变更 |
| `UrbanManagement.Core/Services/DeviceStatusAppService.cs` | UrbanManagement | Modify | 聚合逻辑从 ClientId 切换到 ProId | 查询逻辑变更 |
| `UrbanManagement.App/Views/DeviceManagement/Index.cshtml` | UrbanManagement | Modify | 管理页面展示和筛选从 ClientId 改为 ProName | UI 变更 |
| `MaterialClient.Common/Services/DeviceStatusEventHandler.cs` | MaterialClient | Modify | 事件处理器从 LicenseInfo 读取 ProName 填充到 DeviceStatusMessage | 客户端逻辑变更 |
| `MaterialClient.Common/Services/DeviceStatusSignalRClient.cs` | MaterialClient | Modify | UploadStatus 发送包含 ProName 的消息 | 客户端发送逻辑变更 |

### Data Flow

```mermaid
flowchart TD
    subgraph "MaterialClient.Urban (Client)"
        A[StaticLicenseChecker<br/>硬编码测试数据] -->|LicenseCheckResult| B[MaterialClientUrbanModule<br/>OnApplicationInitialization]
        B -->|Write| C[(LicenseInfo<br/>ProId + ProName +<br/>BuildLicenseNo + FdBuildLicenseNo)]
        D[称重完成] --> E[UrbanServerUploadService]
        C -->|Read ProId/ProName/BuildLicenseNo/FdBuildLicenseNo| E
        E -->|填充 DTO| F[UrbanWeighingRecordSubmitDto]
        G[设备状态变化] --> H[DeviceStatusEventHandler]
        C -->|Read ProId + ProName| H
        H -->|ProId + ProName + DeviceType + Status| I[DeviceStatusSignalRClient]
    end

    subgraph "UrbanManagement (Server)"
        F -->|HTTP POST| J[UrbanWeighingRecordAppService]
        J -->|Store| K[(UrbanWeighingRecord<br/>ProId + ProName +<br/>BuildLicenseNo)]
        I -->|SignalR| L[DeviceStatusHub]
        L -->|ProId 主键 + ProName 展示| M[DeviceStatusService]
        M -->|按 ProId 聚合| N[设备管理页面<br/>展示 ProName]
    end
    end

    style A fill:#f9f,stroke:#333
    style C fill:#bbf,stroke:#333
    style K fill:#bfb,stroke:#333
```

### Cross-Repo Impact

- **MaterialClient → UrbanManagement API 契约**: `UrbanWeighingRecordSubmitDto` 新增 `fdBuildLicenseNo` 字段，服务端需同步接收（UrbanWeighingRecord 实体已有 BuildLicenseNo，需确认是否新增 FdBuildLicenseNo）。
- **数据库迁移**: MaterialClient 的 `LicenseInfo` 表需新增 3 个字段（ProName, BuildLicenseNo, FdBuildLicenseNo）。
- **DeviceStatusHub**: `DeviceStatusMessage` 新增 `ProId`（主键）和 `ProName`（展示名称）字段。服务端以 ProId 为聚合和缓存主键，设备管理页面以 ProName 展示。客户端从 LicenseInfo 读取 ProId/ProName 填充到设备状态消息中。
