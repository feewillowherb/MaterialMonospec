## ADDED Requirements

### Requirement: Recycle 在线激活绑定机器码
Recycle（ProductCode **5020**）在线激活 SHALL 要求激活码与本机 `MachineCode`。操作员 UI SHALL 只要求填写激活码；机器码 SHALL 由客户端自动采集并提交。激活成功后 SHALL 持久化 JWT/项目标识并进入称重主界面。

#### Scenario: 激活请求含机器码
- **WHEN** 用户提交激活码
- **THEN** 客户端 SHALL 将 `ProductCode=5020`、激活码与本机 `MachineCode` 提交至在线激活接口
- **AND** SHALL NOT 以缺少机器码的 `GetAuthClientLicense` 作为产品主路径

#### Scenario: 激活成功进主界面
- **WHEN** 在线激活返回成功 JWT 与项目信息
- **THEN** 客户端 SHALL 持久化本地授权
- **AND** SHALL 进入 Recycle 称重主界面

### Requirement: PublicApi 对 5020 与 5001 同形激活
BasePlatform PublicApi 的在线激活与 JWT 签发 SHALL 接受 ProductCode **5020**，行为与 **5001** 同形：校验 Redis 一次性码、回写 `JC_ProductAuthority.MachineCode`、签发 JWT。BasePlatform 管理端 UI SHALL NOT 为本次能力改版。

#### Scenario: 5020 激活成功
- **WHEN** PublicApi 收到合法 5020 激活码与非空 MachineCode
- **THEN** SHALL 消费 Redis 码、回写 MachineCode、返回 JWT
- **AND** SHALL NOT 仅因 ProductCode 为 5020 而拒绝

#### Scenario: 发码载荷含 AccessCode
- **WHEN** BasePlatform 为 ProductCode 5020 调用 `SendAuthLicense`
- **THEN** Redis 载荷 SHALL 包含 `AccessCode`（与 5001 同形字段）
