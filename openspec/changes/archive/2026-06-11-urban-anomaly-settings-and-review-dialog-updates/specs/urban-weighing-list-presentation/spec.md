## ADDED Requirements

### Requirement: 列表展示异常原因

Urban 左侧称重记录列表 SHALL 显示异常原因字段，帮助操作员快速定位异常类型。

#### Scenario: 异常记录显示原因
- **WHEN** 列表项 `IsAnomaly == true`
- **THEN** 行模板 MUST 显示异常原因文本字段
- **AND** 文本内容 MUST 与异常判定输出一致

#### Scenario: 正常记录无异常原因
- **WHEN** 列表项 `IsAnomaly == false`
- **THEN** 行模板 MUST 显示空值或占位（如 `--`）

### Requirement: 列表展示上传时间

Urban 左侧称重记录列表 SHALL 新增上传时间字段，用于显示记录上云时间。

#### Scenario: 有上传时间
- **WHEN** 列表项存在上传时间
- **THEN** 行模板 MUST 显示上传时间
- **AND** 时间格式 MUST 与界面既有时间格式保持一致

#### Scenario: 无上传时间
- **WHEN** 列表项没有上传时间
- **THEN** 行模板 MUST 显示占位（如 `--`）

### Requirement: 仅异常可审批

审批按钮 SHALL 仅对异常记录可点击，正常记录必须禁用审批入口。

#### Scenario: 异常记录按钮可用
- **WHEN** 列表项 `IsAnomaly == true`
- **THEN** 对应行的审批按钮 MUST 可点击并可触发审批命令

#### Scenario: 正常记录按钮禁用
- **WHEN** 列表项 `IsAnomaly == false`
- **THEN** 对应行的审批按钮 MUST 为禁用状态
- **AND** 点击（或触发）时 MUST NOT 执行审批命令
