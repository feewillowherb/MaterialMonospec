## ADDED Requirements

### Requirement: Urban 桌面端支持 MinimalWebHost 测试入口
MaterialClient.Urban SHALL 提供可触发的 MinimalWebHost 测试入口，以便在不进入完整称重流程时验证 UrbanManagement 联通性。该入口 MUST 输出可观察结果用于联调与验收。

#### Scenario: 本地快速联调
- **WHEN** 开发或测试人员在 Urban 客户端触发 MinimalWebHost 测试
- **THEN** 系统 SHALL 在当前会话内返回测试结果
- **AND** SHALL 明确显示成功或失败状态

### Requirement: UrbanManagement 地址配置与测试链路一致
MaterialClient.Urban 的 MinimalWebHost 测试流程 MUST 读取 `UrbanManagement:BaseUrl` 作为目标服务地址，并与业务上传链路保持一致的配置来源。

#### Scenario: 配置一致性
- **WHEN** `UrbanManagement:BaseUrl` 在 `appsettings` 或 secret 配置中被修改
- **THEN** MinimalWebHost 测试 SHALL 使用更新后的地址
- **AND** SHALL 不使用硬编码地址覆盖配置值
