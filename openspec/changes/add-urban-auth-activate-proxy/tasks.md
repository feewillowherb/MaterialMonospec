## 1. DTO 与 BasePlatform Refit 客户端

- [ ] 1.1 在 `UrbanManagement.Core.Models` 新增 `ActivateUrbanRequestDto`、`ActivateUrbanResponseData`（与 BasePlatform JSON 字段对齐；使用 class 或 record，禁止 tuple）
- [ ] 1.2 在 `IBasePlatformAuthHttpClient` 新增 `[Post("/api/auth/activate-urban")] ActivateAsync` 方法
- [ ] 1.3 确认 `UrbanManagementAppModule` 中 Refit 注册无需额外配置（与现有 `GetLicenseFileAsync` 共用客户端）

## 2. 激活 AppService

- [ ] 2.1 新增 `IUrbanAuthActivateAppService` / `UrbanAuthActivateAppService`（接口与实现同文件，符合 AGENTS）
- [ ] 2.2 实现入参校验：`productCode == 5001`、`code` / `machineCode` 非空
- [ ] 2.3 调用 `_basePlatformAuthClient.ActivateAsync` 并映射 `BasePlatformApiResponse` 为对外响应 DTO
- [ ] 2.4 成功时按 `data.proId` 更新 `GovProject.MachineCode`、`AccessCode`、`AuthEndTime`（`[UnitOfWork]`）
- [ ] 2.5 BasePlatform 失败时不写 `GovProject`；记录错误日志（不记录完整授权码）

## 3. 对外 HTTP 路由

- [ ] 3.1 新增 `UrbanAuthController`（`UrbanManagement.App`）：`[Route("api/urban/auth")]` + `[HttpPost("activate")]`
- [ ] 3.2 Controller 委托 `IUrbanAuthActivateAppService.ActivateAsync`；`[AllowAnonymous]` 允许无登录客户端调用
- [ ] 3.3 禁用该 Controller 的 ABP 自动 RemoteService 暴露（若需要），避免路由冲突

## 4. 测试

- [ ] 4.1 新增 `UrbanAuthActivateAppServiceTests`：BasePlatform 成功 → `GovProject` 字段更新
- [ ] 4.2 测试 BasePlatform 失败 → 不更新 `GovProject`、返回失败消息
- [ ] 4.3 测试 `productCode != 5001` 与空 `machineCode` 校验拒绝
- [ ] 4.4 测试本地无 `GovProject` 时仍返回成功 JWT（Warning 路径）

## 5. 文档

- [ ] 5.1 更新 `repos/UrbanManagement/docs/BasePlatform-JWT-Endpoints.md`：补充 `POST /api/urban/auth/activate` 与内部 `activate-urban` 关系
- [ ] 5.2 移除或修订文档中「activate 未代理 / deferred」过时描述

## 6. 联调（用户负责）

- [ ] 6.1 MaterialClient `POST /api/urban/auth/activate` 端到端：Urban 200 → 客户端 `LatestJwtToken` 写入
- [ ] 6.2 验证 JWT `iss=BasePlatform`、含 `accessCode` / `machineCode` claims
- [ ] 6.3 验证激活后 Urban `GovProject.MachineCode` 与客户端一致
- [ ] 6.4 对照 vault `07-客户端服务端EPIC缺口对齐拟稿提案` §7 完成其余验收项
