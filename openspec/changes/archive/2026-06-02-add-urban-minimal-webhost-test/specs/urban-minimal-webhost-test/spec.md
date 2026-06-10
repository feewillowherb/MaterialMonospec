## ADDED Requirements

### Requirement: Urban 客户端提供 MinimalWebHost 测试服务
`MaterialClient.Urban` SHALL 提供 `MinimalWebHostService` 用于最小化验证 UrbanManagement 服务可达性与接口可用性。该服务 MUST 以测试能力为目标，返回结构化执行结果（成功状态与消息）。

#### Scenario: 测试服务可执行
- **WHEN** 调用方触发 MinimalWebHost 测试
- **THEN** 系统 SHALL 执行一次最小化服务端请求
- **AND** SHALL 返回包含 Success 与 Message 的结果对象

#### Scenario: 服务端不可达时返回失败
- **WHEN** `UrbanManagement:BaseUrl` 无效或目标服务不可达
- **THEN** 测试结果 MUST 标记为失败
- **AND** SHALL 返回可诊断的错误消息

### Requirement: MinimalWebHost 测试实现采用复制策略
`MaterialClient.Urban` 中的 `MinimalWebHostService.cs` MUST 通过复制既有可用能力实现，MUST NOT 抽取到共享层进行复用改造。

#### Scenario: 代码组织约束
- **WHEN** 开发者实现 MinimalWebHost 测试服务
- **THEN** 服务实现 SHALL 位于 `MaterialClient.Urban` 项目内
- **AND** MUST NOT 新增跨项目公共抽象以复用该测试实现
