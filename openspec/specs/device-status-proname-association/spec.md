# Device Status ProId ProName Association Specification

## Purpose

定义设备管理基于项目主键（ProId）和项目名称（ProName）的关联能力，替代原有的 ClientId 标识体系。设备状态消息携带 ProId/ProName，服务端按 ProId 聚合，UI 以 ProName 展示，实现面向项目的设备管理视图。

## Requirements

### Requirement: DeviceStatusMessage 新增 ProId 和 ProName 字段

`DeviceStatusMessage` SHALL 新增 `ProId` (string) 和 `ProName` (string) 属性。`ProId` 作为设备管理的主键标识（用于聚合、缓存、筛选），`ProName` 作为面向用户的展示名称。两个字段均从客户端 LicenseInfo 读取填充。

#### Scenario: 消息包含 ProId 和 ProName

- **WHEN** 客户端构建设备状态消息
- **THEN** `DeviceStatusMessage` SHALL 包含 `ProId` 字段
- **AND** SHALL 包含 `ProName` 字段
- **AND** `ProId` SHALL 从 `LicenseInfo.ProjectId.ToString()` 读取
- **AND** `ProName` SHALL 从 `LicenseInfo.ProName` 读取

#### Scenario: ProId/ProName 为空时的降级处理

- **WHEN** 客户端 LicenseInfo 不存在或 ProId/ProName 为空
- **THEN** `ProId` 和 `ProName` SHALL 使用空字符串
- **AND** 消息 SHALL 仍然发送成功
- **AND** 服务端 SHALL 降级使用 ClientId 作为标识

### Requirement: 设备管理页面以 ProName 展示，ProId 为主键

设备管理页面 SHALL 以 ProName（项目名称）作为面向用户的展示标签，以 ProId 作为底层数据标识。列表、筛选、实时更新均使用 ProId/ProName 替代 ClientId。

#### Scenario: 列表展示 ProName

- **WHEN** 用户访问设备管理页面
- **THEN** 设备列表 SHALL 显示 ProName 列（替代 ClientId 列）
- **AND** 列头 SHALL 显示"项目名称"
- **AND** 行标识 SHALL 使用 ProId 而非 ClientId

#### Scenario: 按 ProId 筛选

- **WHEN** 用户在筛选区域输入搜索关键字
- **THEN** 系统 SHALL 按精确匹配 ProId 过滤设备状态
- **AND** 筛选结果 SHALL 显示匹配的 ProName 对应的设备

#### Scenario: 实时更新使用 ProId/ProName

- **WHEN** SignalR 推送新的设备状态消息
- **THEN** 页面 SHALL 从 `message.proId` 读取标识进行数据更新
- **AND** SHALL 从 `message.proName` 读取展示名称
- **AND** SHALL NOT 使用 `message.clientId` 作为展示或聚合标识

### Requirement: 服务端按 ProId 聚合设备状态

`DeviceStatusAppService` SHALL 按 ProId + DeviceType 聚合最新设备状态，替代当前按 ClientId + DeviceType 的聚合逻辑。返回结果中包含 ProName 用于 UI 展示。

#### Scenario: 按 ProId 聚合

- **WHEN** 查询设备状态列表
- **THEN** 系统 SHALL 按 ProId + DeviceType 分组
- **AND** 每组 SHALL 返回最新的一条状态记录
- **AND** 返回结果 SHALL 包含 ProId 和 ProName 字段
- **AND** ProName SHALL 用于 UI 展示

#### Scenario: ProId 筛选

- **WHEN** 请求包含 `ProId` 筛选参数
- **THEN** 系统 SHALL 按精确匹配过滤 ProId
- **AND** SHALL NOT 使用 ClientId 筛选
