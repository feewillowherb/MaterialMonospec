## ADDED Requirements

### Requirement: 提交 JWT 的 machineCode 设备绑定校验

`JwtAntiTamperService.VerifyAndCompareAsync` SHALL 在 RS256 验签通过、查询到 `GovProject` 之后、调用 BasePlatform 获取新 JWT 之前，提取**提交 JWT 的 `machineCode` claim** 并与 `GovProject.MachineCode`（权威机器码）比对。两者不一致时 SHALL 返回 `Passed = false` 并以 `DEVICE_CHANGED` 标记原因，表明授权设备已变更。

#### Scenario: machineCode 一致正常通过

- **WHEN** 提交 JWT 的 `machineCode` claim 与 `GovProject.MachineCode` 一致
- **THEN** SHALL 继续既有流程（调用 BasePlatform 获取新 JWT）
- **AND** SHALL 返回 `Passed = true`、`ServerJwt` 为 BasePlatform 新签发 JWT

#### Scenario: machineCode 不一致返回设备变更失败

- **WHEN** 提交 JWT 的 `machineCode` claim 与 `GovProject.MachineCode` 不一致（如旧设备在跨设备重新激活后连接）
- **THEN** SHALL 返回 `Passed = false`
- **AND** `Reason` SHALL 标记设备变更（如 `DEVICE_CHANGED:授权设备已变更，请在当前设备重新激活`）
- **AND** `RevocationReason` SHALL 标记为设备变更类型
- **AND** SHALL NOT 调用 BasePlatform API 获取新 JWT
- **AND** `ServerJwt` SHALL 为 null

#### Scenario: 提交 JWT 缺少 machineCode claim

- **WHEN** 提交 JWT 通过签名验证但不含 `machineCode` claim
- **THEN** SHALL 返回 `Passed = false`，`Reason` 指示令牌缺少设备绑定信息
- **AND** SHALL NOT 调用 BasePlatform API

## MODIFIED Requirements

### Requirement: JwtAntiTamperResult DTO

`JwtAntiTamperResult` SHALL 在原有属性（`Passed`、`Reason`、`ServerJwt`、`ProName`、`BuildLicenseNo`、`FdBuildLicenseNo`、`AuthEndTime`）基础上新增 `RevocationReason`（可空枚举/字符串），用于区分失败类型（`DEVICE_CHANGED`、`EXPIRED`、`NOT_FOUND`、`INVALID_SIGNATURE` 等），便于客户端对设备变更采取终止运行的差异化处理。

#### Scenario: 设备变更失败结果

- **WHEN** 因 machineCode 不一致返回 `Passed = false`
- **THEN** `RevocationReason` SHALL 为 `DEVICE_CHANGED`
- **AND** `Reason` SHALL 包含面向用户的中文提示
- **AND** `ServerJwt` SHALL 为 null
