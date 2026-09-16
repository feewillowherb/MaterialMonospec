## ADDED Requirements

### Requirement: Independent headless Hikvision LPR probe application

系统 MUST 提供一个独立的、无 UI 的 Windows 可执行程序，专门用于测试海康 LPR。该程序 MUST NOT 引用 `MaterialClient.Common`、`MaterialClient.UI` 或其它产品模块程序集。实现 MAY 使用非固化、自包含的 HCNetSDK P/Invoke 与结构体定义。

#### Scenario: Process runs without UI

- **WHEN** 运维启动该程序
- **THEN** 程序 SHALL 以无图形界面方式运行（控制台日志即可）
- **AND** SHALL 能在完成初始化后保持长时运行以接收后续报警回调，直到运维停止进程（如 Ctrl+C）

#### Scenario: No product assembly dependency

- **WHEN** 检查诊断项目的项目引用
- **THEN** 项目 MUST NOT 包含对 `MaterialClient.Common`（及其它产品业务程序集）的 `ProjectReference`

### Requirement: JSON configuration for device and local listen endpoint

程序 MUST 从 JSON 配置文件加载设备登录信息与本机监听 endpoint。配置 MUST 至少支持：设备 IP、设备端口、用户名、密码，以及本机监听 **host** 与 **port**。

#### Scenario: Load credentials and listen host port from JSON

- **WHEN** 配置文件包含有效的 device 与 listen（host、port）字段
- **AND** 程序启动
- **THEN** 程序 SHALL 使用该文件中的账号登录设备
- **AND** 若启用监听，SHALL 使用配置的 host 与 port 调用 `NET_DVR_StartListen_V30`（或等价监听 API）

#### Scenario: Missing required config fails fast

- **WHEN** 配置缺少设备 IP 或凭据等必要字段
- **THEN** 程序 SHALL 记录错误并退出（或拒绝进入长时运行），MUST NOT 静默使用空凭据登录

### Requirement: Probe receive path for active capture and callbacks

程序 MUST 能验证主动抓拍触发后是否经报警回调收到车牌/图片数据。默认路径 MUST 支持客户端布防（`NET_DVR_SetupAlarmChan_V50` 或文档约定的等价布防 API）并注册消息回调；监听路径 MUST 可通过配置启用。

#### Scenario: Arm then shoot and log callback

- **WHEN** 配置启用布防
- **AND** 程序完成 Login 与布防
- **AND** 触发 `ContinuousShoot`（启动时一次和/或运维再次触发）
- **THEN** 若收到 `COMM_UPLOAD_PLATE_RESULT` 或 `COMM_ITS_PLATE_RESULT`，程序 SHALL 在日志中输出命令字、车牌文本（可空）以及是否检测到图片数据

#### Scenario: Long-running wait with no callback yet

- **WHEN** 程序已布防或监听成功并进入长时运行
- **AND** 尚无报警回调
- **THEN** 程序 SHALL 保持运行并继续等待
- **AND** SHALL NOT 仅因一时无回调而崩溃退出（除非运维停止或配置为单次限时模式且已到期——若实现单次模式须在配置/帮助中说明）

#### Scenario: Login failure is reported

- **WHEN** 设备登录失败
- **THEN** 程序 SHALL 记录 SDK ErrorCode 与失败原因
- **AND** MUST NOT 假装布防或抓拍成功

### Requirement: Collect diagnostic information during execution

程序在运行期间 MUST 持续收集诊断信息，并写入配置指定的诊断目录（缺省可用相对目录如 `logs`）。收集内容 MUST 至少包括：各步骤时间戳与结果、SDK ErrorCode（失败时）、实际监听 host 与 port、布防句柄（若启用）、报警回调的命令字/车牌/图片字节长度。程序 MUST 同时向控制台输出关键诊断行。

#### Scenario: Step results are persisted while running

- **WHEN** 程序完成 Login、布防或监听、ContinuousShoot 等任一步骤
- **THEN** 程序 SHALL 将带时间戳的步骤结果追加到诊断日志文件
- **AND** SHALL 在控制台打印对应摘要

#### Scenario: Callback diagnostics are collected

- **WHEN** 收到车牌报警回调
- **THEN** 程序 SHALL 记录 lCommand、车牌文本（可空）、图片数据长度（可为 0）
- **AND** MAY 将图片字节保存到诊断目录下的 captures 子目录

#### Scenario: Session diagnostic summary on shutdown

- **WHEN** 运维通过 Ctrl+C 或等价方式停止程序
- **THEN** 程序 SHALL 在退出前刷新或写入一份结构化诊断摘要（如 JSON）
- **AND** 摘要 SHALL 反映本会话已执行步骤与最近回调情况（若有）

### Requirement: Diagnose camera-to-PC inbound TCP

当配置启用入站 TCP 检测时，程序 MUST 在 SDK `StartListen` 占用端口之前，在配置的 listen host/port 上侦听并等待相机（或对端）主动连入。登录成功仅证明 PC→相机，MUST NOT 当作相机→PC 已通。检测失败时 MUST 输出可操作的网络排查提示（同网段隔离/ARP、跨网段路由 ACL、防火墙、报警主机须填具体 PC IP）。

#### Scenario: Inbound TCP check times out

- **WHEN** `inboundTcpCheckSeconds` 大于 0
- **AND** 等待窗口内无任何入站 TCP 连接
- **THEN** 程序 SHALL 将 `inbound_tcp` 步骤记为 FAIL
- **AND** SHALL 提示相机无法主动建立 TCP 到 PC 及交换机隔离/路由/防火墙等原因

#### Scenario: Inbound TCP connection accepted

- **WHEN** 入站检测窗口内接受到来自远端的 TCP 连接
- **THEN** 程序 SHALL 将 `inbound_tcp` 步骤记为 PASS
- **AND** SHALL 记录远端地址
