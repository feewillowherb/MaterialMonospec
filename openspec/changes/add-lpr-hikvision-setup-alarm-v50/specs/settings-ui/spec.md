## ADDED Requirements

### Requirement: LPR settings row arm alarm action

系统 MUST 在「车牌识别设置」DataGrid 操作栏提供「布防」操作，供用户对单行海康 LPR 配置触发客户端布防。该操作 MUST 与既有「测试抓拍」「编辑」「删除」并列；MUST NOT 要求用户离开设置页或改全局厂商开关。

#### Scenario: Hikvision row shows arm button

- **WHEN** 车牌识别设置列表中某行 `DeviceType = Hikvision`
- **THEN** 该行操作栏 SHALL 显示「布防」按钮
- **AND** 按钮 SHALL 绑定到设置窗口 ViewModel 的布防命令，并以该行配置为参数

#### Scenario: Non-Hikvision row hides arm button

- **WHEN** 某行 `DeviceType` 为 `Vzvision` 或 `Huaxiazhixin`（或其它非海康类型）
- **THEN** 该行操作栏 MUST NOT 显示可用的「布防」按钮（隐藏或等效不可用）

#### Scenario: User clicks arm on Hikvision row

- **WHEN** 用户点击海康行的「布防」
- **THEN** 系统 SHALL 调用海康 LPR 客户端布防能力（见 `license-plate-recognition`）
- **AND** SHALL 将成功或失败结果写入日志（MAY 同时更新该行短状态文案）
