## 1. 扩展 LicenseCheckResult 携带授权数据

- [x] 1.1 在 `LicenseCheckResult` 类中新增 `ProId` (Guid)、`ProName` (string?)、`BuildLicenseNo` (string?)、`FdBuildLicenseNo` (string?)、`AuthEndTime` (DateTime) 属性
- [x] 1.2 更新 `LicenseCheckResult.Success()` 静态工厂方法，支持传入授权数据参数

## 2. 扩展 LicenseInfo 实体

- [x] 2.1 在 `LicenseInfo.cs` 中新增 `ProName` (string?)、`BuildLicenseNo` (string?)、`FdBuildLicenseNo` (string?) 属性
- [x] 2.2 更新 `LicenseInfo` 构造函数，接收新增字段参数
- [x] 2.3 更新 `LicenseInfo.Update()` 方法，支持更新新增字段
- [x] 2.4 创建 EF Core 迁移，为 LicenseInfo 表添加 ProName、BuildLicenseNo、FdBuildLicenseNo 三个 nullable 列

## 3. 修改 StaticLicenseChecker 返回硬编码测试数据

- [x] 3.1 定义测试常量：固定的 ProId、ProName、BuildLicenseNo、FdBuildLicenseNo 值，以及硬编码的授权过期时间 `AuthEndTime`（使用 `DateTime.Now.AddYears(1)` 一年有效期，与 `LicenseService.VerifyAuthorizationCodeTestAsync` 保持一致）
- [x] 3.2 修改 `StaticLicenseChecker.CheckLicenseAsync()` 返回包含硬编码测试数据的 `LicenseCheckResult`

## 4. 启动流程写入 LicenseInfo

- [x] 4.1 在 `MaterialClientUrbanModule.OnApplicationInitializationAsync` 中，静态授权检查成功后，从 `LicenseCheckResult` 读取 ProId/ProName/BuildLicenseNo/FdBuildLicenseNo/AuthEndTime
- [x] 4.2 通过 `IRepository<LicenseInfo, Guid>` 写入或更新 LicenseInfo 记录（在 UnitOfWork 中执行）
- [x] 4.3 处理授权检查失败的情况：不修改 LicenseInfo，记录警告日志，非阻塞继续启动

## 5. 修复称重记录上传数据流

- [x] 5.1 在 `UrbanWeighingRecordSubmitDto.cs` 中新增 `[JsonPropertyName("fdBuildLicenseNo")] public string? FdBuildLicenseNo` 字段
- [x] 5.2 修改 `UrbanServerUploadService` 构造函数，注入 `ILicenseService`
- [x] 5.3 修改 `UrbanServerUploadService.SubmitRecordAsync()`，从 `ILicenseService.GetCurrentLicenseAsync()` 读取 LicenseInfo
- [x] 5.4 填充 DTO：将 LicenseInfo 的 ProId（ToString）、ProName、BuildLicenseNo、FdBuildLicenseNo 赋值到 DTO，替代当前的 null 硬编码
- [x] 5.5 处理 LicenseInfo 不存在的情况：保持字段为 null，记录警告日志

## 6. 服务端扩展 FdBuildLicenseNo

- [x] 6.1 在 `UrbanWeighingRecord.cs` 实体中新增 `FdBuildLicenseNo` (string?) 属性
- [x] 6.2 在 `UrbanWeighingRecordDtos.cs`（接收 DTO）中新增 `FdBuildLicenseNo` 字段
- [x] 6.3 在 `UrbanWeighingRecordAppService` 中确保 `FdBuildLicenseNo` 从 DTO 正确映射到实体
- [x] 6.4 创建 EF Core 迁移，为 UrbanWeighingRecord 表添加 FdBuildLicenseNo nullable 列

## 7. 验证与测试

- [ ] 7.1 运行 MaterialClient.Urban 应用，确认启动时 LicenseInfo 正确写入（检查数据库记录）
- [ ] 7.2 执行称重流程，确认 UrbanWeighingRecordSubmitDto 携带正确的 ProId/ProName/BuildLicenseNo/FdBuildLicenseNo
- [ ] 7.3 确认服务端收到并持久化包含 FdBuildLicenseNo 的称重记录
- [ ] 7.4 确认设备状态消息携带 ProName，设备管理页面以 ProName 展示和筛选正常

## 8. 设备管理 ProId 关联 — 服务端消息协议

- [x] 8.1 在 `DeviceStatusMessage` 中新增 `ProId` (string) 字段 `[JsonPropertyName("proId")]` 和 `ProName` (string) 字段 `[JsonPropertyName("proName")]`
- [x] 8.2 更新 `DeviceStatusService.HandleStatusUploadAsync()`，缓存消息时以 ProId 为主键
- [x] 8.3 更新 `DeviceStatusQueryDto`，新增 `ProId` 和 `ProName` 属性，`FromMessage()` 映射新增字段
- [x] 8.4 更新 `DeviceStatusListRequestDto`，新增 `ProId` (string?) 筛选字段（替代 ClientId 的精确筛选场景）

## 9. 设备管理 ProId 关联 — 服务端查询与聚合

- [x] 9.1 修改 `DeviceStatusAppService`，聚合主键从 ClientId 改为 ProId（按 ProId + DeviceType 取最新状态）
- [x] 9.2 修改 `DeviceStatusAppService` 的筛选逻辑，支持按 ProId 筛选
- [x] 9.3 更新客户端注册表（`DeviceStatusService` 的 client registry），改为以 ProId 为主键维护
- [x] 9.4 返回结果中包含 ProName 用于 UI 展示

## 10. 设备管理 ProId 关联 — 服务端管理页面 UI

- [x] 10.1 修改 `DeviceManagement/Index.cshtml`，列表展示 ProName 列（展示名称），使用 ProId 作为行标识
- [x] 10.2 修改筛选区域，将 ClientId 输入框改为 ProId/ProName 搜索
- [x] 10.3 更新 SignalR 实时更新回调，从 `message.clientId` 改为 `message.proName` 展示，`message.proId` 作为键
- [x] 10.4 确保分页查询参数使用 ProId 而非 ClientId

## 11. 设备管理 ProId 关联 — 客户端发送

- [x] 11.1 修改 `DeviceStatusEventHandler`，注入 `ILicenseService`，从 `LicenseInfo` 读取 ProId（ProjectId.ToString()）和 ProName
- [x] 11.2 构造 `DeviceStatusMessage` 时，填充 ProId（主键）和 ProName（展示名称）
- [x] 11.3 处理 LicenseInfo 不存在的情况：ProId 和 ProName 使用空字符串，服务端降级使用 ClientId
