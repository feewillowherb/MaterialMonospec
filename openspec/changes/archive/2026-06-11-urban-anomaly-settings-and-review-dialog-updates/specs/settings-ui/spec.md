## ADDED Requirements

### Requirement: Urban 异常阈值设置区块

设置窗口 SHALL 提供 `UrbanAnomalyDetection` 配置编辑区块，包含 `UpperLimit`、`LowerLimit`、`DeviationPercentage` 三个字段。

#### Scenario: Urban 模式显示设置区块
- **WHEN** 当前产品模式为 `UrbanMode`
- **THEN** 设置窗口 MUST 显示 Urban 异常阈值设置区块
- **AND** 区块内 MUST 提供上限、下限、偏差百分比可编辑控件

#### Scenario: 非 Urban 模式隐藏设置区块
- **WHEN** 当前产品模式不是 `UrbanMode`
- **THEN** 设置窗口 MUST NOT 显示 Urban 异常阈值设置区块

### Requirement: Urban 异常阈值区块位置

Urban 异常阈值设置区块 SHALL 固定显示在系统设置页面内容的最下方。

#### Scenario: 区块顺序
- **WHEN** 设置窗口渲染系统设置区域
- **THEN** Urban 异常阈值设置区块 MUST 位于已有系统设置项之后
- **AND** MUST 作为系统设置区域最后一个配置分组

### Requirement: Urban 异常阈值持久化

用户在设置窗口修改 Urban 异常阈值后，系统 SHALL 通过现有设置保存流程持久化并在下次加载时恢复。

#### Scenario: 保存阈值
- **WHEN** 用户修改 `UpperLimit`、`LowerLimit`、`DeviationPercentage` 并点击保存
- **THEN** 系统 MUST 通过 `ISettingsService.SaveSettingsAsync` 持久化三个值

#### Scenario: 重新打开设置窗口
- **WHEN** 设置窗口重新打开并加载设置
- **THEN** 系统 MUST 显示上次已保存的 Urban 异常阈值
