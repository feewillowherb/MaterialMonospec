## ADDED Requirements

### Requirement: 异常原因可读输出

系统 SHALL 为 Urban 异常记录提供可读的异常原因文本，用于列表展示与审核判断。

#### Scenario: 车牌为空异常原因
- **WHEN** 记录被判定为异常且原因是车牌号为空
- **THEN** 系统 MUST 输出简短原因文本（如“车牌为空”）

#### Scenario: 超上限异常原因
- **WHEN** 记录被判定为异常且原因是重量超过上限偏差阈值
- **THEN** 系统 MUST 输出简短原因文本（如“超上限”）

#### Scenario: 低于下限异常原因
- **WHEN** 记录被判定为异常且原因是重量低于下限偏差阈值
- **THEN** 系统 MUST 输出简短原因文本（如“低下限”）

#### Scenario: 正常记录原因
- **WHEN** 记录被判定为正常
- **THEN** 系统 MUST 返回空原因或默认占位值
- **AND** UI MUST NOT 将其显示为异常原因

#### Scenario: 异常原因文案长度
- **WHEN** 系统生成 `AnomalyReason` 文案
- **THEN** 文案 MUST 使用短语表达，避免长句
- **AND** 文案长度 SHOULD 控制在 8 个汉字以内
