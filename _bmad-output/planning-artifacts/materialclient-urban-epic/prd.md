# PRD：MaterialClient.Urban 城市管理称重桌面端

**Epic ID**: `materialclient-urban-epic`  
**版本**: 0.6  
**状态**: 规划完成，待 OpenSpec 衔接  
**影响子仓库**: MaterialClient（新桌面端 `MaterialClient.Urban`）、UrbanManagement

---

## 1. 背景与问题

MaterialClient 面向工业材料称重，具备运单匹对、实时授权、多页面 UI 等能力。城市管理场景（UrbanManagement）需要 **UrbanMode = 201 专用桌面端**：在**单一称重界面**内完成采集与列表查看，将 **WeighingRecord** 上报服务端，**不**做运单匹对、**不**提供登录页与授权页；静态授权文件在**启动时后台校验**（首期仅日志占位）。

UrbanManagement 需掌握各采集端的**设备状态、软件运行状态与错误日志**。

**UI 布局草稿**：`repos/MaterialClient/MaterialClient.Demo/Views/WeighingSystemWindow.axaml`（详见 `ui-layout-reference.md`）。

## 2. 目标用户与场景

| 角色 | 场景 |
|------|------|
| 现场称重操作员 | 打开应用即进入唯一主界面，查看实时重量与历史称重记录 |
| 平台运维 | 在 UrbanManagement 查看设备在线/异常、客户端版本与错误日志 |
| 开发/集成 | ProductCode 5030、WeighingMode 201 标识 Urban 产品线 |

## 3. 产品目标

1. 新增 **MaterialClient.Urban** — **UrbanMode = 201 专用 Avalonia 桌面应用**（非 Generic Host / 非 headless），配置体系与 MaterialClient 类似。
2. **仅一个主界面**（称重系统窗），**无登录页、无授权页**；启动后直接显示主窗口。
3. 仅处理 **WeighingRecord**，**不**配对 waybill。
4. 上传称重记录至 **UrbanManagement**。
5. **ProductCode = 5030**、**WeighingMode = 201（UrbanMode）**。
6. 静态授权：启动时读文件 + 日志占位，**无授权相关 UI**。
7. UrbanManagement 接收设备/软件状态与错误日志。

## 4. 非目标（Out of Scope — 首期）

- 多窗口导航、登录 Window、授权配置 Window
- 用户登录、Session、Token 刷新、实时授权 API 轮询
- 静态授权文件完整加解密 UI 或签名校验实现（仅后台日志）
- Waybill 同步、匹对、推荐、SolidWaste 等 MaterialClient 专有流程
- 上传除 WeighingRecord 以外的实体

## 5. 功能需求

### FR-1 桌面端与配置

- **FR-1.1** 新增 `MaterialClient.Urban` Avalonia 可执行项目，引用共享 Domain/Application/Infrastructure。
- **FR-1.2** 默认 **ProductCode = 5030**、**WeighingMode = 201（UrbanMode）**。
- **FR-1.3** 主界面布局以 `WeighingSystemWindow.axaml` 为草稿落地（标题栏、重量区、记录列表、照片侧栏、设备状态栏）。
- **FR-1.4** 配置：UrbanManagement 基址、授权文件路径、上传 Worker 周期与重试等。
- **FR-1.5** **设备 ID（首期占位）**：定义 **`IDeviceIdentityProvider`（或等价命名）** 抽象，实现类 **暂不解析机器/硬件**；`GetDeviceId()`（或异步变体）**返回配置中的固定 `Guid` 字符串**（全客户端可相同，用于打通联调）。**未来缓解（非首期）**：持久化安装 ID、机器/主板指纹、与 UrbanManagement **设备注册** API 对齐、多实例唯一性校验；届时替换实现并迁移已上报数据策略在独立 change 中处理。

### FR-2 授权（静态文件，无 UI）

- **FR-2.1** 应用启动时（`App` / 模块初始化）读取 `Urban:LicenseFilePath`。
- **FR-2.2** 缺失或不可读 → Error 日志；存在 → Information 日志。
- **FR-2.3** **不**提供授权页面；**不**在每次上传时做实时授权。

### FR-3 称重与数据范围

- **FR-3.1** 仅 **WeighingRecord**；**不**调用 waybill 匹对。
- **FR-3.2** 记录携带 ProductCode 5030、WeighingMode 201。
- **FR-3.3** 主界面列表绑定本地记录；称重完成后上传 UrbanManagement。
- **FR-3.4** 称重触发与流程复用 **`MaterialClient.Common` 中既有 `AttendedWeighing` 相关逻辑**（服务/事件与有人值守称重一致路径）；UrbanMode 下按需**扩展或分支**（例如跳过运单匹对），避免在 Urban 中平行重写一套称重状态机。

### FR-4 上传（客户端）

- **FR-4.1** REST 上传 WeighingRecord DTO。
- **FR-4.2** 请求含 DeviceId、ClientVersion 等元数据。
- **FR-4.3** 上传调度与主程序 **Material 后台**一致：采用 **`MaterialClient.Backgrounds` 中与 `PollingBackgroundService` 相同的技术形态** — Volo.Abp **`AsyncPeriodicBackgroundWorkerBase`**，在 **`IUnitOfWorkManager`** 开启的独立 UOW 内扫描待上传记录并调用 HTTP 客户端；**不以 UI 线程作为主上传路径**。定周期由配置项控制（可与主程序 10 分钟量级对齐或单独 `Urban` 节）；单条失败重试策略在 OpenSpec design 中细化（可与现有 Polly/日志模式对齐）。

### FR-5 UrbanManagement

- **FR-5.1** 接收并持久化 WeighingRecord。
- **FR-5.2** 设备心跳/状态 API。
- **FR-5.3** 错误日志 API。
- **FR-5.4** 管理端可查询设备与日志。

## 6. 非功能需求

| 类别 | 要求 |
|------|------|
| UI | 单主窗口；Avalonia + ReactiveUI；与 MaterialClient 视觉风格一致（Demo 草稿） |
| 可靠性 | 上传失败重试 |
| 安全 | 无登录 UI；静态授权后台占位 |
| 部署 | 独立安装包，与 MaterialClient 主程序分离 |

## 7. 成功标准

- [ ] 启动后**直接进入**唯一主界面（无登录/授权页）。
- [ ] 界面布局与 `WeighingSystemWindow` 草稿一致（允许精简顶栏菜单）。
- [ ] 产生 UrbanMode 称重记录并上传成功。
- [ ] 底栏设备状态可见；UrbanManagement 可查设备与错误日志。
- [ ] MaterialClient 主程序无回归。

## 8. 假设与依赖

- Demo 中 `WeighingSystemWindow` 可迁移为 Urban 正式 View + ViewModel。
- 共享 `WeighingRecord` 实体与称重设备基础设施。
- Urban 称重行为以 **`MaterialClient.Common` 的 AttendedWeighing 既有实现**为基线；若 UrbanMode 与有人值守差异无法仅靠配置消除，在 Common 或 Urban 宿主内做**最小扩展**（接口/策略），不复制大段业务逻辑。
- **UrbanManagement 表 `Urban_WeighingRecord`（及上传 DTO）**：BMAD 阶段**不做逐列定稿**；**默认与 MaterialClient 本地 `WeighingRecord` 表结构一致或高度相似**（列名、类型、可空性以 MaterialClient 解决方案内 **实体定义 + EF Core Fluent / 迁移** 为蓝本）。OpenSpec `design.md` / `specs` 中须**显式对照** MaterialClient 源表后再冻结迁移脚本。

## 9. 开放问题

| ID | 问题 | 状态 |
|----|------|------|
| OQ-1 | 上传实时 vs 批量？ | **已闭合**：与主程序 **Material 后台**相同机制 — 参考 **`PollingBackgroundService`**（`AsyncPeriodicBackgroundWorkerBase` + `WithUow` + 定周期执行）；Urban 仅在该 Worker 内处理 **WeighingRecord** 的 Pending 上传，不包含物料/运单等其它同步步骤。 |
| OQ-2 | 称重触发方式？ | **已闭合**：复用 **`MaterialClient.Common` 中 AttendedWeighing 既有逻辑**（重量流、记录落库、事件总线等与有人值守对齐）；主界面 ViewModel 绑定重量区与列表；必要时为 UrbanMode **扩展**（如禁用 waybill 分支）。不采用独立 headless 管线。 |
| OQ-3 | 设备 ID 来源？ | **已闭合（首期占位）**：提供 **`IDeviceIdentityProvider`**（名称以 OpenSpec 为准），**不**做机器指纹/注册表等实现；**返回 `appsettings` 中配置的固定 `Guid`**。多安装点会共用同一逻辑 ID — **已知局限**。**未来缓解**：持久化设备密钥、硬件/OS 绑定、`IDeviceIdentityProvider` 真实实现、UrbanManagement 设备建档与冲突检测（另开 change）。 |
| OQ-4 | 服务端表结构？ | **已闭合（原则）**：新建表 **`Urban_WeighingRecord`**（Urban 专用，不写入 `Gov_*`）。**列级设计不在 BMAD 定稿** — **以 MaterialClient 中 `WeighingRecord` 持久化形态为参考**（实体 + `*DbContext` / `OnModelCreating` / SQLite 实际列），服务端表 **默认镜像或子集对齐**；额外可加 `ReceivedAt`、`RawPayload` 等监管字段（OpenSpec 列出）。若 MaterialClient **实体或映射演进**，Urban 侧通过独立 change 跟进迁移。 |

## 10. Epic 映射

见 `epic-traceability.md`。
