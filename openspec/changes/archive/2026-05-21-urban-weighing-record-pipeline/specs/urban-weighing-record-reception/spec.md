## ADDED Requirements

### Requirement: 接收称重记录 API 端点

UrbanManagement SHALL 提供 `POST /api/urban/weighing-records` 端点，接收 MaterialClient 推送的称重记录。

#### Scenario: 成功接收称重记录
- **WHEN** 收到 POST /api/urban/weighing-records，Body 包含有效 DTO
- **THEN** SHALL 创建 UrbanWeighingRecord 实体
- **AND** SHALL 持久化到 SQLite
- **AND** SHALL 返回 HTTP 200 且 Body 包含 `{ success: true, data: { id: <newId> } }`

#### Scenario: 重复记录幂等处理
- **WHEN** 收到 POST /api/urban/weighing-records，ClientRecordId 已存在
- **THEN** SHALL 返回 HTTP 200 且 Body 包含已有记录 ID
- **AND** SHALL NOT 创建重复记录

#### Scenario: 无效 DTO 返回 400
- **WHEN** 收到 POST /api/urban/weighing-records，Body 缺少必填字段
- **THEN** SHALL 返回 HTTP 400 且 Body 包含 `{ success: false, msg: "<validation error>" }`

### Requirement: 称重记录 DTO 格式

UrbanManagement SHALL 定义称重记录接收 DTO，包含 MaterialClient 传输的必要字段。

#### Scenario: DTO 包含必要字段
- **WHEN** MaterialClient 构建称重记录 DTO
- **THEN** DTO SHALL 包含以下字段：ClientRecordId (long)、PlateNumber (string?)、TotalWeight (decimal)、WeighingTime (DateTime)、SyncType (int?)

### Requirement: 查询称重记录 API 端点

UrbanManagement SHALL 提供 `GET /api/urban/weighing-records` 端点，支持分页和条件查询。

#### Scenario: 分页查询称重记录
- **WHEN** 收到 GET /api/urban/weighing-records?page=1&limit=20
- **THEN** SHALL 返回第 1 页的 20 条记录
- **AND** SHALL 返回总数 `{ success: true, count: <total>, data: [...] }`

#### Scenario: 按车牌号模糊查询
- **WHEN** 收到 GET /api/urban/weighing-records?searchText=京A
- **THEN** SHALL 返回 PlateNumber 包含 "京A" 的记录

#### Scenario: 按时间范围查询
- **WHEN** 收到 GET /api/urban/weighing-records?startTime=2026-01-01&endTime=2026-01-31
- **THEN** SHALL 返回 WeighingTime 在指定范围内的记录

### Requirement: UrbanWeighingRecord 实体定义

UrbanManagement SHALL 定义 `UrbanWeighingRecord` 实体，映射到 `Urban_WeighingRecord` 表。

#### Scenario: 实体字段
- **WHEN** 定义 UrbanWeighingRecord
- **THEN** SHALL 包含以下属性：
  - Id (long, 自增主键)
  - ClientRecordId (long, 客户端记录 ID，唯一索引)
  - PlateNumber (string?)
  - TotalWeight (decimal)
  - WeighingTime (DateTime)
  - AddTime (DateTime, 服务端入库时间)
  - SyncType (int?)
  - SnapImages (string?)

#### Scenario: ClientRecordId 唯一约束
- **WHEN** 插入重复 ClientRecordId 的记录
- **THEN** SHALL 违反唯一约束，触发幂等处理逻辑

### Requirement: 称重记录业务服务

UrbanManagement SHALL 提供 `IUrbanWeighingRecordAppService` 处理称重记录业务逻辑。

#### Scenario: 接收并去重
- **WHEN** ReceiveAsync 被调用且 ClientRecordId 已存在
- **THEN** SHALL 返回已有记录 Id
- **AND** SHALL NOT 插入新记录

#### Scenario: 接收新记录
- **WHEN** ReceiveAsync 被调用且 ClientRecordId 不存在
- **THEN** SHALL 创建新 UrbanWeighingRecord
- **AND** SHALL 设置 AddTime = DateTime.Now
- **AND** SHALL 返回新记录 Id
