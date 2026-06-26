## 1. LicenseInfo 实体与 Migration（P-Client-1）

- [x] 1.1 将 `LicenseInfo.BuildLicenseNo` 重命名为 `AccessCode`
- [x] 1.2 删除 `LicenseInfo.FdBuildLicenseNo` 属性及所有代码引用（grep 全仓清理）
- [x] 1.3 删除 `LicenseInfo.AuthToken` 属性及所有代码引用
- [x] 1.4 生成并应用 EF Core Migration（RenameColumn + DropColumn）
- [x] 1.5 更新 `LicenseCheckResult`：`BuildLicenseNo` → `AccessCode`；移除 `FdBuildLicenseNo`
- [x] 1.6 更新 `UrbanServerUploadService`、`UrbanAttachmentSyncService` 等使用 `AccessCode`

## 2. StaticLicenseChecker JWT 验权（P-Client-1）

- [x] 2.1 设置 `ValidIssuer = "BasePlatform"`；拒绝其它 issuer（无 LegacyIssuers）
- [x] 2.2 从 claim `accessCode` 提取接入码；拒绝仅含 `buildLicenseNo` / `fdBuildLicenseNo` 的 JWT
- [x] 2.3 新增 `machineCode` claim 校验（与本机一致）
- [x] 2.4 更新 `appsettings.json` 中 `Jwt:PublicKey` 为 BasePlatform 公钥
- [x] 2.5 更新 `IStaticLicenseChecker` 接口与实现签名/文档

## 3. 启动门禁与 bootstrap（P-Client-1）

- [x] 3.1 改造 `MaterialClientUrbanModule.TryExecuteStartupLicenseCheckAsync`：持久化 `AccessCode`
- [x] 3.2 从 `license.urban` bootstrap 成功时回写 `LatestJwtToken`
- [x] 3.3 确认启动失败路径不写 `LicenseInfo`、不进入主界面

## 4. 在线激活 activate（P-Client-2）

- [x] 4.1 在 `IUrbanAuthApi` 添加 `POST /api/urban/auth/activate` Refit 方法（Urban 模块注册）
- [x] 4.2 定义 `ActivateUrbanRequest` / `ActivateUrbanResponseData`（命名 record / class）
- [x] 4.3 在 `ILicenseService` / `LicenseService` 实现 `ActivateUrbanAsync`（`[UnitOfWork]`）
- [x] 4.4 新建 Urban 专用授权对话框（展示 MachineCode、输入接入码）
- [x] 4.5 未授权提示增加「在线激活」入口（或等价触发方式）
- [x] 4.6 确认 5001 不走 `VerifyAuthorizationCodeAsync` 直连 BasePlatform

## 5. SignalR 同步对齐 Urban V2（P-Client-1/2）

- [x] 5.1 更新 `DeviceStatusSignalRClient.SyncProjectLicenseFromServerAsync`：`buildLicenseNo` → `AccessCode`
- [x] 5.2 移除 `SyncProjectFieldsFromServerAsync` 的 `fdBuildLicenseNo` 参数及调用
- [x] 5.3 更新 `StoreServerJwtAsync` 签名：接入码参数改为 `accessCode`
- [x] 5.4 更新 `JwtAntiTamperResult`、`ClientProjectLicenseInfoDto` 映射注释与落库逻辑

## 6. UpdateClientLicense 可选推送（P-Client-3）

- [x] 6.1 注册 SignalR `UpdateClientLicense` handler
- [x] 6.2 验签后复用 `StoreServerJwtAsync` 更新 `LatestJwtToken` 与 `AccessCode`

## 7. 联调与验证（由用户执行与勾选）

> 本节为人工联调清单；**未勾选不代表实现缺口**，仅作验收记录。

- [ ] 7.1 JWT `iss=BasePlatform` + `accessCode` + `machineCode` 启动通过
- [ ] 7.2 JWT `iss=UrbanManagement` 被拒绝
- [ ] 7.3 JWT 无 `accessCode`（仅旧 claim）被拒绝
- [ ] 7.4 `activate` 成功写入 `LatestJwtToken`；无 `AuthToken` / `FdBuildLicenseNo`
- [ ] 7.5 Hub `VerifyJwtAsync` 覆盖 `LatestJwtToken`；`GetClientProjectLicenseInfo` 同步 `AccessCode`
- [ ] 7.6 `license.urban` bootstrap 后 DB 含 `LatestJwtToken`
- [ ] 7.7 与 Urban V2 + BasePlatform 端到端联调
