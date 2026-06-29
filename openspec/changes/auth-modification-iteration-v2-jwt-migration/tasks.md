# 1. F4 服务端 machineCode 设备绑定（P0 · UrbanManagement）

- [ ] 1.1 `Models/JwtAntiTamperResult.cs`：新增 `RevocationReason` 枚举（`DEVICE_CHANGED`、`EXPIRED`、`NOT_FOUND`、`INVALID_SIGNATURE`、`UNREACHABLE` 等）及可空属性；现有失败路径补填对应枚举值
- [ ] 1.2 `Services/JwtAntiTamperService.cs:VerifyAndCompareAsync`：在 `FindAsync(proId)` 成功之后、`TryGetBasePlatformJwtAsync` 之前，从已验签 `principal` 提取 `machineCode` claim，与 `project.MachineCode` 比对
- [ ] 1.3 比对不一致 → 返回 `Passed=false`、`RevocationReason=DEVICE_CHANGED`、`Reason="授权设备已变更，请在当前设备重新激活"`，不调 BasePlatform
- [ ] 1.4 提交 JWT 缺 `machineCode` claim → 返回 `Passed=false` 并标记原因，不调 BasePlatform
- [ ] 1.5 确认 `DeviceStatusHub.VerifyJwtAsync` 透传新增的 `RevocationReason`（SignalR 序列化兼容）

# 2. F4 客户端设备变更终止处理（P0 · MaterialClient）

- [ ] 2.1 `Common/Services/DeviceStatusSignalRClient.cs:SyncProjectLicenseFromServerAsync`：解析 `antiTamperResult.RevocationReason`
- [ ] 2.2 `RevocationReason == DEVICE_CHANGED` 时：清除 `LicenseInfo.LatestJwtToken`（置空并持久化）
- [ ] 2.3 弹出仅含在线激活入口的 `UnauthorizedNoticeWindow`；用户取消则退出应用（不闪退）
- [ ] 2.4 其它失败类型（`EXPIRED`/`NOT_FOUND`/`INVALID_SIGNATURE`/`UNREACHABLE`）保持既有「记录告警 + 跳过同步」行为，不清 JWT、不终止

# 3. F1 离线授权 UI 裁剪（P0 · MaterialClient）

- [ ] 3.1 删除 `Views/Dialogs/UnauthorizedNoticeWindow.axaml` 中离线授权 UI 区域（约 29-53 行相关区块）及 code-behind 关联逻辑
- [ ] 3.2 删除 `UrbanActivationUiOptions.cs` 的 `ShowOfflineActivationUi` 常量及其所有消费点
- [ ] 3.3 未授权窗仅保留「在线激活」入口（接入码输入 + 本机机器码展示/复制 + 在线激活按钮 + 退出）
- [ ] 3.4 检查并删除设置页中「离线授权」相关 UI 区域与引导文案（若有）
- [ ] 3.5 保留 `license.urban` bootstrap 读取代码路径与 `StaticLicenseChecker`（无 UI 交互）

# 4. F2 提交机器码端到端（P1 · 两仓库）

- [ ] 4.1 MaterialClient `Entities/Urban/UrbanWeighingExtension.cs`：新增 `SubmitMachineCode`（可空 string）
- [ ] 4.2 MaterialClient `Dtos/UrbanWeighingRecordSubmitDto.cs`：新增 `submitMachineCode` 字段
- [ ] 4.3 MaterialClient `Services/UrbanServerUploadService.cs`：提交时由 `MachineCodeService.GetMachineCode()` 写入 Extension 与 DTO
- [ ] 4.4 MaterialClient（SQLite）EF 映射 + 新 Migration：`UrbanWeighingExtensions.SubmitMachineCode TEXT NULL`
- [ ] 4.5 UrbanManagement `Entities/UrbanWeighingRecord.cs`：新增 `SubmitMachineCode`（可空 string）
- [ ] 4.6 UrbanManagement EF Core 映射 + 新 Migration：`UrbanWeighingRecords.SubmitMachineCode NVARCHAR(128) NULL`
- [ ] 4.7 UrbanManagement 接收逻辑（`ReceiveAsync` 及 DTO）：透传 `submitMachineCode` 写入记录，不校验

# 5. F3 ABP 审计字段标准化（P1 · 两仓库）

- [ ] 5.1 UrbanManagement 实体（`GovProject`、`GovSyncData`、`GovLog`、`UrbanWeighingExtension`）实现 `IHasCreationTime`（按需 `FullAudited*`）；`UrbanWeighingRecord` 仅 `IHasCreationTime`（无用户上下文）
- [ ] 5.2 移除领域方法/应用服务中手动审计赋值（`AddTime=DateTime.Now`、`CreatorUserId=...`、`LastModificationTime=...`），含 `ReceiveAsync` 中 `AddTime` 手动赋值
- [ ] 5.3 UrbanManagement EF Core 映射 + Migration：`AddTime → CreationTime` 列重命名 + `UPDATE` 回填（或过渡 `HasColumnName("AddTime")`）
- [ ] 5.4 `GovSyncWorker` 政府出站 DTO 独立映射（AutoMapper Profile/手动），保持协议字段名 `addTime`
- [ ] 5.5 MaterialClient `Common`：新增 `SaveChangesInterceptor`，`Added→CreationTime`、`Modified→LastModificationTime`，并注册
- [ ] 5.6 MaterialClient `LicenseInfo`：`CreatedAt/UpdatedAt` 对齐拦截器自动填充（保留或映射至标准名）

# 6. 跨项目依赖（BasePlatform · 本 change 不实现，记录供协调）

- [ ] 6.1 F1-2：BasePlatform 后台 `DownloadUrbanLicense` 下载授权管理页 UI 隐藏（CSS `display:none`）；`GET /api/auth/license-file` API 保留
- [ ] 6.2 F4-3（可选增强）：BasePlatform `LicenseFileAppService.BuildLicenseFileAsync` 增加 `request.MachineCode != productAuth.MachineCode` 校验

# 7. 联调验收（用户负责）

- [ ] 7.1 Case 1：PC_A 激活→PC_B 同项目再激活→PC_A 连接服务端被判定 `DEVICE_CHANGED` 并终止
- [ ] 7.2 Case 2：同 PC 修改授权时间后重新激活→`VerifyJwtAsync` 正常返回 ServerJwt 并更新
- [ ] 7.3 F2：提交称重数据后 UrbanManagement 记录的 `SubmitMachineCode` 与客户端机器码一致
- [ ] 7.4 F1：未授权/启动失败仅出现在线激活入口，无离线导入 UI
- [ ] 7.5 F3：历史 `AddTime` 数据正确迁移至 `CreationTime`；政府出站字段名不变
