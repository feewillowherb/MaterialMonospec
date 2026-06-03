## MODIFIED Requirements

### Requirement: Urban 异常检测配置模型

系统 SHALL 提供 `UrbanAnomalyDetectionConfig` / `UrbanAnomalyDetectionOptions` 配置类，包含异常判断所需的阈值参数。在 UrbanManagement 服务端，阈值 MUST 与 `UrbanWeighingRecord.TotalWeight` 使用相同单位：**千克（kg）**。

#### Scenario: 配置模型结构

- **WHEN** `UrbanAnomalyDetectionOptions` 被定义（UrbanManagement）
- **THEN** `UpperLimit` MUST 表示重量上限（**kg**）
- **AND** `LowerLimit` MUST 表示重量下限（**kg**）
- **AND** `DeviationPercentage` MUST 表示允许的偏差百分比

#### Scenario: 默认配置值（千克）

- **WHEN** 使用默认配置（未覆盖 appsettings）
- **THEN** `UpperLimit` 默认值 MUST 为 `30000`（对应约 30 吨）
- **AND** `LowerLimit` 默认值 MUST 为 `2000`（对应约 2 吨）
- **AND** `DeviationPercentage` 默认值 MUST 为 `10.0`

#### Scenario: 配置从 appsettings.json 读取

- **WHEN** UrbanManagement 应用启动时读取 `appsettings.json`
- **THEN** 系统 MUST 将 `UrbanAnomalyDetection` 配置节绑定到 `UrbanAnomalyDetectionOptions`
- **AND** 配置值 MUST 以千克解释
