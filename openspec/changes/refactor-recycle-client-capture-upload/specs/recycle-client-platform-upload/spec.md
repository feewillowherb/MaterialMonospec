## ADDED Requirements

### Requirement: Recycle 第一跳上传我方平台
`MaterialClient.Recycle` SHALL 在运单采集完成（本地 `Complete` 成功）后，将车牌、毛重与必要照片元数据上传至我方平台接收 API；SHALL NOT 将该记录经客户端 HMAC 直连市平台 §2.2/§2.3。

#### Scenario: 完成后天上传平台
- **WHEN** Recycle 运单本地完成且车牌合法、毛重有效
- **THEN** 系统 SHALL 调用我方平台 `POST /api/recycle/weighing/receive`（或等价配置路径）
- **AND** SHALL NOT 调用 `IRecycleDataApi` 市平台 batch 接口

#### Scenario: 上传成功标记已同步
- **WHEN** 平台返回成功结果
- **THEN** 本地 SHALL 标记该记录平台同步成功
- **AND** SHALL NOT 再作为待市平台上报队列项

#### Scenario: 上传失败可重试
- **WHEN** 平台返回失败或网络错误
- **THEN** 本地 SHALL 保留待平台同步状态
- **AND** 后台重试或下次触发 SHALL 可再次提交

### Requirement: 平台上传载荷为命名 record
上传请求与响应 SHALL 使用命名 `record`（如 `RecycleWeighingReceiveRequest` / `RecycleWeighingReceiveResult`）；SHALL NOT 使用 C# tuple / `ValueTuple` 作为 API 或服务方法的参数或返回值类型。

#### Scenario: 请求含采集字段
- **WHEN** 构建上传请求
- **THEN** record SHALL 包含客户端记录标识、车牌、毛重、过磅时间
- **AND** SHALL NOT 要求供应商、材料名称、销售合同号、单价作为必填上传字段

### Requirement: RecyclePlatform 基址可配置
`MaterialClientRecycleModule` SHALL 注册指向 `RecyclePlatform:BaseUrl` 的 Refit（或等价）客户端，供第一跳上传使用。

#### Scenario: DI 可解析平台客户端
- **WHEN** Recycle 应用 DI 构建完成且配置了 `RecyclePlatform:BaseUrl`
- **THEN** 平台接收 API 客户端 SHALL 可解析
- **AND** 上传服务 SHALL 使用该基址
