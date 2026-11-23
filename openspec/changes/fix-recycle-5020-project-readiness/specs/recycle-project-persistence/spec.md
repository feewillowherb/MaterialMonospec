## ADDED Requirements

### Requirement: Recycle 项目就绪验证

Recycle 联调环境 SHALL 使用有效的 5020 项目及可信 SourceProId，并验证已授权用户可以读取该项目业务台账。

#### Scenario: 有效项目已绑定

- **WHEN** 已应用 Recycle 迁移且授权用户访问已绑定的有效 5020 项目
- **THEN** 业务列表成功读取，仅返回该项目数据

#### Scenario: 项目缺失或绑定错误

- **WHEN** 配置项无法解析到有效 5020 项目
- **THEN** 业务请求返回明确的项目未绑定错误，且无业务记录写入
