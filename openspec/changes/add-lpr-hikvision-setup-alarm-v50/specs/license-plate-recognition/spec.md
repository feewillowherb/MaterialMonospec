## ADDED Requirements

### Requirement: Hikvision client alarm arm via SetupAlarmChan_V50

系统 MUST 支持对海康车牌识别设备执行客户端布防，底层 MUST 调用 HCNetSDK `NET_DVR_SetupAlarmChan_V50`（不得以 V41/V30 作为本需求的实现替代）。布防参数结构 MUST 为 `NET_DVR_SETUPALARM_PARAM_V50`；无订阅子报文时 `pSub` MAY 为 null 且 `dwSubSize` 为 0。

默认布防参数 MUST 至少设置：`dwSize` 为结构体大小、`byLevel = 1`、`byAlarmInfoType = 1`（ITS / `NET_ITS_PLATE_RESULT`）、`byDeployType = 0`（客户端布防）。多值结果 MUST 使用命名 `record`，禁止 tuple。

#### Scenario: Successful arm after login

- **WHEN** 调用方以有效的海康 `LicensePlateRecognitionConfig` 请求布防
- **AND** 设备登录成功
- **AND** 消息回调已注册（或本次完成注册）
- **THEN** 系统 SHALL 调用 `NET_DVR_SetupAlarmChan_V50`
- **AND** 当返回句柄 `>= 0` 时 SHALL 判定成功并缓存该布防句柄
- **AND** SHALL 返回表示成功的命名 `record` 结果

#### Scenario: Arm failure surfaces SDK error

- **WHEN** 登录失败或 `NET_DVR_SetupAlarmChan_V50` 返回 `< 0`
- **THEN** 系统 SHALL 判定失败
- **AND** SHALL 通过 `NET_DVR_GetLastError`（或等价）记录错误码
- **AND** SHALL 在结果 `record` 中暴露失败信息（不得静默吞掉）

#### Scenario: Re-arm closes previous handle

- **WHEN** 同一设备键已存在有效布防句柄
- **AND** 用户再次请求布防
- **THEN** 系统 MUST 先调用 `NET_DVR_CloseAlarmChan_V30`（或文档等价撤防 API）关闭旧句柄
- **AND** 再执行新的 `SetupAlarmChan_V50`

#### Scenario: Dispose closes open alarm handles

- **WHEN** `HikvisionLprService` 停止或异步释放
- **THEN** 系统 MUST 关闭仍打开的布防句柄，避免句柄泄漏

#### Scenario: Message callback receives plate alarms after arm

- **WHEN** 客户端布防成功
- **AND** 设备上报车牌报警（`COMM_UPLOAD_PLATE_RESULT` 或 `COMM_ITS_PLATE_RESULT`）
- **THEN** 系统 SHALL 经已注册的消息回调进入既有车牌解析路径
- **AND** MUST NOT 为布防单独复制一套车牌解码实现

### Requirement: SetupAlarmChan_V50 P/Invoke bindings

系统 MUST 在 `HikvisionSdk`（或等价集中 P/Invoke 模块）中声明 `NET_DVR_SetupAlarmChan_V50`、`NET_DVR_CloseAlarmChan_V30`、`NET_DVR_SetDVRMessageCallBack_V31`（若尚无）以及 `NET_DVR_SETUPALARM_PARAM_V50`，布局 MUST 与 HCNetSDK V6.1.9.48 头文件一致。

#### Scenario: Struct layout is verifiable

- **WHEN** 运行结构体布局测试（或既有 Hikvision struct layout 测试套件扩展）
- **THEN** `NET_DVR_SETUPALARM_PARAM_V50` 的 `Marshal.SizeOf` SHALL 与头文件预期一致（或项目内锁定的黄金尺寸）
- **AND** 失败时测试 MUST 失败而非运行时静默错位
