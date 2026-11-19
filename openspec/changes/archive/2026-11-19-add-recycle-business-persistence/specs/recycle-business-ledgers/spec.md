## ADDED Requirements

### Requirement: 独立业务台账
系统 SHALL 持久化车辆、合同及独立产品明细、日产量、运输清单；合同明细 SHALL 保存数量、单价和金额，日产量 SHALL 不随出厂净重自动增减。ownerName SHALL 表示车主并与运输人分开。

#### Scenario: 同材料不同合同
- **WHEN** 不同合同使用同一材料并填写不同单价和数量
- **THEN** 分别保存各自合同明细，材料目录不被改写

### Requirement: 一次称重一单与幂等
运输清单 SHALL 以一次称重为粒度，按 ProId、来源客户端、来源记录 Id 防重；不同内容复用相同来源键 SHALL 明确拒绝。

#### Scenario: 重传称重
- **WHEN** 同一来源记录重复提交相同称重内容
- **THEN** 返回已有记录且数据库仍只有一单

### Requirement: 皮重快照和不完整数据
平台 SHALL 保存接收时车辆皮重快照并以毛重减皮重算净重；未找到启用车辆或皮重不可用时 SHALL 保留毛重并标记待补全，净重留空。

#### Scenario: 车辆皮重后改
- **WHEN** 车辆皮重在单据生成后被修改
- **THEN** 既有运输清单皮重和净重不被静默重算

### Requirement: 重量无损保存和外发
Recycle 重量和数量 SHALL 使用 kg 与 decimal；外发 SHALL 按目标单位精确换算并保留小数，SHALL NOT 取整或截断；存储无法无损表示的输入 SHALL 明确拒绝。

#### Scenario: 小数公斤转吨
- **WHEN** 重量为 1234.56789 kg 且目标字段单位为吨
- **THEN** 输出数值 1.23456789，不输出整数或按 UI 位数截断的值

### Requirement: 精度越界不得静默舍入
系统 SHALL 在持久化前验证范围与精度。

#### Scenario: 小数位超限
- **WHEN** 提交超出重量列可表示小数位的值
- **THEN** 明确返回验证错误，不落入已舍入数据

### Requirement: 附件项目归属
附件 SHALL 使用 Recycle 独立元数据和项目存储命名空间，区分现场、合同和收货凭据。

#### Scenario: 附件跨项目读取
- **WHEN** 项目 A 用户请求项目 B 附件
- **THEN** 拒绝访问且不暴露文件内容或存储路径

### Requirement: 同步真实状态和尝试历史
业务行 SHALL 保存最新上报状态及时间，每次真实发送 SHALL 留独立尝试记录；SHALL NOT 将 mock 操作或仅排队标为上报成功。

#### Scenario: 发送失败
- **WHEN** 后续发送器调用目标 API 失败
- **THEN** 记录失败尝试和摘要，业务状态不标记成功
