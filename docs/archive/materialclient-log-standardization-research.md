# MaterialClient 日志标准化调研报告

> 调研日期：2026-06-22
> 调研范围：MaterialClient、MaterialClient.Urban、UrbanManagement
> 调研目标：评估是否需要标准化客户端日志，为后续服务端下载客户端日志提供支持

---

## 1. 调研背景

为支持 UrbanManagement 服务端下载 MaterialClient 客户端日志进行故障排查，需要评估当前日志配置是否满足服务端拉取需求。

用户提出潜在问题：
1. 日志没有日期文件夹区分
2. 日志文件可能过大，避免服务端拉取到过大文件

---

## 2. 当前日志配置现状

### 2.1 MaterialClient（标准版）

**配置位置**：`src/MaterialClient/MaterialClientModule.cs:106-146`

```csharp
private void ConfigureSerilog(IServiceCollection services, IConfiguration configuration)
{
    var appDirectory = AppContext.BaseDirectory;
    var logsDirectory = Path.Combine(appDirectory, "Logs");
    
    if (!Directory.Exists(logsDirectory)) 
        Directory.CreateDirectory(logsDirectory);
    
    var logFilePath = Path.Combine(logsDirectory, "MaterialClient-.log");
    
    var loggerConfig = new LoggerConfiguration()
        .Enrich.FromLogContext()
        .MinimumLevel.Is(ParseLogEventLevel(defaultLevel))
        .MinimumLevel.Override("Microsoft", ParseLogEventLevel(microsoftLevel))
        .MinimumLevel.Override("Microsoft.EntityFrameworkCore", ParseLogEventLevel(efCoreLevel))
        .MinimumLevel.Override("Volo.Abp", ParseLogEventLevel(abpLevel))
        .WriteTo.File(
            logFilePath,
            rollingInterval: RollingInterval.Day,
            retainedFileCountLimit: 30,
            outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}",
            encoding: Encoding.UTF8);
}
```

**关键参数**：
- **日志目录**：`{AppDirectory}/Logs/`
- **文件命名**：`MaterialClient-.log`（Serilog 自动添加日期后缀，实际文件为 `MaterialClient-20250622.log`）
- **滚动策略**：按天滚动（`RollingInterval.Day`）
- **保留策略**：保留 30 天
- **编码**：UTF-8

### 2.2 MaterialClient.Urban（Urban 版本）

**配置位置**：`src/MaterialClient.Urban/MaterialClientUrbanModule.cs:102-136`

配置模式与 MaterialClient 完全一致，差异仅为文件名：

```csharp
var logFilePath = Path.Combine(logsDirectory, "MaterialClient.Urban-.log");
```

**关键参数**：
- **日志目录**：`{AppDirectory}/Logs/`
- **文件命名**：`MaterialClient.Urban-.log`
- **滚动策略**：按天滚动
- **保留策略**：保留 30 天

### 2.3 UrbanManagement（服务端）

**配置位置**：`src/UrbanManagement.App/appsettings.json:5-24`

```json
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft": "Warning",
        "Microsoft.Hosting.Lifetime": "Information",
        "Volo.Abp": "Warning"
      }
    },
    "WriteTo": [
      { "Name": "Console" },
      {
        "Name": "File",
        "Args": {
          "path": "Logs/log-.txt",
          "rollingInterval": "Day",
          "retainedFileCountLimit": 30
        }
      }
    ]
  }
}
```

**关键参数**：
- **日志目录**：`{ContentRoot}/Logs/`
- **文件命名**：`log-.txt`
- **滚动策略**：按天滚动
- **保留策略**：保留 30 天

---

## 3. 问题分析

### 3.1 日志文件组织结构

**当前模式**：
```
Logs/
├── MaterialClient-20250620.log
├── MaterialClient-20250621.log
├── MaterialClient-20250622.log
└── MaterialClient-20250623.log
```

**特点**：
- ✅ 按日期分文件（文件名包含日期）
- ❌ 所有日志文件在同一目录层级
- ❌ 没有按日期或大小创建子目录

### 3.2 日志文件大小风险

**当前配置**：
- Serilog 默认**不限制单文件大小**
- 仅按时间（天）切割
- 在高负载场景下，单日日志可能达到数百 MB

**潜在风险场景**：
1. **高频错误日志**：设备连接失败、API 调用异常等
2. **调试级别日志**：临时启用 Debug 级别时日志量激增
3. **长时间运行**：24 小时持续运行累积大量日志

### 3.3 服务端下载挑战

**假设服务端需要下载客户端日志**：

1. **文件大小不可控**：
   - 无大小限制可能导致单文件 > 100 MB
   - 下载耗时、超时风险

2. **文件定位效率**：
   - 所有日志在同一目录，需遍历查找特定日期
   - 日期子目录可提升定位效率

3. **传输友好性**：
   - 大文件不利于网络传输
   - 压缩传输可考虑，但需客户端支持

---

## 4. 标准化建议

### 4.1 目录结构调整

**建议结构**：
```
Logs/
├── 2025/
│   ├── 06/
│   │   ├── 20/
│   │   │   ├── MaterialClient-20250620.log
│   │   │   └── MaterialClient-20250620_001.log  # 大小切割
│   │   ├── 21/
│   │   │   └── MaterialClient-20250621.log
│   │   └── 22/
│   │       └── MaterialClient-20250622.log
```

**优势**：
- ✅ 按年/月/日分层，便于导航
- ✅ 同期日志聚合，便于归档和清理
- ✅ 服务端可按日期路径精准拉取

### 4.2 文件大小限制

**建议配置**：
```csharp
WriteTo.File(
    logFilePath,
    rollingInterval: RollingInterval.Day,
    rollOnFileSizeLimit: true,      // 启用大小限制
    fileSizeLimitBytes: 50 * 1024 * 1024,  // 50 MB 切割
    retainedFileCountLimit: 30,
    outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}",
    encoding: Encoding.UTF8)
```

**效果**：
- 单文件超过 50 MB 自动切割
- 切割后文件：`MaterialClient-20250622_001.log`、`MaterialClient-20250622_002.log`
- 控制单文件大小在合理范围内

### 4.3 配置可扩展性

**建议配置方式**：

考虑到 appsettings.json 的简洁性，推荐以下配置策略：

| 方案 | 适用场景 | 实现方式 |
|------|----------|----------|
| **代码硬编码（推荐）** | 标准客户端应用 | 在 Module 中定义常量，仅暴露必要开关 |
| **独立 serilog.json** | 需要灵活调整的环境 | 使用 `ReadFrom.Configuration` 加载独立文件 |
| **环境变量覆盖** | 容器化部署 | 通过 `DOTNET_` 环境变量覆盖关键参数 |
| **最小化配置** | 需要少量定制 | 仅在 appsettings.json 中配置日志级别 |

**方案对比**：

```csharp
// 方案 A：代码硬编码（推荐用于客户端）
private static readonly LogFileConfig DefaultLogConfig = new()
{
    PathFormat = "Logs/{YYYY}/{MM}/{DD}/MaterialClient-.log",
    RollingInterval = RollingInterval.Day,
    RollOnFileSizeLimit = true,
    FileSizeLimitBytes = 50 * 1024 * 1024,
    RetainedFileCountLimit = 30
};
```

```json
// 方案 B：最小化 appsettings.json 配置
{
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    }
  },
  "Log": {
    "Directory": "Logs",
    "FileSizeLimitMB": 50,
    "RetentionDays": 30
  }
}
```

```json
// 方案 C：独立 serilog.json（不推荐，会增加配置文件数量）
{
  "Serilog": {
    "WriteTo": [...]
  }
}
```

**推荐配置**：

```json
// appsettings.json - 保持简洁
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning",
      "Volo.Abp": "Warning"
    }
  },
  "Log": {
    "Enabled": true,
    "Directory": "Logs",
    "FileSizeLimitMB": 50,
    "RetentionDays": 30,
    "UseDateFolders": true
  }
}
```

```csharp
// 代码中读取简化配置
private void ConfigureSerilog(IServiceCollection services, IConfiguration configuration)
{
    var logSection = configuration.GetSection("Log");
    var enabled = logSection.GetValue<bool>("Enabled", true);
    
    if (!enabled) return;

    var logsDirectory = logSection.GetValue<string>("Directory", "Logs");
    var fileSizeLimit = logSection.GetValue<long>("FileSizeLimitMB", 50) * 1024 * 1024;
    var retentionDays = logSection.GetValue<int>("RetentionDays", 30);
    var useDateFolders = logSection.GetValue<bool>("UseDateFolders", true);

    var logFilePath = useDateFolders 
        ? Path.Combine(logsDirectory, "{YYYY}/{MM}/{DD}/MaterialClient-.log")
        : Path.Combine(logsDirectory, "MaterialClient-.log");

    var loggerConfig = new LoggerConfiguration()
        .Enrich.FromLogContext()
        .MinimumLevel.Is(ParseLogEventLevel(defaultLevel))
        .MinimumLevel.Override("Microsoft", ParseLogEventLevel(microsoftLevel))
        .MinimumLevel.Override("Microsoft.EntityFrameworkCore", ParseLogEventLevel(efCoreLevel))
        .MinimumLevel.Override("Volo.Abp", ParseLogEventLevel(abpLevel))
        .WriteTo.File(
            logFilePath,
            rollingInterval: RollingInterval.Day,
            rollOnFileSizeLimit: true,
            fileSizeLimitBytes: fileSizeLimit,
            retainedFileCountLimit: retentionDays,
            outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}",
            encoding: Encoding.UTF8);

    Log.Logger = loggerConfig.CreateLogger();
    
    services.AddLogging(logging =>
    {
        logging.ClearProviders();
        logging.AddSerilog(Log.Logger);
    });
}
```

**优势**：
- ✅ appsettings.json 保持简洁（仅 5 个配置项）
- ✅ 详细的日志策略在代码中维护，便于版本控制
- ✅ 保留必要的灵活性（文件大小、保留天数、日期文件夹可配）
- ✅ 开发者可在本地临时禁用日志（`"Enabled": false`）

---

## 5. 跨项目一致性

### 5.1 当前一致性评估

| 配置项 | MaterialClient | MaterialClient.Urban | UrbanManagement |
|--------|----------------|----------------------|-----------------|
| 滚动策略 | 按天 | 按天 | 按天 |
| 保留天数 | 30 天 | 30 天 | 30 天 |
| 文件大小限制 | ❌ 无 | ❌ 无 | ❌ 无 |
| 日期目录 | ❌ 无 | ❌ 无 | ❌ 无 |
| 配置方式 | 代码硬编码 | 代码硬编码 | appsettings.json |

**结论**：
- ✅ 滚动策略和保留天数已一致
- ❌ 缺少文件大小限制和日期目录结构
- ❌ 配置方式不统一（客户端硬编码 vs 服务端配置文件）

### 5.2 标准化目标

**建议统一标准**：
1. **目录结构**：`Logs/{YYYY}/{MM}/{DD}/` 日期子目录
2. **文件大小限制**：50 MB 自动切割
3. **保留策略**：保留 30 天
4. **配置方式**：客户端和服务端均使用 appsettings.json

---

## 6. 服务端日志下载支持评估

### 6.1 UrbanManagement 当前能力

**已检查**：
- UrbanManagement 无客户端日志下载相关 API
- 现有文件下载能力：许可证文件下载（`GovProjectLicenseAppService`）

**需要新增**：
1. 客户端日志上传 API（客户端主动推送）
2. 服务端日志拉取 API（服务端请求客户端）
3. 日志文件列表查询 API
4. 权限控制和审计

### 6.2 传输方案建议

**方案对比**：

| 方案 | 优势 | 劣势 |
|------|------|------|
| **客户端主动上传** | ✅ 服务端无需主动连接<br>✅ 可批量上传历史日志 | ❌ 需要定时任务<br>❌ 可能重复上传 |
| **服务端主动拉取** | ✅ 按需拉取<br>✅ 可实时获取 | ❌ 需要客户端监听端口<br>❌ 网络拓扑要求高 |
| **混合模式** | ✅ 灵活性高<br>✅ 支持离线场景 | ❌ 实现复杂度较高 |

**推荐**：客户端主动上传（适合当前 UrbanManagement 已有的轮询上报模式）

---

## 7. 服务端下载日志设计方案

### 7.1 架构设计

#### 7.1.1 传输架构

基于需求，采用 **服务端按需拉取 + 静态文件缓存** 模式：

```
┌─────────────────┐                    ┌─────────────────┐
│ MaterialClient  │                    │ UrbanManagement  │
│   (客户端)       │                    │   (服务端)        │
└────────┬────────┘                    └────────┬────────┘
         │                                     │
         │ ① 用户选择日期，请求日志列表           │
         │ <─────────────────────────────────│
         │                                     │
         │ ② 客户端返回该日期的日志文件列表        │
         │─────────────────────────────────> │
         │                                     │
         │ ③ 用户选择文件，请求下载              │
         │ <─────────────────────────────────│
         │                                     │
         │ ④ 服务端从客户端拉取文件并保存          │
         │═══════════════════════════════════│
         │      (HTTP 传输 → 服务端静态文件)      │
         │═══════════════════════════════════│
         │                                     │
         │ ⑤ 服务端返回下载链接给用户             │
         │─────────────────────────────────> │
         │                                     │
         │ ⑥ 用户从服务端静态文件下载             │
         │ <─────────────────────────────────│
         │                                     │
    已缓存文件：                               │ ClientLogs/ 
    └── material-client-001/                    │   ├─ material-client-001/
       └── 2025/06/22/                          │      └── 2025/06/22/
           ├─ MaterialClient-20250622.log        │         └─ *.log
           └─ MaterialClient-20250622_001.log     │
```

**核心流程**：
1. **浏览阶段**：服务端请求某日期的日志目录 → 客户端返回文件列表
2. **选择阶段**：服务端用户勾选需要下载的文件
3. **拉取阶段**：服务端从客户端拉取文件并保存为静态文件（缓存）
4. **下载阶段**：用户从服务端静态文件下载（可重复下载）
5. **清理阶段**：运维人员定期手动删除缓存文件

**设计原则**：
1. **静态文件缓存**：拉取的日志保存在服务端作为静态文件
2. **按需拉取**：仅在用户操作时才发起传输
3. **手动清理**：由运维人员手动删除缓存文件，无需自动清理逻辑
4. **最小侵入性**：复用现有 SignalR 连接

#### 7.1.2 与现有组件集成

UrbanManagement 现有相关组件：

| 组件 | 位置 | 用途 | 扩展方案 |
|------|------|------|----------|
| `DeviceStatusHub` | `src/UrbanManagement.Core/Hubs/` | 设备状态 SignalR Hub | 扩展支持日志消息通道 |
| `UrbanServerUploadService` | `src/MaterialClient.Urban/Services/` | 客户端上传服务 | 扩展支持日志上传 |
| `AttachmentService` | `src/MaterialClient.Common/Services/` | 附件处理 | 参考实现日志存储 |

### 7.2 API 设计

#### 7.2.1 服务端 → 客户端：请求日志列表

**API 端点**：通过 SignalR Hub 调用

**Hub 方法**：`RequestLogList`

**请求参数**：
```json
{
  "requestId": "req-list-20250622",
  "clientId": "material-client-001",
  "date": "2025-06-22",
  "dateFolder": "2025/06/22/"
}
```

**响应**（通过 SignalR 返回）：
```json
{
  "requestId": "req-list-20250622",
  "clientId": "material-client-001",
  "date": "2025-06-22",
  "files": [
    {
      "fileName": "MaterialClient-20250622.log",
      "filePath": "Logs/2025/06/22/",
      "fileSize": 5242880,
      "lastModified": "2025-06-22T23:59:59+08:00"
    },
    {
      "fileName": "MaterialClient-20250622_001.log",
      "filePath": "Logs/2025/06/22/",
      "fileSize": 52428800,
      "lastModified": "2025-06-22T18:30:00+08:00"
    }
  ],
  "totalSize": 57671680,
  "scannedAt": "2025-06-22T10:30:00+08:00"
}
```

#### 7.2.2 服务端 → 客户端 → 用户浏览器：流式下载

**流程**：`用户浏览器 → 服务端 → 客户端 → 服务端 → 用户浏览器`

**服务端 API 端点**：`GET /api/app/client-log/download`

**查询参数**：
- `clientId`：客户端 ID（必需）
- `filePath`：日志文件相对路径（必需）
- `fileName`：文件名（必需）

**实现方式**：服务端作为代理，从客户端流式获取并实时转发

```csharp
// 服务端 Controller
[HttpGet("download")]
[Authorize]
public async Task<IActionResult> DownloadClientLog([FromQuery] string clientId, 
                                                   [FromQuery] string filePath, 
                                                   [FromQuery] string fileName)
{
    // 1. 向客户端发起下载请求
    var clientDownloadUrl = $"{GetClientBaseUrl(clientId)}/api/local-log/download";
    
    // 2. 流式获取客户端文件
    using var response = await _httpClient.GetAsync(
        clientDownloadUrl, 
        HttpCompletionOption.ResponseHeadersRead);

    if (!response.IsSuccessStatusCode)
        return NotFound($"客户端返回错误: {response.StatusCode}");

    // 3. 实时转发给浏览器
    var stream = await response.Content.ReadAsStreamAsync();
    return new FileStreamResult(stream, "text/plain")
    {
        FileDownloadName = fileName
    };
}
```

**客户端本地 API 端点**：`GET /api/local-log/download`

**查询参数**：
- `filePath`：日志文件相对路径
- `fileName`：文件名

**响应**：文件流（`application/octet-stream` 或 `text/plain`）

```csharp
// 客户端 Controller (仅本地监听)
[HttpGet("download")]
public IActionResult DownloadLocalLog([FromQuery] string filePath, 
                                      [FromQuery] string fileName)
{
    var fullPath = Path.Combine(_logsDirectory, filePath, fileName);
    if (!System.IO.File.Exists(fullPath))
        return NotFound();

    var stream = new FileStream(fullPath, FileMode.Open, FileAccess.Read);
    return new FileStreamResult(stream, "text/plain")
    {
        FileDownloadName = fileName
    };
}
```

#### 7.2.3 服务端 → 客户端：批量下载（ZIP 打包）

**服务端 API 端点**：`POST /api/app/client-log/download-batch`

**请求体**：
```json
{
  "clientId": "material-client-001",
  "files": [
    {
      "filePath": "Logs/2025/06/22/",
      "fileName": "MaterialClient-20250622.log"
    },
    {
      "filePath": "Logs/2025/06/22/",
      "fileName": "MaterialClient-20250622_001.log"
    }
  ]
}
```

**实现**：服务端从客户端逐个下载文件，实时打包成 ZIP 返回

```csharp
[HttpPost("download-batch")]
[Authorize]
public async Task<IActionResult> DownloadBatch([FromBody] BatchDownloadRequest request)
{
    using var zipStream = new MemoryStream();
    using var archive = new ZipArchive(zipStream, ZipArchiveMode.Create, true);

    foreach (var file in request.Files)
    {
        // 从客户端下载单个文件
        var fileContent = await DownloadFromClientAsync(request.ClientId, file.FilePath, file.FileName);
        
        // 添加到 ZIP
        var entry = archive.CreateEntry(file.FileName);
        using var entryStream = entry.Open();
        await entryStream.WriteAsync(fileContent, 0, fileContent.Length);
    }

    archive.Complete();
    zipStream.Position = 0;

    return File(zipStream, "application/zip", "client-logs.zip");
}
```

### 7.3 实体设计

#### 7.3.1 ClientLog 实体（缓存的日志文件）

```csharp
using System;
using Volo.Abp.Domain.Entities.Auditing;

namespace UrbanManagement.Core.Entities;

/// <summary>
/// 客户端日志文件缓存记录
/// </summary>
public class ClientLog : FullAuditedEntity<Guid>
{
    /// <summary>
    /// 客户端唯一标识
    /// </summary>
    public string ClientId { get; set; }

    /// <summary>
    /// 客户端名称
    /// </summary>
    public string ClientName { get; set; }

    /// <summary>
    /// 日志文件名
    /// </summary>
    public string FileName { get; set; }

    /// <summary>
    /// 客户端原始路径（相对）
    /// </summary>
    public string OriginalFilePath { get; set; }

    /// <summary>
    /// 服务端缓存路径（相对）
    /// </summary>
    public string CachedFilePath { get; set; }

    /// <summary>
    /// 文件大小（字节）
    /// </summary>
    public long FileSize { get; set; }

    /// <summary>
    /// 日志日期
    /// </summary>
    public DateTime LogDate { get; set; }

    /// <summary>
    /// 客户端文件最后修改时间
    /// </summary>
    public DateTime ClientLastModified { get; set; }

    /// <summary>
    /// 拉取时间
    /// </summary>
    public DateTime PulledAt { get; set; }

    /// <summary>
    /// 是否已删除（运维人员手动删除）
    /// </summary>
    public bool IsDeleted { get; set; }

    /// <summary>
    /// 删除时间
    /// </summary>
    public DateTime? DeletedAt { get; set; }

    /// <summary>
    /// 删除人
    /// </summary>
    public string? DeletedBy { get; set; }

    /// <summary>
    /// 备注
    /// </summary>
    public string? Remark { get; set; }
}
```

#### 7.3.2 ClientInfo 实体（客户端连接信息）

```csharp
using System;
using Volo.Abp.Domain.Entities.Auditing;

namespace UrbanManagement.Core.Entities;

/// <summary>
/// 客户端连接信息
/// </summary>
public class ClientInfo : FullAuditedEntity<Guid>
{
    /// <summary>
    /// 客户端唯一标识
    /// </summary>
    public string ClientId { get; set; }

    /// <summary>
    /// 客户端名称
    /// </summary>
    public string ClientName { get; set; }

    /// <summary>
    /// 客户端版本
    /// </summary>
    public string ClientVersion { get; set; }

    /// <summary>
    /// 最后连接时间
    /// </summary>
    public DateTime LastConnectedAt { get; set; }

    /// <summary>
    /// SignalR 连接 ID
    /// </summary>
    public string? SignalRConnectionId { get; set; }

    /// <summary>
    /// 客户端 IP 地址
    /// </summary>
    public string? IpAddress { get; set; }

    /// <summary>
    /// 是否在线
    /// </summary>
    public bool IsOnline { get; set; }

    /// <summary>
    /// 是否支持日志拉取
    /// </summary>
    public bool SupportsLogPull { get; set; }

    /// <summary>
    /// 备注
    /// </summary>
    public string? Remark { get; set; }
}
```

#### 7.3.3 ClientLogPullHistory 实体（拉取审计）

```csharp
using System;
using Volo.Abp.Domain.Entities.Auditing;

namespace UrbanManagement.Core.Entities;

/// <summary>
/// 客户端日志拉取历史记录
/// </summary>
public class ClientLogPullHistory : CreationAuditedEntity<Guid>
{
    /// <summary>
    /// 客户端 ID
    /// </summary>
    public string ClientId { get; set; }

    /// <summary>
    /// 请求的日期
    /// </summary>
    public DateTime RequestDate { get; set; }

    /// <summary>
    /// 请求的日期文件夹
    /// </summary>
    public string DateFolder { get; set; }

    /// <summary>
    /// 拉取的文件列表（JSON）
    /// </summary>
    public string FilesJson { get; set; }

    /// <summary>
    /// 总大小（字节）
    /// </summary>
    public long TotalSize { get; set; }

    /// <summary>
    /// 拉取用户 ID
    /// </summary>
    public Guid? PulledByUserId { get; set; }

    /// <summary>
    /// 拉取用户名
    /// </summary>
    public string? PulledByName { get; set; }

    /// <summary>
    /// 拉取 IP 地址
    /// </summary>
    public string? PullIpAddress { get; set; }

    /// <summary>
    /// 拉取原因
    /// </summary>
    public string? PullReason { get; set; }

    /// <summary>
    /// 关联的工单/问题 ID
    /// </summary>
    public string? RelatedTicketId { get; set; }

    /// <summary>
    /// 是否成功
    /// </summary>
    public bool IsSuccess { get; set; }

    /// <summary>
    /// 错误信息
    /// </summary>
    public string? ErrorMessage { get; set; }
}
```

### 7.4 服务端服务设计

#### 7.4.1 ClientLogAppService

```csharp
using UrbanManagement.Core.Entities;
using Volo.Abp.Application.Services;

namespace UrbanManagement.Core.Services;

/// <summary>
/// 客户端日志应用服务
/// </summary>
public interface IClientLogAppService : IApplicationService
{
    /// <summary>
    /// 获取在线客户端列表
    /// </summary>
    Task<List<ClientInfoDto>> GetOnlineClientsAsync();

    /// <summary>
    /// 请求客户端日志列表
    /// </summary>
    Task<ClientLogListResultDto> RequestLogListAsync(RequestLogListDto input);

    /// <summary>
    /// 从客户端拉取日志文件并缓存到服务端
    /// </summary>
    Task<List<ClientLogDto>> PullAndCacheAsync(PullLogDto input);

    /// <summary>
    /// 获取已缓存的日志文件列表
    /// </summary>
    Task<PagedResultDto<ClientLogDto>> GetCachedLogsAsync(GetCachedLogsDto input);

    /// <summary>
    /// 下载已缓存的日志文件
    /// </summary>
    Task<IActionResult> DownloadCachedAsync(Guid id);

    /// <summary>
    /// 批量下载已缓存的日志文件（ZIP）
    /// </summary>
    Task<IActionResult> DownloadBatchCachedAsync(List<Guid> ids);

    /// <summary>
    /// 删除已缓存的日志文件
    /// </summary>
    Task DeleteCachedAsync(Guid id);

    /// <summary>
    /// 记录拉取历史
    /// </summary>
    Task RecordPullHistoryAsync(ClientLogPullHistory history);
}
```

#### 7.4.2 SignalR Hub 扩展

在现有 `DeviceStatusHub` 中添加日志相关方法：

```csharp
// DeviceStatusHub.cs
public class DeviceStatusHub : Hub
{
    private readonly IClientLogService _clientLogService;

    // 现有方法...

    /// <summary>
    /// 客户端注册日志拉取能力
    /// </summary>
    public async Task RegisterLogCapability(string clientId, LogCapabilityInfo capability)
    {
        await _clientLogService.RegisterCapabilityAsync(clientId, capability);
        await Clients.Caller.SendAsync("LogCapabilityRegistered", clientId);
    }

    /// <summary>
    /// 服务端请求客户端日志列表
    /// </summary>
    public async Task RequestLogList(string requestId, string clientId, string dateFolder)
    {
        await Clients.Client(clientId).SendAsync("ReceiveLogListRequest", new
        {
            RequestId = requestId,
            ClientId = clientId,
            DateFolder = dateFolder,
            RequestedAt = DateTime.Now
        });
    }

    /// <summary>
    /// 客户端返回日志列表
    /// </summary>
    public async Task ReturnLogList(string requestId, ClientLogListResultDto result)
    {
        // 通知服务端 UI 层
        await Clients.Group("LogRequesters").SendAsync("LogListReceived", new
        {
            RequestId = requestId,
            Result = result
        });
    }
}
```

### 7.5 客户端实现设计

#### 7.5.1 ClientLogPullService（MaterialClient）

```csharp
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.Configuration;

namespace MaterialClient.Common.Services;

/// <summary>
/// 客户端日志拉取服务（响应服务端请求）
/// </summary>
public class ClientLogPullService : ITransientDependency
{
    private readonly ILogger<ClientLogPullService> _logger;
    private readonly IConfiguration _configuration;
    private readonly string _logsDirectory;
    private HubConnection? _hubConnection;

    public ClientLogPullService(
        ILogger<ClientLogPullService> logger,
        IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
        _logsDirectory = Path.Combine(AppContext.BaseDirectory, "Logs");
    }

    /// <summary>
    /// 初始化 SignalR 连接并注册日志拉取能力
    /// </summary>
    public async Task InitializeAsync()
    {
        var serverUrl = _configuration["UrbanManagement:BaseUrl"];
        if (string.IsNullOrEmpty(serverUrl))
        {
            _logger.LogWarning("未配置 UrbanManagement 服务端地址，日志拉取功能不可用");
            return;
        }

        _hubConnection = new HubConnectionBuilder()
            .WithUrl($"{serverUrl}/hubs/devicestatus")
            .Build();

        // 注册接收日志列表请求
        _hubConnection.On<string, string, string>("ReceiveLogListRequest", 
            async (requestId, clientId, dateFolder) =>
            {
                await HandleLogListRequestAsync(requestId, clientId, dateFolder);
            });

        await _hubConnection.StartAsync();

        // 注册日志拉取能力
        await _hubConnection.InvokeAsync("RegisterLogCapability", 
            GetClientId(), 
            new LogCapabilityInfo
            {
                SupportsLogPull = true,
                LogDirectory = _logsDirectory,
                MaxConcurrentDownloads = 3
            });

        _logger.LogInformation("客户端日志拉取服务已启动");
    }

    /// <summary>
    /// 处理日志列表请求
    /// </summary>
    private async Task HandleLogListRequestAsync(string requestId, string clientId, string dateFolder)
    {
        try
        {
            var targetPath = Path.Combine(_logsDirectory, dateFolder);
            var files = new List<LogFileDto>();

            if (Directory.Exists(targetPath))
            {
                var logFiles = Directory.GetFiles(targetPath, "*.log");
                foreach (var file in logFiles)
                {
                    var info = new FileInfo(file);
                    files.Add(new LogFileDto
                    {
                        FileName = info.Name,
                        FilePath = dateFolder,
                        FileSize = info.Length,
                        LastModified = info.LastWriteTime
                    });
                }
            }

            var result = new ClientLogListResultDto
            {
                RequestId = requestId,
                ClientId = clientId,
                DateFolder = dateFolder,
                Files = files,
                TotalSize = files.Sum(f => f.FileSize),
                ScannedAt = DateTime.Now
            };

            await _hubConnection.InvokeAsync("ReturnLogList", requestId, result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "处理日志列表请求失败");
        }
    }

    private string GetClientId()
    {
        return _configuration["Client:Id"] ?? Environment.MachineName;
    }
}

/// <summary>
/// 日志文件信息 DTO
/// </summary>
public class LogFileDto
{
    public string FileName { get; set; }
    public string FilePath { get; set; }
    public long FileSize { get; set; }
    public DateTime LastModified { get; set; }
}

/// <summary>
/// 日志能力信息
/// </summary>
public class LogCapabilityInfo
{
    public bool SupportsLogPull { get; set; }
    public string LogDirectory { get; set; }
    public int MaxConcurrentDownloads { get; set; }
}
```

#### 7.5.2 客户端本地 HTTP API（仅本地监听）

```csharp
using Microsoft.AspNetCore.Mvc;

namespace MaterialClient.Controllers;

/// <summary>
/// 客户端本地日志 API（仅服务端可访问）
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class LocalLogController : ControllerBase
{
    private readonly ILogger<LocalLogController> _logger;
    private readonly string _logsDirectory;

    public LocalLogController(ILogger<LocalLogController> logger)
    {
        _logger = logger;
        _logsDirectory = Path.Combine(AppContext.BaseDirectory, "Logs");
    }

    /// <summary>
    /// 下载本地日志文件
    /// </summary>
    [HttpGet("download")]
    public IActionResult DownloadLog([FromQuery] string filePath, [FromQuery] string fileName)
    {
        try
        {
            var fullPath = Path.Combine(_logsDirectory, filePath, fileName);
            
            if (!System.IO.File.Exists(fullPath))
            {
                _logger.LogWarning("日志文件不存在: {FullPath}", fullPath);
                return NotFound(new { error = "日志文件不存在", path = fullPath });
            }

            var stream = new FileStream(fullPath, FileMode.Open, FileAccess.Read, FileShare.Read);
            
            return new FileStreamResult(stream, "text/plain")
            {
                FileDownloadName = fileName,
                EnableRangeProcessing = true  // 支持断点续传
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "下载日志文件失败");
            return StatusCode(500, new { error = "下载失败", message = ex.Message });
        }
    }

    /// <summary>
    /// 获取日志文件列表（用于调试）
    /// </summary>
    [HttpGet("list")]
    public IActionResult ListLogs([FromQuery] string? dateFolder = null)
    {
        try
        {
            var targetPath = string.IsNullOrEmpty(dateFolder) 
                ? _logsDirectory 
                : Path.Combine(_logsDirectory, dateFolder);

            if (!Directory.Exists(targetPath))
            {
                return Ok(new List<LogFileDto>());
            }

            var files = Directory.GetFiles(targetPath, "*.log", SearchOption.AllDirectories)
                .Select(f => new FileInfo(f))
                .Select(info => new LogFileDto
                {
                    FileName = info.Name,
                    FilePath = Path.GetRelativePath(_logsDirectory, info.DirectoryName),
                    FileSize = info.Length,
                    LastModified = info.LastWriteTime
                })
                .ToList();

            return Ok(files);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "获取日志列表失败");
            return StatusCode(500, new { error = "获取失败", message = ex.Message });
        }
    }
}
```

#### 7.5.3 启用本地 HTTP 服务

在客户端启动时配置本地 HTTP 监听（仅监听 localhost）：

```csharp
// MaterialClientUrbanModule.cs 或 Program.cs
public override void OnApplicationInitialization(ApplicationInitializationContext context)
{
    var configuration = context.ServiceProvider.GetConfiguration();
    var enableLocalApi = configuration.GetValue<bool>("LocalLogApi:Enabled", true);
    var localApiPort = configuration.GetValue<int>("LocalLogApi:Port", 5900);

    if (enableLocalApi)
    {
        // 启动本地 Kestrel 监听（仅 localhost）
        Task.Run(async () =>
        {
            var builder = WebApplication.CreateBuilder();
            builder.Services.AddControllers();
            builder.Services.AddEndpointsApiExplorer();
            
            var app = builder.Build();
            app.MapControllers();
            
            app.Urls.Add($"http://localhost:{localApiPort}");
            await app.RunAsync();
        });

        _logger.LogInformation("本地日志 API 已启动: http://localhost:{Port}", localApiPort);
    }

    // 初始化 SignalR 连接
    var logPullService = context.ServiceProvider.GetService<ClientLogPullService>();
    if (logPullService != null)
    {
        Task.Run(() => logPullService.InitializeAsync());
    }
}
```

**客户端配置（appsettings.json）**：
```json
{
  "LocalLogApi": {
    "Enabled": true,
    "Port": 5900
  },
  "UrbanManagement": {
    "BaseUrl": "http://191.12.234.212:5233"
  },
  "Client": {
    "Id": "material-client-001"
  }
}
```

### 7.6 安全性设计

#### 7.6.1 权限控制

```csharp
// 在 ClientLogAppService 上添加权限
[Volo.Abp.Authorization.AbpAuthorize("UrbanManagement.ClientLogs")]
public class ClientLogAppService : ApplicationService, IClientLogAppService
{
    // ...
}
```

权限定义（`UrbanManagementPermissions.cs`）：
```csharp
public static class UrbanManagementPermissions
{
    public const string ClientLogs = "UrbanManagement.ClientLogs";
    public const string ClientLogsDownload = ClientLogs + ".Download";
    public const string ClientLogsDelete = ClientLogs + ".Delete";
    public const string ClientLogsRequest = ClientLogs + ".Request";
}
```

#### 7.6.2 数据加密

**传输加密**：
- 所有 API 通信强制 HTTPS
- JWT Token 认证

**存储加密**（可选）：
- 敏感日志可考虑 AES-256 加密存储
- 密钥管理使用 Azure Key Vault 或本地安全存储

#### 7.6.3 审计日志

所有日志下载操作记录到 `ClientLogDownloadHistory`：

```csharp
public async Task<FileResult> DownloadAsync(Guid id, DownloadLogDto input)
{
    var log = await _repository.GetAsync(id);

    // 记录下载历史
    await _downloadHistoryRepository.InsertAsync(new ClientLogDownloadHistory
    {
        ClientLogId = id,
        DownloadedByUserId = CurrentUser.Id,
        DownloadedByName = CurrentUser.Name,
        DownloadIpAddress = GetClientIpAddress(),
        DownloadReason = input.Reason,
        RelatedTicketId = input.TicketId
    });

    // 返回文件流
    // ...
}
```

### 7.7 配置设计

#### 7.7.1 客户端配置（appsettings.json）

```json
{
  "LocalLogApi": {
    "Enabled": true,
    "Port": 5900
  },
  "UrbanManagement": {
    "BaseUrl": "http://191.12.234.212:5233"
  },
  "Client": {
    "Id": "material-client-001"
  },
  "Log": {
    "Enabled": true,
    "Directory": "Logs",
    "FileSizeLimitMB": 50,
    "RetentionDays": 30,
    "UseDateFolders": true
  }
}
```

**客户端配置项说明**：

| 配置项 | 说明 |
|--------|------|
| `LocalLogApi:Enabled` | 是否启用本地 HTTP API（供服务端拉取） |
| `LocalLogApi:Port` | 本地 API 监听端口 |
| `UrbanManagement:BaseUrl` | UrbanManagement 服务端地址 |
| `Client:Id` | 客户端唯一标识 |
| `Log:Enabled` | 是否启用文件日志 |
| `Log:Directory` | 日志目录 |
| `Log:FileSizeLimitMB` | 单文件大小限制（MB） |
| `Log:RetentionDays` | 日志保留天数 |
| `Log:UseDateFolders` | 是否使用日期子目录 |

#### 7.7.2 服务端配置（appsettings.json）

```json
{
  "ClientLogPull": {
    "Enabled": true,
    "MaxConcurrentPulls": 5,
    "PullTimeoutSeconds": 300,
    "MaxZipSizeMB": 500,
    "CacheBasePath": "ClientLogs/",
    "EnablePullHistory": true
  }
}
```

**服务端配置项说明**：

| 配置项 | 说明 |
|--------|------|
| `ClientLogPull:Enabled` | 是否启用客户端日志拉取功能 |
| `ClientLogPull:MaxConcurrentPulls` | 服务端最大并发拉取数 |
| `ClientLogPull:PullTimeoutSeconds` | 单个拉取请求超时时间 |
| `ClientLogPull:MaxZipSizeMB` | 批量下载 ZIP 最大大小（超过则拒绝） |
| `ClientLogPull:CacheBasePath` | 日志缓存目录（相对 wwwroot 或绝对路径） |
| `ClientLogPull:EnablePullHistory` | 是否记录拉取历史 |

**注意**：
- 日志文件缓存在 `CacheBasePath` 指定的目录中（如 `wwwroot/ClientLogs/`）
- 缓存文件由运维人员手动删除，系统不提供自动清理功能
- 建议定期检查磁盘空间使用情况

### 7.8 实施优先级

**Phase 1（高优先级）- 核心拉取功能**：
1. 客户端日志标准化（日期目录 + 大小限制）
2. 客户端本地 HTTP API 实现
3. 服务端 SignalR 日志列表请求
4. 服务端拉取并缓存日志文件
5. 基础权限控制

**Phase 2（中优先级）- 批量和优化**：
6. 批量拉取和 ZIP 打包
7. 拉取历史记录
8. Blazor 管理界面（日期浏览 + 文件选择）
9. 缓存文件管理（列表、删除）
10. 断点续传支持

**Phase 3（低优先级）- 增强功能**：
11. 日志在线预览
12. 日志搜索和过滤
13. 拉取进度实时显示
14. 客户端日志健康检查

---

## 8. 实施建议

### 8.1 阶段化实施

**阶段 1：客户端日志标准化**
- 目标：优化客户端日志文件组织
- 任务：
  - [ ] 修改 MaterialClient 日志配置（日期目录 + 大小限制）
  - [ ] 修改 MaterialClient.Urban 日志配置
  - [ ] 更新 appsettings.json 配置项

**阶段 2：客户端本地 API**
- 目标：客户端支持服务端拉取
- 任务：
  - [ ] 实现 ClientLogPullService（SignalR）
  - [ ] 实现 LocalLogController（本地 HTTP API）
  - [ ] 配置本地 Kestrel 监听

**阶段 3：服务端拉取功能**
- 目标：服务端可拉取客户端日志
- 任务：
  - [ ] 扩展 DeviceStatusHub（日志相关方法）
  - [ ] 实现 ClientLogAppService
  - [ ] 实现流式下载代理
  - [ ] 添加权限控制

**阶段 4：管理界面**
- 目标：Web UI 支持日志拉取操作
- 任务：
  - [ ] 实现客户端列表页面
  - [ ] 实现日期浏览和文件选择
  - [ ] 实现下载进度显示

### 8.2 向后兼容性

**迁移策略**：
1. **渐进式切换**：新配置仅影响新日志，旧日志保持原路径
2. **双路径支持**：本地 API 支持扫描新旧两种目录结构
3. **可选启用**：`LocalLogApi:Enabled` 默认可设为 false，按需启用

---

## 9. 结论与建议

### 8.1 调研结论

1. **当前日志配置存在以下问题**：
   - ❌ 缺少文件大小限制，单日日志可能过大
   - ❌ 缺少日期目录结构，服务端定位效率低
   - ❌ 客户端配置硬编码，不利于调整

2. **服务端日志下载支持现状**：
   - ❌ UrbanManagement 无客户端日志相关功能
   - ✅ 已有文件下载基础能力
   - ⚠️ 需要设计完整的日志传输方案

### 8.2 标准化必要性

**建议：需要标准化**

**理由**：
1. **服务端运维需求**：支持远程获取客户端日志进行故障排查
2. **文件大小控制**：避免单文件过大影响传输
3. **目录组织优化**：提升日志管理和定位效率
4. **配置灵活性**：支持按环境调整日志策略

### 8.3 下一步行动

**推荐启动 OpenSpec 变更提案**：

```bash
# 创建日志标准化变更
openspec create standardize-client-logging
```

**变更范围**：
- MaterialClient：日志配置标准化
- MaterialClient.Urban：日志配置标准化
- UrbanManagement：客户端日志上传 API（可选）

**建议技能**：
- 使用 `/opsx:propose standardize-client-logging` 创建正式提案
- 参考本报告中的标准化建议编写 specs

---

## 10. 实施路线图

### 10.1 变更分解建议

基于本调研报告，建议将工作拆分为以下 OpenSpec 变更：

**变更 1：standardize-client-logging-config**
- 范围：MaterialClient、MaterialClient.Urban
- 内容：统一日志配置结构，添加日期目录和大小限制
- 依赖：无
- 优先级：高

**变更 2：add-client-log-local-api**
- 范围：MaterialClient.Urban
- 内容：实现客户端本地 HTTP API 和 SignalR 日志拉取服务
- 依赖：变更 1
- 优先级：高

**变更 3：add-server-log-pull-api**
- 范围：UrbanManagement
- 内容：实现服务端日志拉取 API、SignalR Hub 扩展和流式下载代理
- 依赖：变更 2
- 优先级：高

**变更 4：add-log-pull-management-ui**
- 范围：UrbanManagement
- 内容：实现日志拉取管理 Web UI（客户端列表、日期浏览、文件选择、下载）
- 依赖：变更 3
- 优先级：中

### 10.2 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 客户端离线无法拉取 | 高 | 显示在线状态，仅对在线客户端提供拉取 |
| 拉取影响客户端性能 | 中 | 限制并发拉取数，支持断点续传 |
| 大文件拉取超时 | 中 | 实施流式传输，支持断点续传 |
| 敏感信息泄露 | 高 | 添加权限控制和审计日志 |
| 服务端存储空间占用 | 中 | 提供缓存管理界面，运维人员定期清理 |
| 服务端静态文件访问安全 | 中 | 配置文件访问权限，添加认证 |
| 客户端本地端口冲突 | 低 | 支持自定义端口配置 |

### 10.3 测试策略

**单元测试**：
- 日志文件扫描逻辑
- 客户端本地 API 路径解析
- 服务端缓存路径生成

**集成测试**：
- 端到端日志拉取流程（SignalR → 本地 API → 缓存）
- 拉取中断和恢复场景
- 并发拉取处理
- 缓存文件删除验证

**性能测试**：
- 大文件（>100MB）拉取性能
- 多客户端同时拉取
- 服务端缓存写入性能
- 静态文件下载性能

### 10.3 测试策略

**单元测试**：
- 日志文件扫描逻辑
- 分片上传逻辑
- 文件哈希计算

**集成测试**：
- 端到端日志上报流程
- 上传中断和恢复场景
- 并发上传处理

**性能测试**：
- 大文件（>100MB）上传性能
- 多客户端同时上报
- 服务端存储查询性能

---

## 附录：参考配置

### A.1 完整 Serilog 配置示例

```csharp
private void ConfigureSerilog(IServiceCollection services, IConfiguration configuration)
{
    var appDirectory = AppContext.BaseDirectory;
    var logsDirectory = Path.Combine(appDirectory, "Logs");
    
    if (!Directory.Exists(logsDirectory)) 
        Directory.CreateDirectory(logsDirectory);
    
    // 使用日期子目录结构
    var logFilePath = Path.Combine(logsDirectory, "{YYYY}/{MM}/{DD}/MaterialClient-.log");
    
    var loggerConfig = new LoggerConfiguration()
        .Enrich.FromLogContext()
        .MinimumLevel.Is(ParseLogEventLevel(defaultLevel))
        .MinimumLevel.Override("Microsoft", ParseLogEventLevel(microsoftLevel))
        .MinimumLevel.Override("Microsoft.EntityFrameworkCore", ParseLogEventLevel(efCoreLevel))
        .MinimumLevel.Override("Volo.Abp", ParseLogEventLevel(abpLevel))
        .WriteTo.File(
            logFilePath,
            rollingInterval: RollingInterval.Day,
            rollOnFileSizeLimit: true,
            fileSizeLimitBytes: 50 * 1024 * 1024,  // 50 MB
            retainedFileCountLimit: 30,
            outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}",
            encoding: Encoding.UTF8);
    
    Log.Logger = loggerConfig.CreateLogger();
    
    services.AddLogging(logging =>
    {
        logging.ClearProviders();
        logging.AddSerilog(Log.Logger);
    });
}
```

### A.2 appsettings.json 配置示例（简化版）

**MaterialClient / MaterialClient.Urban**：

```json
{
  "ConnectionStrings": {
    "Default": "Data Source=MaterialClient.db"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Microsoft.Hosting.Lifetime": "Information",
      "Microsoft.EntityFrameworkCore": "Warning",
      "Volo.Abp": "Warning"
    }
  },
  "Log": {
    "Enabled": true,
    "Directory": "Logs",
    "FileSizeLimitMB": 50,
    "RetentionDays": 30,
    "UseDateFolders": true
  },
  "BackgroundServices": {
    "Polling": false
  }
}
```

**UrbanManagement**（保持现有 Serilog 配置，因服务端需要更灵活的日志管理）：

```json
{
  "ConnectionStrings": {
    "Default": "Data Source=UrbanManagement.db"
  },
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft": "Warning",
        "Microsoft.Hosting.Lifetime": "Information",
        "Volo.Abp": "Warning"
      }
    },
    "WriteTo": [
      { "Name": "Console" },
      {
        "Name": "File",
        "Args": {
          "path": "Logs/log-.txt",
          "rollingInterval": "Day",
          "retainedFileCountLimit": 30
        }
      }
    ]
  }
}
```

### A.3 配置项说明

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `Log:Enabled` | bool | true | 是否启用文件日志 |
| `Log:Directory` | string | "Logs" | 日志目录（相对或绝对路径） |
| `Log:FileSizeLimitMB` | int | 50 | 单文件大小限制（MB） |
| `Log:RetentionDays` | int | 30 | 日志保留天数 |
| `Log:UseDateFolders` | bool | true | 是否使用日期子目录（{YYYY}/{MM}/{DD}/） |

---

**文档版本**：1.3
**最后更新**：2026-06-22
**相关文档**：
- `docs/UrbanManagement/windows-server-deploy.md` - 服务端部署手册
- `repos/MaterialClient/src/MaterialClient/MaterialClientModule.cs` - 客户端日志配置
- `repos/MaterialClient/src/MaterialClient.Urban/MaterialClientUrbanModule.cs` - Urban 版本日志配置

**版本历史**：
- v1.3 (2026-06-22)：调整为"服务端按需拉取 + 静态文件缓存"模式，日志文件缓存在服务端供用户下载，由运维人员手动删除，移除自动清理逻辑
- v1.2 (2026-06-22)：更新为"服务端按需拉取日志设计方案"，调整架构为服务端按需拉取模式，移除客户端主动上传逻辑，简化配置项
- v1.1 (2026-06-22)：新增第7章"服务端下载日志设计方案"，详细描述API设计、实体设计和实施架构
- v1.0 (2026-06-22)：初始版本，包含现状调研和标准化建议
