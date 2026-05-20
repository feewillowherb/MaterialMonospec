# PRD：MaterialClient.Urban 城市管理称重上传

**Epic ID**: `materialclient-urban-epic`  
**版本**: 0.1（需求初稿）  
**状态**: 规划完成，待 OpenSpec 衔接  
**影响子仓库**: MaterialClient（新宿主 `MaterialClient.Urban`）、UrbanManagement

---

## 1. 背景与问题

MaterialClient 面向工业材料称重，具备运单匹对、实时授权、完整 UI 等能力。城市管理场景（UrbanManagement）需要**轻量桌面采集端**：仅采集称重记录并上报服务端，**不**做运单匹对、**不**要求登录与实时授权校验，授权通过**静态授权文件**在启动时校验（首期仅日志占位）。

UrbanManagement 需掌握各采集端的**设备状态、软件运行状态与错误日志**，用于运维与监管。

## 2. 目标用户与场景

| 角色 | 场景 |
|------|------|
| 现场称重操作员 | 在无完整 MaterialClient UI 的前提下完成称重，数据自动上传 |
| 平台运维 | 在 UrbanManagement 查看设备在线/异常、客户端版本与错误日志 |
| 开发/集成 | 通过 ProductCode、WeighingMode 区分 Urban 产品线，与现有 MaterialClient 配置模式对齐 |

## 3. 产品目标

1. 新增 **MaterialClient.Urban** 可执行宿主，配置体系与 MaterialClient 类似（共享核心库、ABP、SQLite 等模式）。
2. 仅处理 **WeighingRecord** 称重记录，**不**配对 waybill。
3. 将称重记录上传至 **UrbanManagement** API 并持久化。
4. 使用 **ProductCode = 5030**、**WeighingMode = 201（UrbanMode）** 标识 Urban 产品线。
5. **首期无 UI 页面**；**无登录**；启动时读取并校验静态授权文件（**实现阶段仅打印日志，不阻断或不做真实密码学校验**）。
6. UrbanManagement 提供设备/软件状态与错误日志的**接收与展示能力**（首期 API + 存储 + 管理端可查；具体 LayUI 页面可后续迭代）。

## 4. 非目标（Out of Scope — 首期）

- MaterialClient.Urban 的 Avalonia 业务 UI（菜单、称重界面、设置页等）
- 用户登录、Session、Token 刷新、实时授权 API 轮询
- 静态授权文件的完整加解密/签名校验实现（仅校验文件存在性与日志输出）
- Waybill 同步、匹对、推荐、SolidWaste 等 MaterialClient 专有流程
- 上传除 WeighingRecord 以外的实体（Provider、Material、Waybill 等）

## 5. 功能需求

### FR-1 宿主与配置

- **FR-1.1** 解决方案中新增 `MaterialClient.Urban` 项目，引用与 MaterialClient 相同的核心层（Domain、Application、Infrastructure 等按架构切片落地），独立 `appsettings`、启动入口。
- **FR-1.2** 默认 **ProductCode = 5030**；称重业务模式为 **WeighingMode = 201（UrbanMode）**。
- **FR-1.3** 配置项包含 UrbanManagement 基址、设备标识、授权文件路径、上传重试策略等（与 MaterialClient 配置风格一致）。

### FR-2 授权（静态文件）

- **FR-2.1** 应用启动时读取配置的静态授权文件路径。
- **FR-2.2** 若文件缺失或格式不可读，记录 **Error** 级日志；首期**不**实现完整校验逻辑，**不**要求弹出 UI。
- **FR-2.3** 若文件存在，记录 **Information** 级日志（含路径、读取成功），**不**在每次上传时重复实时授权。

### FR-3 称重与数据范围

- **FR-3.1** 仅创建/维护本地 **WeighingRecord**（及称重流程必需的最小依赖，如设备通道、重量读数），**不**调用 waybill 匹对服务。
- **FR-3.2** WeighingRecord 在 UrbanMode 下写入时携带 ProductCode 5030、WeighingMode 201。
- **FR-3.3** 称重完成后（或按后台定时）将记录**上传**至 UrbanManagement；失败可重试并写本地同步状态（具体字段在架构/切片 design 中定）。

### FR-4 上传协议（客户端）

- **FR-4.1** 客户端调用 UrbanManagement 提供的 REST API（ABP 应用服务或 Controller），payload 以 **WeighingRecord** 契约为主。
- **FR-4.2** 请求携带设备 ID、客户端版本、时间戳等元数据，便于服务端关联设备状态。

### FR-5 UrbanManagement 接收与运维可见性

- **FR-5.1** 提供 **接收 WeighingRecord** 的 API，校验必填字段并持久化（新表或扩展现有 Gov 相关模型，在架构中决策）。
- **FR-5.2** 提供 **设备心跳/状态** 上报 API：设备在线、软件版本、最后活动时间。
- **FR-5.3** 提供 **错误日志** 上报 API：级别、消息、堆栈（可选）、关联设备。
- **FR-5.4** 管理端可查询各设备最近状态与错误日志列表（首期可为 API + 简单列表页或复用现有 LayUI 表格模式）。

## 6. 非功能需求

| 类别 | 要求 |
|------|------|
| 可靠性 | 上传失败本地队列/重试，避免静默丢数 |
| 可观测性 | 客户端与 UrbanManagement 双侧结构化日志 |
| 安全 | 首期无登录；后续静态授权可升级为签名校验，API 可增加设备密钥 |
| 兼容 | 不破坏现有 MaterialClient ProductCode/WeighingMode 枚举语义 |
| 部署 | MaterialClient.Urban 可独立安装；UrbanManagement 独立部署 API |

## 7. 成功标准

- [ ] `MaterialClient.Urban` 可启动，日志显示授权文件检查结果（占位实现）。
- [ ] 产生一条 UrbanMode 称重记录并成功上传至 UrbanManagement。
- [ ] UrbanManagement 可查询该记录及对应设备状态、至少一条错误日志样本。
- [ ] 现有 MaterialClient 主程序行为无回归（独立宿主）。

## 8. 假设与依赖

- MaterialClient 代码库中已存在 `WeighingRecord` 实体及称重基础设施，Urban 宿主通过**组合/复用**而非复制业务逻辑。
- UrbanManagement 已具备 ABP + EF Core + SQLite 基础（见 `urbanmanagement-initialization` 归档变更）。
- 网络为客户端可访问 UrbanManagement 的内网/专线环境。

## 9. 开放问题（建议在 OpenSpec design 阶段闭合）

| ID | 问题 | 建议决策方向 |
|----|------|----------------|
| OQ-1 | WeighingRecord 上传是实时还是批量？ | 首期：创建后异步单次上传 + 失败重试 |
| OQ-2 | 无 UI 下如何触发称重？ | 首期：控制台/后台服务模拟或复用最小 headless 称重管线；或保留内部 API 供集成测试 |
| OQ-3 | 设备 ID 来源？ | 配置文件 + 机器名哈希，与 UrbanManagement 设备注册表对齐 |
| OQ-4 | GovSyncData 与 WeighingRecord 关系？ | 新建 `UrbanWeighingRecord` 表映射上传字段，避免污染 Gov 历史语义 |

## 10. Epic 与 OpenSpec 切片映射（预览）

见同目录 `epic-traceability.md`。
