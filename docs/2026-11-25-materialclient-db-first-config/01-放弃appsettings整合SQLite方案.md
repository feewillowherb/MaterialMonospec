# 01 - 放弃 `appsettings`、整合进 SQLite DB 方案

知识状态：现状核对为 `CONFIRMED`（基于 `MaterialClient` 4 个宿主的 `appsettings*.json` 与 `SettingsEntity.cs`）；技术路线与存表选型为 `PENDING_VALIDATION`（待后续立项 OpenSpec 时拍板细节）。生命周期：`ACTIVE`。

---

## 1. 现状对比：`appsettings.json` vs 数据库 `Settings`

| 维度 | `appsettings.json`（现行启动文件） | `Settings`（SQLite `SettingsEntity`） |
|------|-----------------------------------|---------------------------------------|
| **加载时机** | 进程启动最早期（DI、日志、EF/SQLite 初始化前） | 程序启动、SQLite 就绪后 |
| **存放内容** | 连接串、日志级别、服务端地址、`Jwt:PublicKey`、静态字典（街道/固废类型）、异常阈值、`Client:Id` 等 | 地磅串口/型号、LPR/相机 IP 与账号、语音/打印、称重与业务对接设置 |
| **修改方式** | 打包或人工文本编辑（易断电损坏/语法报错炸启动） | 客户端 UI「设置」保存，走 SQLite 事务（不出现文本语法损坏） |
| **反序列化容错** | 无兜底，JSON 损坏直接抛异常终止启动 | `SettingsEntity` 各 JSON 属性均自带 `try/catch` 回退默认值 |

---

## 2. 配置项三分法归口（适用全部 4 个宿主）

| 归口类别 | 典型配置项 | 2.0 落点 | 说明 |
|----------|------------|----------|------|
| **A. 固定引导与不可变常量** | SQLite 固定数据路径（如 `C:\ProgramData\MaterialClient\<Product>\MaterialClient.db`）、`Jwt:PublicKey`、静态字典（`Streets`、`SolidWasteTypes`、`LowPriorityPlateColors`）、SignalR 重连参数、`MinimalWebHost` | **代码内置常量** | 解决启动引导“鸡生蛋”问题，程序启动不依赖外部文件，杜绝公钥与常量被误改。 |
| **B. 运行时可调与环境配置** | 服务端 `BaseUrl`（`SignalR` 地址自动派生）、日志级别与保留天数、后台轮询与清理参数、称重异常阈值（`UrbanAnomalyDetection`）、以及既有全部硬件/业务设置 | **SQLite DB** | 走 SQLite 事务持久化，支持 UI 设置页修改及未来服务端统一下发；版本目录切换（Velopack OTA）时数据外置零丢失。 |
| **C. 研发/测试临时覆写** | 切换 138 实验室地址、临时调 Debug 日志 | **命令行参数 / 环境变量**（可选） | 正式工控机零外部文件；研发测试按需传参，不污染发布包。 |

> 注：`Client:Id` 统一由确定性机器标识自动生成，不再作为手工配置项。

---

## 3. 启动早期读 DB 机制（解决「鸡生蛋」问题）

ABP 模块与日志系统在 `Host.CreateApplicationBuilder()` 阶段即依赖 `IConfiguration`，此时 EF Core 尚未初始化。采用轻量裸读机制即可无侵入衔接：

1. **自定义 `SqliteConfigurationProvider`（基于 `Microsoft.Data.Sqlite` 只读查询）**：
   - 配置加载优先级（从低到高）：
     1. **代码内置默认值**（`AddInMemoryCollection`）—— 裸机空目录也能正常启动；
     2. **SQLite DB 配置**（若固定路径下 `.db` 已存在，启动时只读加载；若库不存在、表未建或单条记录解析失败，**捕获异常并回退内置默认值，绝不阻塞启动**）；
     3. **环境变量 + 命令行参数**（仅开发/测试临时覆写）。
2. **对现有业务代码零侵入**：
   - 所有既有依赖 `IConfiguration` / `IOptions<T>` 的服务保持原样读取，无感知切换；
   - 运行时经 UI 修改并写入 SQLite 后，同步触发内存配置刷新。

---

## 4. DB 存储结构选型（待立项时拍板）

| 选项 | 表结构 | 优点 | 权衡 |
|------|--------|------|------|
| **方案 1：复用 `SettingsEntity`** | 沿用 `repos/MaterialClient/src/MaterialClient.Common/Entities/SettingsEntity.cs` 的强类型 JSON 列（如 `SystemSettingsJson` / `UrbanSettingsJson`） | 不新增表，复用现有 `ISettingsService` 与容错反序列化 | 启动 provider 需解析对应 JSON 列 |
| **方案 2：新增 `AppConfigs (Key TEXT PK, Value TEXT)` 扁平 KV 表** | 直接存 `UrbanManagement:BaseUrl`、`Log:Level` 等 `IConfiguration` 键 | `SqliteConfigurationProvider` 零 JSON 解析、一行 SQL 映射到 `IConfiguration`；未来 Admin 远程下发单项配置最直接 | 多一张极简配置表 |

---

## 5. 与现有现场（1.0）及 2.0 推送更新的衔接

1. **存量现场一次性平滑导入**：新版本首次启动时，若 DB 中尚未写入服务端地址等原 `appsettings` 配置，且检测到旧目录存在 `appsettings.json` / `appsettings.secret.json`，可执行一次**幂等导入进 SQLite**；导入完成后彻底脱离外部 `appsettings` 依赖。
2. **与 2.0 OTA / 防变砖协同**：
   - 外部不再依赖 `appsettings.json` 后，「配置 JSON 损坏导致软件起不来」整类故障从根源消除；
   - 配合 2.0 的**安全恢复模式（Safe Mode）**与 **Velopack 启动健康标记回滚**，即使新版本代码存在初始化缺陷，也能自动回退上一版本或维持心跳/日志/更新通道存活。
