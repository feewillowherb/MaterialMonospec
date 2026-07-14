# 车牌识别 规范

## 目的
待定 - 由变更 hikvision-lpr-integration 归档后创建。归档后更新目的。

## 需求

### 需求：海康威视设备配置字段

系统应支持车牌识别设备的海康威视专用配置字段。

#### 场景：用户添加海康威视 LPR 设备配置
- **假设** 系统配置为 `LprDeviceType = Hikvision`
- **当** 用户在设置窗口中添加新的车牌识别设备
- **则** 系统应：
  - 显示海康威视专用配置字段：UserName、Password、Port、Channel
  - 将 Channel 字段默认值设为 "1"
  - 将 Channel 字段显示为只读（禁用）
  - 允许用户输入 UserName、Password、Port

#### 场景：用户查看已有海康威视 LPR 配置
- **假设** 已有填好海康威视专用字段的 LPR 配置
- **且** `LprDeviceType = Hikvision`
- **当** 用户打开设置窗口
- **则** 系统应：
  - 显示所有海康威视专用字段及其已保存值
  - UserName 显示已配置值
  - Password 以掩码显示（PasswordChar="●"）
  - Port 显示已配置值
  - Channel 以只读显示，值为 "1"

#### 场景：用户将设备类型切换为 Vzvision
- **假设** 当前 `LprDeviceType = Hikvision`
- **且** 海康威视专用字段可见
- **当** 用户将 `LprDeviceType` 改为 `Vzvision`（原 `LprAllInOne`，已重命名）
- **则** 系统应：
  - 隐藏海康威视专用字段中的 Channel（及与海康绑定的展示规则）
  - 在内存中保留海康威视字段值（不丢失），以便用户切回海康时使用
  - 显示通用 LPR 字段（Name、Ip、Direction）
  - 显示 Vzvision SDK 连接所需字段：UserName、Password、Port（可编辑，具体标签与掩码规则与实现一致）
  - 无需重启窗口即可更新 UI

---

### 需求：按设备类型动态显示字段

系统应根据所选 `LprDeviceType` 动态显示或隐藏海康威视专用配置字段，以及 Vzvision SDK 连接字段。

#### 场景：设备类型为 Hikvision 时显示海康威视字段
- **假设** 用户在设置窗口中
- **且** `LprDeviceType = Hikvision`
- **则** 系统应显示：UserName（可编辑）、Password（可编辑带掩码）、Port（可编辑）、Channel（只读，固定值 "1"）

#### 场景：设备类型为 Vzvision 时显示 SDK 连接字段且不显示海康 Channel
- **假设** 用户在设置窗口中且 `LprDeviceType = Vzvision`（原 `LprAllInOne`）
- **则** 系统应显示通用字段 Name、Ip、Direction，以及 UserName、Password、Port（用于 `VzLPRClient_Open`）
- **且** 系统不应显示海康专用 Channel 字段

#### 场景：设备类型为 Huaxiazhixin 时不显示海康威视字段
- **假设** 用户在设置窗口中且 `LprDeviceType = Huaxiazhixin`
- **则** 系统不应显示海康威视专用字段，仅显示 Name、Ip、Direction（华夏智信设备配置将在后续变更中实现）

---

### 需求：海康威视字段的 JSON 配置持久化

系统应将海康威视专用配置字段持久化到 JSON，并在加载设置时正确恢复，同时兼容旧数据；对 Vzvision 设备，同一 `LicensePlateRecognitionConfig` 中的 Port/UserName/Password MUST 可被持久化与恢复以支持 SDK 连接。

#### 场景：保存海康威视 LPR 配置到 JSON
- **假设** 用户已配置海康威视 LPR（含 Name、Ip、Direction、UserName、Password、Port、Channel）
- **当** 用户在设置窗口点击保存
- **则** 系统应将所有字段序列化到 `SettingsEntity.LicensePlateRecognitionConfigsJson`，并保存到 SQLite

#### 场景：从 JSON 加载海康威视 LPR 配置
- **假设** 数据库中存在含完整海康威视字段的 JSON
- **当** 用户打开设置窗口
- **则** 系统应反序列化并正确显示所有海康威视字段及通用字段

#### 场景：加载旧配置 JSON（向后兼容）
- **假设** 数据库中存在不含海康威视字段的旧 JSON
- **当** 用户打开设置窗口
- **则** 系统应成功反序列化、正确加载已有字段、将新海康威视字段设为 null，且无需手动数据迁移

#### 场景：混合设备类型配置持久化
- **假设** 用户配置了多台 LPR（含海康威视与 Vzvision）
- **当** 用户保存并重新加载
- **则** 系统应正确序列化/反序列化各设备配置并保持完整

#### 场景：持久化中设备类型枚举迁移
- **假设** 历史 JSON 中存在已弃用的设备类型字面量 `LprAllInOne`
- **当** 用户加载设置或升级后首次启动
- **则** 系统 MUST 将其解析或迁移为 `Vzvision`（或提供等价兼容层），且不得静默丢失该条设备配置

---

### 需求：海康威视 LPR 服务接口定义

系统应定义海康威视 LPR 设备集成的服务接口，为后续实现确立契约。

#### 场景：已定义服务接口
- **则** 系统应在命名空间 `MaterialClient.Common.Services.Hikvision` 中定义 `IHikvisionLprService` 接口
- **且** 声明方法：ConnectAsync、DisconnectAsync、StartListeningAsync、StopListeningAsync
- **且** 声明属性：PlateRecognized（IObservable）、IsConnected
- **且** 为所有成员提供 XML 文档注释，不包含实现代码（实现在单独提案中）

#### 场景：接口遵循 ReactiveUI 模式
- **则** 应使用 IObservable 表示事件流、Task 表示异步操作，并遵循现有 ReactiveUI 模式与依赖注入

**说明**：本需求仅确立接口定义；实际实现与 HCNetSDK 集成由单独提案覆盖。

---

## ADDED Requirements

### Requirement: 识别后动作按供应商能力门控
系统 MUST 在 MessageBus 驱动的车牌识别后置动作中按设备类型进行能力门控，未声明支持某能力的供应商不得触发该能力。

#### Scenario: Vzvision 可触发道闸 I/O 后置动作
- **WHEN** `LprDeviceType = Vzvision` 且识别消息到达 MessageBus 后置动作编排
- **THEN** 系统 MAY 进入道闸 I/O 执行分支（仍受 `EnableGateIo` 配置约束）

#### Scenario: 非 Vzvision 不触发道闸 I/O 后置动作
- **WHEN** `LprDeviceType != Vzvision` 且识别消息到达 MessageBus 后置动作编排
- **THEN** 系统 MUST 跳过道闸 I/O 执行分支，并继续其他不依赖该能力的识别流程

#### Scenario: 非支持设备输出可观测日志
- **WHEN** `LprDeviceType != Vzvision` 且道闸 I/O 功能被启用或进入评估流程
- **THEN** 系统 MUST 输出“当前设备类型暂未支持道闸 I/O 功能”的日志，帮助定位能力差异

---

### 需求：支持通过测试接口注入识别事件

系统应支持通过本地测试接口触发识别事件，以在无真实抓拍回调时驱动车牌识别后续流程。

#### 场景：测试接口发布的识别事件进入统一事件通道
- **当** 测试车牌注入接口接收到合法请求
- **则** 系统应通过 `MessageBus.Current` 发布 `LicensePlateRecognizedMessage`
- **且** 该消息应与真实设备识别消息共享同一消费通道

#### 场景：测试接口事件在来源标识上可区分
- **当** 系统根据测试接口请求构造 `LicensePlateRecognizedMessage`
- **则** 系统应为来源相关字段赋予可识别值（由请求提供或由默认策略补齐）
- **且** 下游日志或联调输出应能区分“测试注入”与“设备回调”来源
## Requirements
### Requirement: 海康 LPR P/Invoke 结构体必须与官方 SDK 对齐

系统 MUST 使海康 LPR 回调所用的 P/Invoke 结构体定义与 `HCNetSDK.h`（CH-HCNetSDKV6.1.9.48）及官方 Demo `CHCNetSDK.cs` 内存布局一致。禁止在 `MaterialClient.Common` 中手写或自创与 SDK 同名的结构体类型。

#### Scenario: LPR 结构体来自官方 Demo 而非手写

- **WHEN** 开发者在 `MaterialClient.Common` 中维护海康 LPR 相关 P/Invoke 类型
- **THEN** `NET_ITS_PLATE_RESULT`、`NET_DVR_PLATE_RESULT`、`NET_DVR_ALARMER`、`NET_DVR_PLATE_INFO` 等 MUST 从官方 `CHCNetSDK.cs`（交通产品 Demo 或 GovClient 已验证副本）裁剪或完整复制
- **AND** MUST NOT 定义 SDK 中不存在的类型名（例如 `NET_ITS_PLATE_INFO`、`NET_DVR_PLATE_INFO_EX`）

#### Scenario: 结构体大小防回归校验

- **WHEN** 单元测试或 CI 执行海康 SDK 绑定校验
- **THEN** 系统 MUST 断言 `Marshal.SizeOf<NET_ITS_PLATE_RESULT>()` 等关键类型与官方 `CHCNetSDK.cs` 同 SDK 版本下的期望值一致
- **AND** 断言失败时 MUST 使构建或测试失败，而非静默通过

---

### Requirement: 海康 ITS 车牌回调解析（COMM_ITS_PLATE_RESULT）

系统 MUST 正确解析 `COMM_ITS_PLATE_RESULT` (0x3050) 回调，从 `NET_ITS_PLATE_RESULT.struPlateInfo.sLicense` 提取 GBK 编码车牌，且每次有效抓拍仅发布一条 LPR 事件。

#### Scenario: ITS 回调提取正确车牌

- **GIVEN** 海康设备（如 iDS-TCM204-E）上报 `COMM_ITS_PLATE_RESULT`
- **WHEN** `HikvisionLprService` 处理 `pAlarmInfo`
- **THEN** 系统 MUST 将 `pAlarmInfo` 编组为 `NET_ITS_PLATE_RESULT`
- **AND** MUST 从 `struPlateInfo.sLicense` 使用 GBK 解码车牌文本
- **AND** MUST NOT 从顶层虚构字段或数组元素 `struPlateInfo[i]` 读取车牌
- **AND** 发布至多一条 `LicensePlateRecognizedEventData`（占位符或空车牌除外）

#### Scenario: ITS 回调过滤无效车牌占位符

- **GIVEN** 解码后的车牌包含占位文本「车牌」或为空
- **WHEN** `HandleItsPlateResult` 完成 GBK 解码
- **THEN** 系统 MUST 跳过事件发布（与 GovClient `CaptureDevice` 行为一致）

#### Scenario: ITS 回调单次抓拍不产生多条垃圾事件

- **GIVEN** 设备完成一次 ITS 抓拍并触发一次回调
- **WHEN** 系统处理该回调
- **THEN** 系统 MUST NOT 因遍历假 `struPlateInfo` 数组而连续发布多条含时间戳、UUID 或乱码的 LPR 事件

#### Scenario: ITS 场景图从 struPicInfo 提取

- **GIVEN** `NET_ITS_PLATE_RESULT.dwPicNum > 0` 且 UrbanMode 需要保存 LPR 附件
- **WHEN** 系统保存 LPR 图片
- **THEN** 系统 MUST 从 `struPicInfo[]`（`i < dwPicNum`，场景图 `byType == 1`）读取图片缓冲区
- **AND** MUST NOT 从错误的 `plateInfo.pBuffer` 路径读取

---

### Requirement: 海康旧版车牌回调解析（COMM_UPLOAD_PLATE_RESULT）

系统 MUST 正确解析 `COMM_UPLOAD_PLATE_RESULT` (0x2800) 回调，从 `NET_DVR_PLATE_RESULT.struPlateInfo.sLicense` 提取 GBK 编码车牌。

#### Scenario: 旧版回调提取正确车牌

- **GIVEN** 海康设备上报 `COMM_UPLOAD_PLATE_RESULT`
- **WHEN** `HikvisionLprService` 处理 `pAlarmInfo`
- **THEN** 系统 MUST 将 `pAlarmInfo` 编组为 `NET_DVR_PLATE_RESULT`
- **AND** MUST 从 `struPlateInfo.sLicense` 使用 GBK 解码车牌
- **AND** MUST NOT 从 `NET_DVR_PLATE_RESULT` 顶层 `sLicense` 字段读取（该字段在官方布局中不存在）

#### Scenario: 旧版回调场景图提取

- **GIVEN** `NET_DVR_PLATE_RESULT.dwPicLen > 0` 且 `pBuffer1` 有效
- **WHEN** 系统保存 LPR 全景图
- **THEN** 系统 MUST 优先从 `pBuffer1` 读取；若无则 MAY 回退 `pBuffer5`/`dwFarCarPicLen`（与 GovClient 一致）

---

### Requirement: 海康报警器结构体解析用于设备识别

系统 MUST 使用与 SDK 对齐的 `NET_DVR_ALARMER` 从回调中解析设备 IP，以匹配 `LicensePlateRecognitionConfig`。

#### Scenario: 从 NET_DVR_ALARMER 解析设备 IP

- **WHEN** `MSGCallBack` 收到 `pAlarmer`
- **THEN** 系统 MUST 将 `pAlarmer` 编组为 `NET_DVR_ALARMER`
- **AND** MUST 从 `sDeviceIP` 提取 IP 字符串（去除 `\0` 填充）
- **AND** MUST 能根据该 IP 在 `_deviceConfigs` 中查找到已配置设备名称

#### Scenario: 设备 IP 解析不得混入设备名称乱码

- **GIVEN** 设备 IP 为 `192.168.1.100`
- **WHEN** 解析回调中的报警器信息
- **THEN** 日志与 `DeviceName` 解析 MUST NOT 将 `sDeviceName` 与 `sDeviceIP` 错位拼接为 `Unknown (iDS-TCM204-E...&192.168.1.100)` 形式

---

### Requirement: 无 CameraConfigs 时 LPR 双附件落盘
当 `SettingsEntity.CameraConfigs` 为空（无海康称重相机配置）时，系统 SHALL 在 LPR 识别落盘时同时创建 `AttachType.Lpr` 与 `AttachType.UnmatchedEntryPhoto` 两条 `AttachmentFile`，二者 `LocalPath` 相同；SHALL 在创建称重记录后挂接到该 `WeighingRecord`。

#### Scenario: 无相机时双附件
- **WHEN** `CameraConfigs.Count == 0`
- **AND** LPR 识别成功并落盘至 `Lpr/{yyyy}/{MM}/{dd}/` 下的 jpg
- **AND** 创建称重记录
- **THEN** 数据库 SHALL 存在 `AttachType.Lpr` 与 `AttachType.UnmatchedEntryPhoto` 两条记录
- **AND** 二者 `LocalPath` SHALL 相同

#### Scenario: 有 CameraConfigs 时不自动创建 UnmatchedEntryPhoto
- **WHEN** `CameraConfigs.Count > 0`
- **AND** LPR 识别成功
- **THEN** SHALL NOT 因 LPR  alone 自动创建 `UnmatchedEntryPhoto`（沿用现有 Hik 抓拍链路）

### Requirement: 非 UrbanMode 下无相机时 LPR 仍落盘
当 `CameraConfigs` 为空时，Hikvision/Vzvision LPR 服务 SHALL 允许在 `WeighingMode` 为 Standard、SolidWaste 或 Recycle 时落盘 LPR 图片，SHALL NOT 因非 `UrbanMode` 直接返回 null。

#### Scenario: Recycle 模式 LPR 落盘
- **WHEN** `WeighingMode` 为 `Recycle`
- **AND** `CameraConfigs` 为空
- **AND** LPR 回调触发
- **THEN** SHALL 写入 `Lpr/{yyyy}/{MM}/{dd}/` 目录下的 jpg 文件

### Requirement: LPR 落盘使用年月日目录

Hikvision / Vzvision LPR 服务保存识别图片时，MUST 使用日期目录约定：根目录 `Lpr` 下 `{yyyy}/{MM}/{dd}/`，文件名可继续使用 `{plate}_{yyyyMMdd_HHmmss_fff}.jpg`（或等价时间戳命名）。系统 MUST 通过 `AttachmentPathUtils.GetLocalStorageAbsolutePath(AttachType.Lpr, date)`（或等价调用同一套路径辅助方法）取得目录，MUST NOT 再写入无日期层级的扁平 `Lpr/` 根目录（调试目录 `LprDebug` 除外）。返回并持久化的 `LocalPath` MUST 为相对路径，例如 `Lpr/2026/07/14/浙A12345_….jpg`。

#### Scenario: 正常识别落盘带日期目录

- **WHEN** LPR 回调含有效图片字节且保存成功
- **AND** 当前本地日期为 2026-07-14
- **THEN** 文件 MUST 存在于应用程序目录下的 `Lpr/2026/07/14/`（路径分隔符以实现平台为准）
- **AND** 返回的相对路径 MUST 包含 `2026`、`07`、`14` 段

#### Scenario: 与 UrbanPhoto 共用 Lpr 根与日期结构

- **WHEN** Urban 枪机使用 `GetLocalStorageAbsolutePath(AttachType.UrbanPhoto, now)`
- **AND** LPR 使用 `GetLocalStorageAbsolutePath(AttachType.Lpr, now)`
- **THEN** 二者 MUST 使用相同的根目录名 `Lpr` 与相同的 `{yyyy}/{MM}/{dd}` 目录结构

### Requirement: 本周期 LPR 候选择优

系统 SHALL 在单个称重周期内维护至多一个当前 LPR 图片候选。当新的带图片路径的 `LicensePlateRecognizedEventData` 到达时，系统 MUST 按以下优先级决定是否接受该路径：有车牌结果（非空且通过车牌校验的 `PlateNumber`）的优先级 MUST 高于无车牌；同优先级时 MUST 接受较新到达的候选。被拒绝的候选 MUST NOT 覆盖当前候选。

#### Scenario: 无车牌后被有车牌升级

- **GIVEN** 本周期当前 LPR 候选来自无车牌（或空车牌）事件且已保存路径
- **WHEN** 随后收到带有效车牌与新 LPR 路径的识别事件
- **THEN** 系统 MUST 将当前候选更新为该新路径
- **AND** MUST 将候选标记为有车牌

#### Scenario: 有车牌不被无车牌降级

- **GIVEN** 本周期当前 LPR 候选已有车牌
- **WHEN** 随后收到无有效车牌但带 LPR 路径的事件
- **THEN** 系统 MUST NOT 用该路径覆盖当前候选

### Requirement: LPR 附件绑定与建单时序解耦

系统 SHALL 支持在称重记录创建之前或之后完成本周期 LPR 附件关联，且 MUST 对所有称重模式（含 Standard、SolidWaste、Recycle、UrbanMode）生效。当创建称重记录时若已有接受的候选路径，MUST 挂接 `AttachType.Lpr`；当无 `CameraConfigs` 时 MUST 仍按既有规则同步挂接同路径的 `UnmatchedEntryPhoto`。当本周期已存在最近创建的称重记录标识且新候选被接受时，系统 MUST 将该路径 Upsert 到该记录的 LPR 附件，而 MUST NOT 要求重新创建称重记录。非 Urban 客户端 MAY 不在业务 UI 中展示或消费该附件。

#### Scenario: 先建单后图（任意模式）

- **GIVEN** 称重已稳定并已创建 `WeighingRecord`（任意 `WeighingMode`），本周期尚无 LPR 附件
- **WHEN** 本周期内晚到的 LPR 识别事件携带图片路径且候选被接受
- **THEN** 系统 MUST 为该记录创建或更新 `AttachType.Lpr` 附件指向该路径

#### Scenario: 先图后建单（任意模式）

- **GIVEN** 本周期已接受带路径的 LPR 候选
- **WHEN** 创建称重记录且存在该候选路径
- **THEN** 系统 MUST 在创建流程中将当前候选路径挂接为 LPR 附件
- **AND** MUST NOT 因非 `UrbanMode` 或存在 `CameraConfigs` 而跳过挂接

#### Scenario: 下磅后不再补绑

- **GIVEN** 系统已执行周期重置，上一笔记录的最近创建标识已清空
- **WHEN** 随后收到带 LPR 路径的识别事件
- **THEN** 系统 MUST NOT 将路径绑定到已重置的上一笔称重记录

### Requirement: 全模式 LPR 图片落盘

Hikvision/Vzvision 等 LPR 服务在回调中收到有效图片缓冲时，SHALL 将图片落盘到 LPR 目录并在事件中携带相对路径，MUST NOT 仅因 `WeighingMode` 非 `UrbanMode` 或已配置 `CameraConfigs` 而跳过落盘。

#### Scenario: Standard 有相机仍落盘

- **WHEN** `WeighingMode` 为 `Standard` 且 `CameraConfigs` 非空
- **AND** LPR 回调携带图片数据
- **THEN** SHALL 写入 `Lpr/{yyyy}/{MM}/{dd}/` 目录下的 jpg 文件
- **AND** SHALL 在 `LicensePlateRecognizedEventData.LprImagePath` 中提供路径

#### Scenario: Recycle 有相机仍落盘并挂接

- **WHEN** `WeighingMode` 为 `Recycle` 且 `CameraConfigs` 非空
- **AND** 本周期有已接受的 LPR 候选路径并创建称重记录
- **THEN** SHALL 挂接 `AttachType.Lpr`
- **AND** Recycle UI MAY 不展示该附件

### Requirement: 晚到补绑后刷新 Urban 异常

Urban 建单时 MUST NOT 因尚未到达的 LPR 立即写入 `CaptureFailure`；系统 SHALL 在创建扩展时推迟异常判定（`IsAnomaly=false`），并在以下时机之一使用与记录编辑后相同的异常检测路径重算并持久化 `IsAnomaly` 与 `AnomalyReason`：（1）本周期 LPR 附件 Upsert/补绑成功后（重算前 SHOULD 将识别缓存中的车牌同步到记录）；（2）称重周期重置（下磅）时对上笔记录做最终重算（仍无 LPR 附件则可为 `CaptureFailure`）。无 Urban 扩展的记录 MUST NOT 因此路径创建 Urban 扩展。

#### Scenario: 建单时不因缺图立即标抓拍异常

- **GIVEN** 称重稳定后先创建记录再触发主动 LPR 抓拍
- **WHEN** 创建 `UrbanWeighingExtension` 且本周期尚无 LPR 附件
- **THEN** 系统 MUST NOT 将 `AnomalyReason` 设为 `CaptureFailure`
- **AND** MUST 将异常判定推迟到 LPR 补绑或周期重置

#### Scenario: 缺图异常因补绑清除

- **GIVEN** 记录创建时已推迟异常判定，且其它条件未触发异常
- **WHEN** 本周期晚到 LPR 补绑成功
- **THEN** 系统 MUST 重算异常标志（可先同步车牌）
- **AND** 若检测结果为非异常，MUST 将 `IsAnomaly` 更新为 `false` 并清除相应原因

### Requirement: CreateWeighingRecord 调用 LPR 保存

`WeighingRecordService.CreateWeighingRecordAsync` SHALL 在存在本周期已接受的 LPR 候选路径时调用 LPR 附件保存逻辑，MUST NOT 将保存条件限制为 `WeighingMode.UrbanMode` 或 `CameraConfigs` 为空。创建完成后若本周期仍收到更优候选，SHALL 由补绑路径 Upsert，而 MUST NOT 仅依赖创建瞬间的一次性快照作为唯一绑定机会。无 `CameraConfigs` 时的 `UnmatchedEntryPhoto` 双挂接行为保持既有规则。

#### Scenario: Recycle 有相机创建记录仍挂接 LPR

- **WHEN** 在 Recycle 模式创建称重记录
- **AND** `CameraConfigs` 非空
- **AND** 存在已接受的本周期 LPR 候选路径
- **THEN** SHALL 挂接 LPR 附件

#### Scenario: Recycle 无相机创建记录

- **WHEN** 在 Recycle 模式创建称重记录
- **AND** `CameraConfigs` 为空
- **AND** 存在已接受的本周期 LPR 候选路径
- **THEN** SHALL 挂接 LPR 附件
- **AND** SHALL 按既有规则同步挂接 `UnmatchedEntryPhoto`

#### Scenario: 创建时无路径不阻止晚到补绑

- **WHEN** 创建称重记录时本周期尚无 LPR 候选路径
- **AND** 创建后、周期重置前收到可接受的 LPR 路径事件
- **THEN** SHALL 仍能通过补绑挂接 LPR 附件

