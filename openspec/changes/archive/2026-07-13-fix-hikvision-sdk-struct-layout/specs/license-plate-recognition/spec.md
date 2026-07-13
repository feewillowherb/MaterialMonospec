## ADDED Requirements

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
