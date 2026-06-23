## Purpose

Defines the Urban anomaly detection subsystem that identifies anomalous weighing records based on configurable thresholds (upper/lower weight limits and deviation percentage), automatically marks records during creation, and provides UI filtering and status badges.

## Requirements

### Requirement: Urban 异常检测配置模型

系统 SHALL 提供 `UrbanAnomalyDetectionConfig` 配置类，包含异常判断所需的阈值参数。

#### Scenario: 配置模型结构
- **WHEN** `UrbanAnomalyDetectionConfig` 被定义
- **THEN** MUST 包含 `UpperLimit` 属性（decimal 类型），表示重量上限值（单位：吨）
- **AND** MUST 包含 `LowerLimit` 属性（decimal 类型），表示重量下限值（单位：吨）
- **AND** MUST 包含 `DeviationPercentage` 属性（decimal 类型），表示允许的偏差百分比

#### Scenario: 默认配置值
- **WHEN** `UrbanAnomalyDetectionConfig` 使用默认构造函数创建
- **THEN** `UpperLimit` 默认值 MUST 为 30.0
- **AND** `LowerLimit` 默认值 MUST 为 2.0
- **AND** `DeviationPercentage` 默认值 MUST 为 10.0

#### Scenario: 配置从 appsettings.json 读取
- **WHEN** 应用启动时读取 `appsettings.json`
- **THEN** 系统 MUST 将 `UrbanAnomalyDetection` 配置节绑定到 `UrbanAnomalyDetectionConfig`
- **AND** 配置节 MUST 在 `MaterialClient.Urban/appsettings.json` 中定义
- **AND** 若配置节缺失，MUST 使用默认值

### Requirement: Urban 异常检测服务

系统 SHALL 提供 `IUrbanAnomalyDetector` 接口及其实现 `UrbanAnomalyDetector`，封装异常判断业务逻辑。

#### Scenario: 检测服务接口定义
- **WHEN** `IUrbanAnomalyDetector` 接口被定义
- **THEN** MUST 提供 `IsAnomaly(WeighingRecord record, UrbanAnomalyDetectionConfig config)` 方法
- **AND** 返回值 MUST 为 `bool`（true 表示异常，false 表示正常）

#### Scenario: 车牌号为空判定为异常
- **WHEN** 调用 `IsAnomaly(record, config)`
- **AND** `record.PlateNumber` 为 null 或空字符串或纯空白字符串
- **THEN** MUST 返回 `true`

#### Scenario: 重量超过上限偏差判定为异常
- **WHEN** 调用 `IsAnomaly(record, config)`
- **AND** `record.PlateNumber` 不为空
- **AND** `record.TotalWeight` 与 `config.UpperLimit` 的偏差超过 `config.DeviationPercentage`%
- **THEN** MUST 返回 `true`

#### Scenario: 重量低于下限偏差判定为异常
- **WHEN** 调用 `IsAnomaly(record, config)`
- **AND** `record.PlateNumber` 不为空
- **AND** `record.TotalWeight` 与 `config.LowerLimit` 的偏差超过 `config.DeviationPercentage`%
- **THEN** MUST 返回 `true`

#### Scenario: 正常数据判定
- **WHEN** 调用 `IsAnomaly(record, config)`
- **AND** `record.PlateNumber` 不为空
- **AND** `record.TotalWeight` 在上下限偏差范围内
- **THEN** MUST 返回 `false`

#### Scenario: 偏差计算公式
- **WHEN** 计算重量偏差
- **THEN** 超过上限偏差的定义 MUST 为 `TotalWeight > UpperLimit * (1 + DeviationPercentage / 100)`
- **AND** 低于下限偏差的定义 MUST 为 `TotalWeight < LowerLimit * (1 - DeviationPercentage / 100)`

#### Scenario: DI 注册
- **WHEN** `MaterialClientUrbanModule` 配置服务
- **THEN** `UrbanAnomalyDetector` MUST 注册为 `IUrbanAnomalyDetector` 的实现
- **AND** 生命周期 MUST 为 Singleton

### Requirement: 称重记录创建时自动异常判断

系统 SHALL 在 Urban 模式称重记录创建时，自动执行异常判断并将结果写入 `UrbanWeighingExtension.IsAnomaly`。

#### Scenario: 创建 Urban 记录时标记异常
- **WHEN** `WeighingRecordService.CreateWeighingRecordAsync` 创建 Urban 模式记录
- **THEN** MUST 调用 `IUrbanAnomalyDetector.IsAnomaly()` 判断异常
- **AND** MUST 将判断结果写入 `UrbanWeighingExtension.IsAnomaly`
- **AND** 异常判断 MUST 在同一事务中完成

#### Scenario: 非 Urban 模式不执行异常判断
- **WHEN** 创建非 Urban 模式的称重记录
- **THEN** MUST NOT 调用 `IUrbanAnomalyDetector`
- **AND** MUST NOT 创建 `UrbanWeighingExtension`

#### Scenario: 配置读取失败时的默认行为
- **WHEN** 读取 `UrbanAnomalyDetectionConfig` 失败
- **THEN** MUST 使用 `UrbanAnomalyDetectionConfig` 默认值进行异常判断
- **AND** MUST 记录 Warning 级别日志

### Requirement: UI 标签页基于 IsAnomaly 过滤

系统 SHALL 将「正常/异常」标签页的过滤逻辑基于 `UrbanWeighingExtension.IsAnomaly`（或等价的列表项 DTO 字段 `IsAnomaly`），不得基于 `SyncStatus.Failed`。

#### Scenario: 正常标签页过滤
- **WHEN** 用户点击「正常」标签页
- **THEN** 查询 MUST 过滤 `IsAnomaly == false`（在领域服务 join 上过滤，或在 DTO 投影前过滤）
- **AND** MUST 仅显示 `WeighingMode == UrbanMode` 的记录

#### Scenario: 异常标签页过滤
- **WHEN** 用户点击「异常」标签页
- **THEN** 查询 MUST 过滤 `IsAnomaly == true`
- **AND** MUST 仅显示 `WeighingMode == UrbanMode` 的记录

#### Scenario: 全部标签页
- **WHEN** 用户点击「全部记录」标签页
- **THEN** 查询 MUST 显示所有 `WeighingMode == UrbanMode` 的记录
- **AND** MUST NOT 过滤 `IsAnomaly` 字段

### Requirement: UI 状态徽章区分异常和同步状态

系统 SHALL 在记录列表中通过列表项 DTO 展示数据异常状态；主徽章 MUST 绑定 DTO 的 `IsAnomaly`，不得要求 UI 绑定 `UrbanExtension` 导航属性。

#### Scenario: 数据异常徽章显示
- **WHEN** 列表项 DTO 的 `IsAnomaly == true`
- **THEN** MUST 显示红色「异常」徽章
- **AND** 徽章前景色 MUST 为 "#DC2626"

#### Scenario: 正常数据徽章显示
- **WHEN** 列表项 DTO 的 `IsAnomaly == false`
- **THEN** MUST 显示绿色「正常」徽章
- **AND** 徽章前景色 MUST 为 "#15803D"

#### Scenario: 同步状态与数据异常分离
- **WHEN** 列表项 DTO 的 `SyncStatus == Failed` 且 `IsAnomaly == false`
- **THEN** 主徽章 MUST 仍显示「正常」（数据质量正常）
- **AND** UI MAY 另行展示同步失败提示，且 MUST NOT 将该行归入「异常」Tab 的 `IsAnomaly` 过滤结果

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

### Requirement: 异常判定权威源为 MaterialClient

Urban 称重记录的 `IsAnomaly` 业务含义 SHALL 由 MaterialClient.Urban 在创建与本地审批时判定；UrbanManagement MUST NOT 使用阈值规则（上下限、偏差百分比）重新计算或覆盖该标志，接收上传路径除外下的审批清除逻辑见 `urbanmanagement-weighing-record-approval`。

#### Scenario: 客户端创建时判定异常
- **WHEN** MaterialClient.Urban 创建 Urban 模式称重记录
- **THEN** MUST 调用 `IUrbanAnomalyDetector` 并写入本地 `UrbanWeighingExtension.IsAnomaly`
- **AND** 上传 DTO MUST 携带相同 `IsAnomaly` 值

#### Scenario: 服务端不得阈值重算
- **WHEN** UrbanManagement 接收上传或处理审批以外的写路径
- **THEN** MUST NOT 调用基于 `UpperLimit`/`LowerLimit`/`DeviationPercentage` 的检测器覆盖 `IsAnomaly`
