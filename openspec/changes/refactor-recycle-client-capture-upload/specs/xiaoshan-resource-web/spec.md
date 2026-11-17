## ADDED Requirements

### Requirement: 工控过磅接收 API
`UrbanManagement.XiaoShanResource` SHALL 提供 `POST /api/recycle/weighing/receive`（或同站等价路径），接收工控上传的车牌、毛重与过磅时间，写入与运输清单同源的数据存储。

#### Scenario: 有效车牌与皮重可接收
- **WHEN** 请求携带已启用车辆池车牌与有效毛重
- **THEN** API SHALL 创建或更新运输清单记录
- **AND** 净重 SHALL 为 `毛重 − 车辆池皮重`
- **AND** 响应 SHALL 为命名 result record（含成功标志与净重）

#### Scenario: 未知车牌拒绝
- **WHEN** 车牌不在车辆池或未启用
- **THEN** API SHALL 返回失败
- **AND** SHALL NOT 写入运输清单成功记录

#### Scenario: 不要求业务明细
- **WHEN** 接收请求未带合同号、产品名、收货凭证
- **THEN** API SHALL 仍可成功落运输清单（阶段为待收货或等价）
- **AND** 业务明细 SHALL 留待 Web 运输清单补全

### Requirement: 接收与运输清单列表同源
经接收 API 写入的记录 SHALL 出现在既有运输清单列表查询中，无需单独数据岛。

#### Scenario: 列表可见新接收记录
- **WHEN** 工控接收成功写入一条记录
- **AND** 客户端请求运输清单列表
- **THEN** 列表 SHALL 包含该车牌与毛重/净重信息
