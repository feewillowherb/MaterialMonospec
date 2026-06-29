# UrbanManagement — Windows Server 发布流程手册

> 面向将 `UrbanManagement` 部署到 Windows Server 的运维与开发人员。

**版本**: 1.1  
**最后更新**: 2026-06-18  
**适用项目**: `repos/UrbanManagement`（.NET 10 / ABP / Blazor Server / SQLite）

---

## 目录

- [1. 应用概览](#1-应用概览)
- [2. 前置条件](#2-前置条件)
- [3. 发布构建](#3-发布构建)
  - [3.1 使用发布脚本（推荐）](#31-使用发布脚本推荐)
  - [3.2 手动 dotnet publish](#32-手动-dotnet-publish)
  - [3.3 发布产物](#33-发布产物)
- [4. 部署方式](#4-部署方式)
  - [4.1 IIS（推荐）](#41-iis推荐)
  - [4.2 Windows 服务 + Kestrel](#42-windows-服务--kestrel)
- [5. 生产配置](#5-生产配置)
- [6. 数据与持久化](#6-数据与持久化)
- [7. 网络与防火墙](#7-网络与防火墙)
- [8. 升级流程](#8-升级流程)
- [9. 健康检查](#9-健康检查)
- [10. 故障排查](#10-故障排查)

---

## 1. 应用概览

| 项 | 说明 |
|----|------|
| 宿主项目 | `src/UrbanManagement.App/UrbanManagement.App.csproj` |
| 运行时 | .NET 10.0 |
| UI | Blazor Server（依赖 WebSocket / SignalR） |
| 数据库 | SQLite（默认文件 `UrbanManagement.db`） |
| 附件存储 | `StorageOptions:FilesPhysicalPath`（默认 `{ContentRoot}/Uploads/`） |
| 启动行为 | 自动执行 EF 迁移；自动创建附件目录 |

对外主要端点：

| 路径 | 用途 |
|------|------|
| `/` | Blazor Web 管理界面 |
| `/_framework/blazor.server.js` | Blazor Server 运行时 |
| `/hubs/devicestatus` | 设备状态 SignalR Hub |
| `/api/app/*` | ABP 自动生成的 REST API |

---

## 2. 前置条件

### 2.1 构建机（开发机或 CI）

- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- 能访问 `repos/UrbanManagement` 源码

### 2.2 Windows Server

- Windows Server 2016 或更高版本（建议 2019/2022）
- 若采用 **IIS 托管**：
  - 安装 [**.NET 10 Hosting Bundle**](https://dotnet.microsoft.com/download/dotnet/10.0)（含 ASP.NET Core Runtime 与 IIS 模块）
  - IIS 中启用 **WebSocket 协议**（Blazor Server 必需）
- 若采用 **框架依赖发布**（`--self-contained false`）：服务器需安装 .NET 10 Runtime
- 若采用 **自包含发布**（`--self-contained true`）：服务器无需单独安装 Runtime

### 2.3 磁盘与权限

建议将程序与数据分离：

```
C:\Apps\UrbanManagement\          # 程序目录（可覆盖升级）
D:\Data\UrbanManagement\
  ├── UrbanManagement.db          # SQLite 数据库
  ├── Uploads\                    # 称重附件
  └── Logs\                       # 若日志写在应用目录，需一并备份
```

运行身份（IIS 应用池或 Windows 服务账号）对数据库文件、Uploads、Logs 目录需具备 **读写** 权限。

---

## 3. 发布构建

推荐使用子仓库脚本 **`repos/UrbanManagement/scripts/publish.ps1`**；也可直接调用 `dotnet publish`。

### 3.1 使用发布脚本（推荐）

脚本路径：`repos/UrbanManagement/scripts/publish.ps1`  
默认输出：`repos/UrbanManagement/dist/publish/`（已在子仓库 `.gitignore` 中忽略）

在 **`repos/UrbanManagement`** 目录下执行：

```powershell
# 默认：Release、框架依赖 (win-x64)、输出到 dist/publish
.\scripts\publish.ps1

# 发布前清空输出目录
.\scripts\publish.ps1 -Clean

# 自包含（服务器无需单独安装 .NET Runtime）
.\scripts\publish.ps1 -SelfContained

# 自包含并打 zip（zip 位于 dist/ 下，带时间戳文件名）
.\scripts\publish.ps1 -SelfContained -Zip

# 指定输出路径
.\scripts\publish.ps1 -OutputDir D:\Artifacts\UrbanManagement -Clean
```

从 **MaterialMonospec 根目录** 也可调用：

```powershell
.\repos\UrbanManagement\scripts\publish.ps1 -Clean
```

#### 参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-Configuration` | `Release` | 构建配置（`Release` / `Debug`） |
| `-OutputDir` | `dist/publish` | 发布输出目录（相对子仓库根目录） |
| `-Runtime` | `win-x64` | 目标 RID |
| `-SelfContained` | 关 | 自包含发布；开启后产物含 `UrbanManagement.App.exe` |
| `-Zip` | 关 | 在 `dist/` 下生成 zip 归档 |
| `-Clean` | 关 | 发布前删除 `-OutputDir` |

#### 脚本行为

1. 检查 `dotnet` CLI 与项目文件是否存在  
2. 执行 `dotnet publish`  
3. 校验关键产物：`UrbanManagement.App.dll`、`web.config`、`appsettings.json`、`wwwroot`  
4. 打印服务器部署后续步骤（IIS / 配置 `appsettings.secret.json` 等）

自包含发布时，脚本结束提示会说明：IIS 的 `web.config` 需将 `processPath` 改为 `.\UrbanManagement.App.exe`、`arguments` 留空。

### 3.2 手动 dotnet publish

若不使用脚本，可在 MaterialMonospec 根目录或 `repos/UrbanManagement` 下手动执行。

**框架依赖**（适合已安装 Hosting Bundle 的服务器）：

```powershell
$project = "repos\UrbanManagement\src\UrbanManagement.App\UrbanManagement.App.csproj"
$out     = "repos\UrbanManagement\dist\publish"

dotnet publish $project `
  -c Release `
  -o $out `
  --runtime win-x64 `
  --self-contained false
```

**自包含**（服务器无 .NET 环境时）：

```powershell
dotnet publish $project `
  -c Release `
  -o $out `
  --runtime win-x64 `
  --self-contained true
```

### 3.3 发布产物

`dotnet publish` 输出目录中应包含：

- `UrbanManagement.App.dll` / `UrbanManagement.App.exe`
- `web.config`（IIS 反向代理配置，inprocess 模式）
- `appsettings.json`
- `wwwroot\` 静态资源
- 依赖 DLL 与 `runtimes\`（含 SQLite 原生库）

将发布目录（默认 `dist/publish`）整体复制到服务器目标路径（如 `C:\Apps\UrbanManagement`）。

---

## 4. 部署方式

### 4.1 IIS（推荐）

适用于需要统一 80/443 入口、域名与证书管理的生产环境。

#### 步骤

1. 将发布目录复制到服务器，例如 `C:\Apps\UrbanManagement`
2. 在发布目录旁或应用根目录放置 **`appsettings.secret.json`**（见 [第 5 节](#5-生产配置)）
3. 打开 **IIS 管理器** → 新建网站或应用程序：
   - **物理路径**：`C:\Apps\UrbanManagement`
   - **绑定**：按需配置 HTTP/HTTPS 与主机名
4. 配置 **应用程序池**：
   - **.NET CLR 版本**：**无托管代码**
   - **托管管道模式**：集成
5. 确认已安装 Hosting Bundle 且站点已启用 **WebSocket**
6. 启动网站

发布生成的 `web.config` 示例：

```xml
<aspNetCore processPath="dotnet"
            arguments=".\UrbanManagement.App.dll"
            hostingModel="inprocess" />
```

自包含发布时，可将 `processPath` 改为 `.\UrbanManagement.App.exe`，`arguments` 留空。

#### IIS 请求体大小

应用内已将 Kestrel `MaxRequestBodySize` 设为 16 MB（Blazor 图片上传）。若 IIS 层限制上传，需在 `web.config` 的 `system.webServer` 下增加：

```xml
<security>
  <requestFiltering>
    <requestLimits maxAllowedContentLength="16777216" />
  </requestFiltering>
</security>
```

### 4.2 Windows 服务 + Kestrel

适用于内网单机、不依赖 IIS 的场景。

```powershell
# 1. 复制发布目录到 C:\Apps\UrbanManagement

# 2. 配置环境变量（系统级）
setx ASPNETCORE_URLS "http://*:5080" /M
setx DOTNET_ENVIRONMENT "Production" /M

# 3. 注册 Windows 服务（路径按实际调整）
sc.exe create UrbanManagement `
  binPath="C:\Apps\UrbanManagement\UrbanManagement.App.exe" `
  start=auto `
  DisplayName="UrbanManagement Web"

sc.exe start UrbanManagement
```

也可使用 NSSM 等工具将进程注册为服务。确保防火墙放行监听端口（如 5080）。

---

## 5. 生产配置

### 5.1 配置文件优先级

应用启动时读取：

1. `appsettings.json`（随发布包自带，勿在其中存放生产密钥）
2. **`appsettings.secret.json`**（可选，存在则覆盖前者，**推荐生产使用**）

`Program.cs` 会在 `ContentRoot` 下自动加载 `appsettings.secret.json`。

### 5.2 必改配置项

复制 [appsettings.secret.json.example](./appsettings.secret.json.example) 到服务器发布目录，改名为 `appsettings.secret.json` 后修改：

| 配置节 | 说明 |
|--------|------|
| `ConnectionStrings:Default` | SQLite 路径，建议使用数据盘绝对路径 |
| `StorageOptions:FilesPhysicalPath` | 附件根目录（绝对路径） |
| `StorageOptions:GovAddress` | 政府平台 API 基地址 |
| `PublicApiServiceAuth` | BasePlatform PublicApi 连接（`BaseUrl`、`ApiKey`，项目同步与 JWT 签发共用） |
| `BasePlatformSync` | GovProject 定时拉取（`Enabled`、`PullIntervalMinutes`、`PageSize`） |
| `BackgroundServices:Polling` | `true` 时启动称重数据上报轮询 |
| `Jwt` | **生产必须更换**公私钥，勿使用开发环境密钥 |
| `SignalR:AllowedOrigins` | MaterialClient 等桌面客户端来源；默认仅 localhost |

### 5.3 后台任务

`GovSyncBackgroundWorker` 在以下任一条件为真时启动：

- `BackgroundServices:Polling` = `true`
- `BasePlatformSync:Enabled` = `true`

生产环境按业务需要开启，并确保出站网络可达 `GovAddress` 与 `PublicApiServiceAuth:BaseUrl`。

---

## 6. 数据与持久化

### 6.1 数据库迁移

应用启动时在 `UrbanManagementAppModule` 中自动执行 `Database.MigrateAsync()`，**一般无需手动执行** `dotnet ef database update`。

首次启动会在 `ConnectionStrings:Default` 指定路径创建 `UrbanManagement.db`。

### 6.2 附件

附件保存在 `StorageOptions:FilesPhysicalPath` 解析后的目录（默认 `{ContentRoot}/Uploads/{buildLicenseNo}/`）。启动日志中应出现：

```text
Attachment storage root resolved to ...
```

### 6.3 日志

Serilog 默认写入应用目录下 `Logs/log-YYYYMMDD.txt`，保留 30 天。升级前建议备份近期日志。

### 6.4 备份建议

定期备份：

- `UrbanManagement.db`
- `Uploads\` 整个目录
- `appsettings.secret.json`（安全存放，勿入公开仓库）

---

## 7. 网络与防火墙

### 7.1 入站（客户端 → 服务器）

放行 Web 站点端口（80/443 或 Kestrel 自定义端口）。Blazor Server 需要 **WebSocket** 在同一站点可用。

MaterialClient 等客户端需能访问：

- HTTP(S) 站点根路径
- SignalR / Blazor 协商端点
- `/hubs/devicestatus`

### 7.2 出站（服务器 → 外部）

- `StorageOptions:GovAddress` — 政府平台同步
- `BasePlatformSync:BaseUrl` — 项目目录拉取

### 7.3 外网 CDN 依赖

`_Host.cshtml` 当前从 `cdn.jsdelivr.net` 加载 ECharts。若服务器**无法访问外网**，图表功能会异常，需将 ECharts 改为 `wwwroot` 本地静态资源（属后续优化项）。

---

## 8. 升级流程

```text
1. 通知用户 / 停站点或服务
2. 备份 UrbanManagement.db、Uploads、appsettings.secret.json
3. 在构建机执行 `.\scripts\publish.ps1 -Clean`（或 `dotnet publish`）
4. 覆盖服务器程序目录（保留 appsettings.secret.json 与数据目录）
5. 启动站点或服务
6. 检查 Logs：迁移成功、存储目录初始化成功
7. 执行健康检查（见下节）
```

SQLite 为单文件库，**不支持多实例同时写同一库文件**；生产环境应单实例部署，勿对同一数据库做简单负载均衡多副本。

---

## 9. 健康检查

部署或升级后确认：

- [ ] 浏览器访问首页返回 200，Blazor 页面可加载
- [ ] 日志含 `Database migration completed successfully`
- [ ] 日志含 `Attachment storage root resolved to ...`
- [ ] 若有 MaterialClient：设备可连接 `/hubs/devicestatus`
- [ ] 若开启同步：日志无持续的 Gov / BasePlatform 连接错误
- [ ] 上传一张称重附件，确认 `Uploads` 目录有文件落盘

可选 API 探测（ABP 自动 API 路径以实际为准）：

```text
GET https://<host>/api/app/gov-project
```

---

## 10. 故障排查

| 现象 | 可能原因 | 处理 |
|------|----------|------|
| 502.5 / 应用无法启动 | 未装 Hosting Bundle 或 Runtime 版本不对 | 安装 .NET 10 Hosting Bundle，重启 IIS |
| Blazor 连接断开后无法恢复 | IIS 未启用 WebSocket | 服务器管理器 → Web 服务器 → 应用程序开发 → 勾选 WebSocket |
| 数据库迁移失败 | 运行身份无写权限 | 检查应用池/服务账号对 `.db` 所在目录的写权限 |
| 附件上传失败 | Uploads 无写权限或请求体超限 | 赋权数据目录；检查 IIS `maxAllowedContentLength` |
| MaterialClient 连不上 Hub | CORS / SignalR Origins 未配置 | 在 `appsettings.secret.json` 中配置 `SignalR:AllowedOrigins` |
| 政府同步失败 | `GovAddress` 错误或出站网络不通 | 检查 URL、防火墙出站、对端服务状态 |
| 图表不显示 | 无法访问 jsdelivr CDN | 改用本地 ECharts 或放行 CDN 域名 |

更多 Monospec 通用问题见 [troubleshooting.md](../troubleshooting.md)。

---

## 附录：发布命令速查

```powershell
# 推荐：在 repos/UrbanManagement 下
.\scripts\publish.ps1 -Clean

# 自包含 + zip
.\scripts\publish.ps1 -SelfContained -Zip -Clean

# 手动 dotnet publish（MaterialMonospec 根目录）
dotnet publish repos/UrbanManagement/src/UrbanManagement.App/UrbanManagement.App.csproj `
  -c Release `
  -o repos/UrbanManagement/dist/publish `
  --runtime win-x64 `
  --self-contained false
```

生产配置模板：[appsettings.secret.json.example](./appsettings.secret.json.example)
