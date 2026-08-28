## MODIFIED Requirements

### 需求：海康威视设备配置字段

系统应支持车牌识别设备的海康威视专用配置字段。字段显隐 MUST 跟随**该次添加/编辑对话框所选**（或该行已保存的）`DeviceType`，MUST NOT 假设全站只有一份 `SystemSettings.LprDeviceType`。

#### 场景：用户添加海康威视 LPR 设备配置
- **假设** 添加对话框中 `DeviceType = Hikvision`
- **当** 用户在设置窗口中添加新的车牌识别设备
- **则** 系统应：
  - 显示海康威视专用配置字段：UserName、Password、Port、Channel
  - 将 Channel 字段默认值设为 "1"
  - 将 Channel 字段显示为只读（禁用）
  - 允许用户输入 UserName、Password、Port

#### 场景：用户查看已有海康威视 LPR 配置
- **假设** 已有填好海康威视专用字段的 LPR 配置且该行 `DeviceType = Hikvision`
- **当** 用户打开设置窗口并编辑该行
- **则** 系统应：
  - 显示所有海康威视专用字段及其已保存值
  - UserName 显示已配置值
  - Password 以掩码显示（PasswordChar="●"）
  - Port 显示已配置值
  - Channel 以只读显示，值为 "1"

#### 场景：用户在对话框内将设备类型切换为 Vzvision
- **假设** 添加或编辑对话框当前 `DeviceType = Hikvision`
- **且** 海康威视专用字段可见
- **当** 用户将对话框内 `DeviceType` 改为 `Vzvision`
- **则** 系统应：
  - 隐藏海康威视专用字段中的 Channel（及与海康绑定的展示规则）
  - 在内存中保留海康威视字段值（不丢失），以便用户切回海康时使用
  - 显示通用 LPR 字段（Name、Ip、Direction）
  - 显示 Vzvision SDK 连接所需字段：UserName、Password、Port（可编辑，具体标签与掩码规则与实现一致）
  - 无需重启窗口即可更新 UI
  - MUST NOT 要求先改设置页全局厂商 Combo

### 需求：按设备类型动态显示字段

系统应根据**对话框或该行**所选 `DeviceType` 动态显示或隐藏海康威视专用配置字段，以及 Vzvision SDK 连接字段。

#### 场景：设备类型为 Hikvision 时显示海康威视字段
- **假设** 用户在添加或编辑 LPR 对话框中
- **且** `DeviceType = Hikvision`
- **则** 系统应显示：UserName（可编辑）、Password（可编辑带掩码）、Port（可编辑）、Channel（只读，固定值 "1"）

#### 场景：设备类型为 Vzvision 时显示 SDK 连接字段且不显示海康 Channel
- **假设** 用户在添加或编辑 LPR 对话框中且 `DeviceType = Vzvision`
- **则** 系统应显示通用字段 Name、Ip、Direction，以及 UserName、Password、Port（用于 `VzLPRClient_Open`）
- **且** 系统不应显示海康专用 Channel 字段

#### 场景：设备类型为 Huaxiazhixin 时不显示海康威视字段
- **假设** 用户在添加或编辑 LPR 对话框中且 `DeviceType = Huaxiazhixin`
- **则** 系统不应显示海康威视专用字段，仅显示 Name、Ip、Direction（华夏智信设备配置将在后续变更中实现）

### Requirement: 识别后动作按供应商能力门控
系统 MUST 在 MessageBus 驱动的车牌识别后置动作中按**该次识别对应设备**的 `DeviceType`（消息或匹配到的配置行）进行能力门控，未声明支持某能力的供应商不得触发该能力。MUST NOT 用全站 `SystemSettings.LprDeviceType` 作为门控。

#### Scenario: Vzvision 可触发道闸 I/O 后置动作
- **WHEN** 该次识别的设备 `DeviceType = Vzvision` 且识别消息到达 MessageBus 后置动作编排
- **THEN** 系统 MAY 进入道闸 I/O 执行分支（仍受该行 `EnableGateIo` 配置约束）

#### Scenario: 非 Vzvision 不触发道闸 I/O 后置动作
- **WHEN** 该次识别的设备 `DeviceType != Vzvision` 且识别消息到达 MessageBus 后置动作编排
- **THEN** 系统 MUST 跳过道闸 I/O 执行分支，并继续其他不依赖该能力的识别流程

#### Scenario: 非支持设备输出可观测日志
- **WHEN** 该次识别的设备 `DeviceType != Vzvision` 且道闸 I/O 功能被启用或进入评估流程
- **THEN** 系统 MUST 输出“当前设备类型暂未支持道闸 I/O 功能”的日志，帮助定位能力差异
