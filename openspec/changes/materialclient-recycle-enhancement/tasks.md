# Tasks — MaterialClient Recycle Enhancement

## 1. 数据模型与迁移

- [ ] 1.1 `Provider.cs` 新增可空 `Address` 属性（string?），加 XML 注释说明本地专用、§2.2 consigneeAddress 数据源
- [ ] 1.2 新增 `RecycleWaybillExtension.cs` 实体：`Entity<Guid>`；`WaybillId`(long) 逻辑关联（无 DB FK、无 EF 导航，遵循 `UrbanWeighingExtension`）；`UnitPrice`(decimal?)/`SaleContractNo`(string?)/`ReceivingTime`(DateTime?)
- [ ] 1.3 `MaterialClientDbContext` 注册 `DbSet<RecycleWaybillExtension>`（表名 `RecycleWaybillExtensions`）
- [ ] 1.4 新增 EF Core 迁移 `<timestamp>_RecycleEnhancementFields`：Provider.Address 列 + 新建 `RecycleWaybillExtension` 表，`Up`/`Down` 对称
- [ ] 1.5 本地验证迁移可正向应用与回滚

## 2. Provider.Address 本地字段链路

- [ ] 2.1 `ProviderDto.cs` 新增 `Address` 属性
- [ ] 2.2 `MaterialProviderListResultDto.ToEntity` 确保 `Address` 保持默认 null（远端无此字段，不覆盖）
- [ ] 2.3 `ProviderService.CreateProviderAsync` 增可选 `string? address` 入参；远端 `CreateProvider` 返回后、本地 upsert 前回填 `Address`
- [ ] 2.4 `ProviderService.GetPagedProvidersAsync` 三个投影分支均带回 `Address`
- [ ] 2.5 `MaterialProviderSyncService` 删表重建前按 Id 快照 `Address`，重建后回填（保留本地值）
- [ ] 2.6 `ProviderEditWindow.axaml`/`ProviderManagementWindow.axaml` 展示并允许编辑 `Address`

## 3. §2.2 DTO 映射补全

- [ ] 3.1 `RecycleTransportRecord.FromWaybill` 扩展签名与赋值：`UnitPrice`、`SaleContractNo`、`ReceivingTime`（格式化 `yyyy-MM-dd HH:mm:ss`）、`ReceivingProof`、`ConsigneeAddress`
- [ ] 3.2 更新 `OutPhotos` XML 注释为「进场+出场照片，进场在前」
- [ ] 3.3 确认 `ForLogging()` 对 `ReceivingProof` 的脱敏保持有效

## 4. Recycle 表单录入（单价/合同号）

- [ ] 4.1 `RecycleWeighingDetailViewModel` 新增 `[Reactive] UnitPrice`（decimal?）、`[Reactive] SaleContractNo`（string?）
- [ ] 4.2 `LoadRecycleDataAsync` 的 Waybill 分支按 `WaybillId` 从 `RecycleWaybillExtension` 回填 `UnitPrice`/`SaleContractNo`
- [ ] 4.3 `SaveModeSpecificAsync`/`CompleteModeSpecificAsync` 将两值放入 `UpdateRecycleModeInput`
- [ ] 4.4 `RecycleModeFormView.axaml` 新增「单价」「合同编号」两行（Grid 72,*，FontSize 12，与既有行风格一致）

## 5. Recycle 领域服务

- [ ] 5.1 `UpdateRecycleModeInput` record 新增 `UnitPrice`、`SaleContractNo`
- [ ] 5.2 `RecycleWeighingService.UpdateRecycleModeAsync` Waybill 分支按 `WaybillId` upsert `RecycleWaybillExtension`（`UnitPrice`/`SaleContractNo`，含 null 置空），维持 Waybill `SetPendingSync()`

## 6. 收货功能（替换打印）

- [ ] 6.1 新增 `IRecycleReceivingService`/`RecycleReceivingService`（`[UnitOfWork]`、ABP 约定注册 + `[AutoConstructor]`）：`ConfirmAsync(waybillId, receivingTime, imageStream)`
- [ ] 6.2 `ConfirmAsync` 经 `AttachmentService` 落盘为 `AttachmentFile(AttachType.TicketPhoto)`，建 `WaybillAttachment` 关联，按 `WaybillId` upsert `RecycleWaybillExtension.ReceivingTime`，Waybill `SetPendingSync()`
- [ ] 6.3 新增收货对话框 ViewModel（`receivingTime`、图片选择/预览、必填校验、确认/取消）
- [ ] 6.4 新增收货对话框 View（DatePicker+时间选择、图片选择/预览、确认/取消按钮）
- [ ] 6.5 `AttendedWeighingViewModel`：Recycle+Completed 时屏蔽打印按钮显示，新增 `ReceiveCommand`/`CanReceive`，打开收货对话框并在确认后刷新状态
- [ ] 6.6 `AttendedWeighingMainView.axaml`：Recycle 模式行操作显示「收货」，SolidWaste 保持「打印」

## 7. 后台同步（照片与字段透传）

- [ ] 7.1 `RecycleDataSyncService` 新增 `ExitPhoto` 类型常量用于 §2.2；新增 `BuildExitPhotosBase64Async` 并与进场侧合并（进场在前）
- [ ] 7.2 §2.2 `outPhotos` 使用进场+出场聚合；§2.3 `inPhoto` 维持仅进场侧
- [ ] 7.3 新增 `BuildReceivingProofBase64Async`（读取 `TicketPhoto` 附件，缺失返回 null 并记日志）
- [ ] 7.4 `SubmitSendingAsync` 按 `WaybillId` 读 `RecycleWaybillExtension` 取 `UnitPrice`/`SaleContractNo`/`ReceivingTime`；解析 `Provider.Address` → `consigneeAddress`；将 `UnitPrice`/`SaleContractNo`/`ReceivingTime`/`ReceivingProof`/`consigneeAddress` 透传 `FromWaybill`
- [ ] 7.5 §2.2 上报日志（`ForLogging()`）确认新字段可见且敏感照片脱敏

## 8. 测试

- [ ] 8.1 单测：`RecycleTransportRecord.FromWaybill` 五字段映射（含 null 分支）与 `outPhotos` 进场+出场顺序
- [ ] 8.2 单测：`BuildExitPhotosBase64Async`/`BuildReceivingProofBase64Async` 聚合、缺失文件跳过
- [ ] 8.3 单测：`RecycleReceivingService.ConfirmAsync` 成功落盘 + 异常事务回滚
- [ ] 8.4 单测：`ProviderService.CreateProviderAsync` 回填 Address；`MaterialProviderSyncService` 重建保留 Address
- [ ] 8.5 单测：`RecycleWeighingService.UpdateRecycleModeAsync` 按 `WaybillId` upsert `RecycleWaybillExtension`（存在更新/不存在插入，含 null 置空）
- [ ] 8.6 集成测试：收货 → 后台同步端到端，断言 §2.2 payload 含全部新字段与进场+出场照片
- [ ] 8.7 UI 测试：Recycle 显示「收货」、SolidWaste 显示「打印」；收货必填校验；表单回填

## 9. 构建验证与文档

- [ ] 9.1 `dotnet build MaterialClient.sln -o .build-verify` 通过（避开文件锁）
- [ ] 9.2 运行新增/相关单测与集成测试通过
- [ ] 9.3 更新相关 XML 注释/文档，确认无中文字符出现在代码标识符（注释除外）
