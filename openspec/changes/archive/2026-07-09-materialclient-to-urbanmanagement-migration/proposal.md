## Why

需要新增 MaterialClient.Recycle 客户端（ProductCode=5020, WeighingMode=301），其称重、车牌识别、图片保存等前端功能与 SolidWaste（5010）完全一致，但数据上报链路必须替换：不走 `SynchronizationOrderAsync`（内部 MaterialPlatform），改用「杭州市资源化利用厂数据接入接口 V1.0」§2.2 端点，直连外部第三方平台，要求 HMAC-SHA256 签名认证、Base64 图片内嵌、重量单位由 kg 转吨、JSON Array 批量提交。现在启动是因为接口文档已就位、SolidWaste 同步链路已完整定位，且运营侧有明确的交付时间要求。

## What Changes

- 新增 `WeighingMode.Recycle = 301` 枚举成员（MaterialClient.Common）
- 新增 `ProductCode.Recycle = 5020` 枚举成员（MaterialClient.Common）
- 新增 `MaterialClient.Recycle` ABP 模块项目，遵循 MaterialClient.Urban 扩展模式
- 新增 `IRecycleDataApi` Refit 接口，对接 §2.2 端点 `POST /dataCenter/resourcePlace/productTransportRecord/v1/addBatch`
- 新增 `RecycleTransportRecord` 请求 DTO（17 个字段，含必填：dataNo、pointNumber、carNo、productName、netWeight、outTime、outPhotos）
- 新增 `RecycleHmacSignService`，实现 HMAC-SHA256 签名（4 个自定义 Header）
- 新增 `RecycleDataSyncService` 核心同步服务：查询未同步记录 → 读取附件 Base64 编码（不带标识头，逗号分隔）→ 字段映射（含 kg→吨 ÷1000）→ 构造签名 → HTTP POST → 解析响应（code==200 成功）
- 新增 `RecycleSyncOptions` 配置模型（accessKey、secretKey、pointNumber、productName、API URL 等）
- 扩展 `ISettingsService` 的 `GetProductCodeAsync` / `SaveDefaultWeighingModeAsync`，增加 Recycle ↔ ProductCode.Recycle 映射
- 修改 `MaterialClient.sln` 添加 Recycle 项目引用
- 配置 `appsettings.json` 添加 RecycleSync 配置段 + ProductCode=5020 + WeighingMode=301
- BasePlatform 侧注册 ProductCode 5020（授权页显示 AccessCode + MachineCode，沿用 5010 非 JWT 模式）
- Recycle 客户端授权沿用 SolidWaste 的 `SendAuthLicense` / `DownloadAuth`（不使用 JWT）

## Capabilities

### New Capabilities
- `recycle-abp-module`: MaterialClient.Recycle ABP 模块定义，包括模块依赖（MaterialClientCommonModule）、启动配置、DI 注册、RecycleSync 配置绑定
- `recycle-data-sync`: Recycle 数据上报同步管线，包括未同步记录查询、WeighingRecord → RecycleTransportRecord 字段映射（kg→吨、时间格式化、DataNo 生成）、附件 Base64 编码（不带标识头、逗号分隔）、失败重试与放弃策略（MaxFailCount）
- `recycle-hmac-authentication`: §2.2 接口的 HMAC-SHA256 签名认证，包括签名字符串构造（`{METHOD}\n{query}\n{accessKey}\n{datetime}\n`）、4 个自定义 Header（X-AKZTJG-HMAC-SIGNATURE / ALGORITHM / ACCESS-KEY / DATE-TIME）、GMT+8 时间戳格式
- `recycle-transport-record-dto`: RecycleTransportRecord 请求 DTO 定义（17 个字段）与 RecycleApiResponse 响应 DTO 定义，以及 Refit 接口 IRecycleDataApi

### Modified Capabilities
- `system-configuration`: `GetProductCodeAsync` 需新增 WeighingMode.Recycle → ProductCode.Recycle 映射；`SaveDefaultWeighingModeAsync` 需新增 ProductCode.Recycle → WeighingMode.Recycle 映射
- `detail-viewmodel-hierarchy`: WeighingMode 新增 Recycle=301 分支，Recycle 模式复用 SolidWasteWeighingDetailViewModel（功能一致）

## Impact

### 变更地图

| 模块 | 文件 | 操作 | 原因 |
|------|------|------|------|
| MaterialClient.Common | `Entities/Enums/WeighingMode.cs` | 修改 | 新增 `Recycle = 301` |
| MaterialClient.Common | `Entities/Enums/ProductCode.cs` | 修改 | 新增 `Recycle = 5020` |
| MaterialClient.Common | `Services/ISettingsService` 实现 | 修改 | 扩展 ProductCode/WeighingMode 双向映射 |
| MaterialClient.Recycle | `MaterialClientRecycleModule.cs` | **新增** | ABP 模块注册入口 |
| MaterialClient.Recycle | `Api/IRecycleDataApi.cs` | **新增** | Refit 接口对接 §2.2 |
| MaterialClient.Recycle | `Models/RecycleTransportRecord.cs` | **新增** | 请求 DTO（17 字段） |
| MaterialClient.Recycle | `Models/RecycleApiResponse.cs` | **新增** | 响应 DTO |
| MaterialClient.Recycle | `Models/RecycleSyncOptions.cs` | **新增** | 配置模型 |
| MaterialClient.Recycle | `Services/RecycleHmacSignService.cs` | **新增** | HMAC-SHA256 签名 |
| MaterialClient.Recycle | `Services/RecycleDataSyncService.cs` | **新增** | 核心同步服务 |
| MaterialClient.Recycle | `Services/RecycleWeightMapper.cs` | **新增** | 字段映射（kg→吨） |
| MaterialClient | `appsettings.json` | 修改 | 添加 RecycleSync 配置段 |
| MaterialClient | `Program.cs` / 启动配置 | 修改 | ProductCode 5020 路由到 Recycle 模块 |
| MaterialClient | `MaterialClient.sln` | 修改 | 添加 Recycle 项目引用 |
| BasePlatform | ProductCode 配置/枚举 | 修改 | 注册 5020 |
| BasePlatform | 授权管理 UI | 修改 | 5020 显示 AccessCode + MachineCode |
| UrbanManagement | — | **无改动** | Recycle 直连外部接口，不经过 UrbanManagement |

### 数据上报交互流程

```mermaid
flowchart TD
    A[地磅串口 → 重量数据] --> B[稳定性检测 3000ms]
    C[海康威视 LRP → 车牌识别] --> D[图片保存 AttachmentFile]
    B --> E[创建 WeighingRecord]
    D --> E
    E --> F[RecycleDataSyncService 定时扫描]
    F --> G[查询未同步记录 + 关联附件]
    G --> H[读取附件 → Base64 编码<br/>不带标识头, 逗号分隔]
    H --> I[字段映射 WeighingRecord → RecycleTransportRecord<br/>重量 kg ÷ 1000 = 吨<br/>时间 → yyyy-MM-dd HH:mm:ss]
    I --> J[构造 HMAC-SHA256 签名<br/>4 个自定义 Header]
    J --> K[HTTP POST → addBatch<br/>请求体: JSON Array]
    K --> L{响应 code == 200?}
    L -- 是 --> M[SyncStatus = Success]
    L -- 否 --> N[FailCount++]
    N --> O{FailCount >= MaxFailCount?}
    O -- 是 --> P[SyncStatus = Abandoned]
    O -- 否 --> Q[下次重试]
```

### API 调用时序

```mermaid
sequenceDiagram
    participant Timer as RecycleDataSyncService<br/>(定时扫描)
    participant DB as SQLite<br/>(WeighingRecord)
    participant FS as 文件系统<br/>(AttachmentFile)
    participant Mapper as RecycleWeightMapper
    participant HMAC as RecycleHmacSignService
    participant API as §2.2 接口<br/>(资源化利用厂)

    Timer->>DB: 查询 SyncStatus=Pending 的记录
    DB-->>Timer: 返回 WeighingRecord 列表

    loop 每条记录
        Timer->>FS: 读取关联附件图片
        FS-->>Timer: 图片字节数组

        Timer->>Timer: Base64 编码（不带标识头）
        Timer->>Mapper: MapToRecycleRequest(record, base64Photos)

        Mapper-->>Timer: RecycleTransportRecord<br/>{NetWeight=kg/1000, OutTime=格式化, ...}

        Timer->>Timer: JsonSerializer.Serialize(数组)
        Timer->>HMAC: BuildSignature("POST", body)
        HMAC-->>Timer: (signature, gmtDateTime)

        Timer->>API: POST /dataCenter/resourcePlace/.../addBatch<br/>Headers: X-AKZTJG-HMAC-*<br/>Body: JSON Array

        alt code == 200
            API-->>Timer: { code: 200, msg: "操作成功" }
            Timer->>DB: SyncStatus = Success
        else code != 200
            API-->>Timer: { code: 4xx/5xx, msg: "错误信息" }
            Timer->>DB: FailCount++, FailMsg = msg
        else 网络异常
            Timer-->>Timer: LogWarning, 不计 FailCount
        end
    end
```

### 风险摘要

| 风险 | 等级 | 状态 |
|------|------|------|
| HMAC-SHA256 accessKey / secretKey 缺失 | **阻断** | ❌ 待平台方提供 |
| pointNumber（资源化利用厂标识）缺失 | **阻断** | ❌ 待运营方提供 |
| productName（成品名称）映射未确认 | **阻断** | ❌ 待运营方确认 |
| 外部接口网络不可达（防火墙） | 中 | ❌ 待运维确认 |
| §2.2 接口文档已获取 | — | ✅ 已解决 |
| SynchronizationOrderAsync 链路已定位 | — | ✅ 已解决 |
| WeighingMode 枚举已确认 | — | ✅ 已解决 |
