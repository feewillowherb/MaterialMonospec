## 1. ABP 模块集成

- [ ] 1.1 在 `MaterialClient.Urban.csproj` 中添加 ABP NuGet 包（`Volo.Abp.Autofac`、`Volo.Abp.Core`）
- [ ] 1.2 创建 `MaterialClientUrbanModule.cs`，声明 `[DependsOn(typeof(MaterialClientCommonModule), typeof(AbpAutofacModule))]`
- [ ] 1.3 在模块中实现 `ConfigureServices`：配置 Serilog 日志，按日滚动（与 MaterialClient 模式一致）
- [ ] 1.4 实现 `OnApplicationInitializationAsync`：通过 `IUnitOfWorkManager` + `IDbContextProvider<MaterialClientDbContext>` 执行数据库迁移，通过 `IStaticLicenseChecker` 执行静态授权检查
- [ ] 1.5 重写 `App.axaml.cs`：用手动 `ServiceCollection` 替换为 `AbpApplicationFactory.CreateAsync<MaterialClientUrbanModule>(options => options.UseAutofac())`，从 ABP 容器解析窗口
- [ ] 1.6 实现 `OnApplicationExit`，遵循 AGENTS.md 退出顺序：释放 ViewModel → 关闭硬件 → ABP ShutdownAsync → Serilog flush，10 秒超时保护
- [ ] 1.7 在 ABP 模块服务中注册 `UrbanAttendedWeighingWindow` 和 `UrbanAttendedWeighingViewModel`（或通过 `ITransientDependency` / `ISingletonDependency` 标记）

## 2. 服务接口重构

- [ ] 2.1 在 `ISettingsService` 接口中添加 `GetProductCodeAsync()` 方法 — 将 `WeighingMode` 映射为 `ProductCode`（Standard→5000, SolidWaste→5010, UrbanMode→5030）
- [ ] 2.2 在 `SettingsService` 中实现 `GetProductCodeAsync()` — 从设置中读取 `WeighingMode` 并返回映射的 `ProductCode`
- [ ] 2.3 扩展 `SaveDefaultWeighingModeAsync` 以处理 `ProductCode.Urban` → `WeighingMode.UrbanMode` 映射（当前仅处理 Standard/SolidWaste）
- [ ] 2.4 删除 `MaterialClient.Urban/Services/UrbanWeighingService.cs`（包含 `IUrbanWeighingService` 接口和 `UrbanWeighingService` 实现）
- [ ] 2.5 从 `App.axaml.cs` 中移除 `IUrbanWeighingService` 注册（由 ISettingsService 替代）

## 3. 移除重复实体模型

- [ ] 3.1 删除 `MaterialClient.Urban/Models/WeighingRecord.cs` — 替换为 `MaterialClient.Common.Entities.WeighingRecord`
- [ ] 3.2 删除 `MaterialClient.Urban/Models/DeviceStatus.cs` — 内联为简单的 record struct 或移至 ViewModel
- [ ] 3.3 更新 ViewModel，仅使用 `MaterialClient.Common.Entities.WeighingRecord`（移除 `MaterialClient.Urban.Models` 导入）
- [ ] 3.4 更新 XAML 的 `x:DataType`，从 `models:WeighingRecord` 改为 Common 实体类型
- [ ] 3.5 更新 XAML 绑定：`LicensePlate` → `PlateNumber`、`Weight` → `TotalWeight`、`WeighingTime` → `AddDate`（添加格式化字符串）、`IsNormal` → 基于 `SyncStatus` 的可见性

## 4. 窗口重命名

- [ ] 4.1 将 `Views/WeighingSystemWindow.axaml` 重命名为 `Views/UrbanAttendedWeighingWindow.axaml`
- [ ] 4.2 将 `Views/WeighingSystemWindow.axaml.cs` 重命名为 `Views/UrbanAttendedWeighingWindow.axaml.cs`，更新类名和命名空间引用
- [ ] 4.3 将 `ViewModels/WeighingSystemViewModel.cs` 重命名为 `ViewModels/UrbanAttendedWeighingViewModel.cs`，更新类名
- [ ] 4.4 更新 `App.axaml.cs` 中所有 `WeighingSystemWindow` / `WeighingSystemViewModel` 引用为 `UrbanAttendedWeighingWindow` / `UrbanAttendedWeighingViewModel`
- [ ] 4.5 检查并更新 `UrbanWeighingPipelineStrategy.cs` 中的引用（如有）

## 5. 样式对齐与布局重构

- [ ] 5.1 更新 `App.axaml`，引入 MaterialClient 共享样式资源（颜色画刷、按钮样式、card-border、section-border、DataGrid 样式）
- [ ] 5.2 移除 `UrbanAttendedWeighingWindow.axaml` 中所有内联 `Window.Styles`（约 130 行自定义的 header-menu-btn、titlebar-btn、tab-btn 等）
- [ ] 5.3 应用 MaterialClient 共享样式类：标题栏按钮使用 `titlebar-close-button`、`titlebar-minimize-button`、`popup-menu-item-button`
- [ ] 5.4 操作按钮（搜索、审批）应用 `primary-button` 样式，Tab 导航使用 `tab-button` / `tab-button.active`
- [ ] 5.5 将布局从两列（内容 + 照片）重构为三列（记录列表 280px + 主内容区 * + 照片区 360px），匹配 AttendedWeighingWindow
- [ ] 5.6 标题栏背景从 `#0F172A`（暗色）改为 `#4169E1`（MaterialClient 蓝色），重量区从 `#1E293B` 改为 `#4A85F9` 渐变
- [ ] 5.7 状态栏背景从 `#1E293B` 改为 `#F5F5F5`（与 MaterialClient 一致）
- [ ] 5.8 内容区域边框应用 `card-border` 和 `section-border` 样式

## 6. 验证

- [ ] 6.1 构建并验证无编译错误
- [ ] 6.2 验证 ABP 模块初始化成功（检查控制台输出的模块加载信息）
- [ ] 6.3 验证启动时数据库迁移正常运行
- [ ] 6.4 验证窗口使用 MaterialClient 样式布局正确显示
- [ ] 6.5 验证数据绑定与 Common 实体正常工作（记录列表填充、重量显示更新）
- [ ] 6.6 验证应用退出时正确清理资源，无挂起
