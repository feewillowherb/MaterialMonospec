## 1. Common 层枚举与映射扩展

- [ ] 1.1 在 `MaterialClient.Common/Entities/Enums/WeighingMode.cs` 新增 `Recycle = 301` 枚举成员，添加 `[Description("资源化利用厂称重系统客户端软件")]`
- [ ] 1.2 在 `MaterialClient.Common/Entities/Enums/ProductCode.cs` 新增 `Recycle = 5020` 枚举成员，添加 `[Description("资源化利用厂称重系统客户端软件")]`
- [ ] 1.3 修改 `SettingsService.GetProductCodeAsync()` switch 表达式，新增 `WeighingMode.Recycle => ProductCode.Recycle` 分支
- [ ] 1.4 修改 `SettingsService.SaveDefaultWeighingModeAsync()` switch 表达式，新增 `ProductCode.Recycle => WeighingMode.Recycle` 分支
- [ ] 1.5 修改 `detail-viewmodel-hierarchy` 中 WeighingMode 分支逻辑，新增 `WeighingMode.Recycle` 复用 `SolidWasteWeighingDetailViewModel`

## 2. MaterialClient.Recycle 项目脚手架

- [ ] 2.1 创建 `src/MaterialClient.Recycle/` 项目目录结构（Api/、Models/、Services/、Backgrounds/）
- [ ] 2.2 创建 `MaterialClient.Recycle.csproj`，TargetFramework=net10.0，引用 MaterialClient.Common + MaterialClient.UI，添加 Avalonia + ABP + Refit + Serilog 包引用
- [ ] 2.3 在 `MaterialClient.sln` 添加 `MaterialClient.Recycle` 项目引用
- [ ] 2.4 创建 `Program.cs`（Mutex 单实例、zh-CN 文化、BuildAvaloniaApp）
- [ ] 2.5 创建 `App.axaml` + `App.axaml.cs`（ABP 初始化、授权检查、主窗口显示）
- [ ] 2.6 创建 `appsettings.json`（ProductCode=5020, RecycleSync 配置段）
- [ ] 2.7 创建 `appsettings.secret.json`（accessKey/secretKey 占位）

## 3. ABP 模块定义与服务注册

- [ ] 3.1 创建 `MaterialClientRecycleModule.cs`，定义 ABP Module 依赖（MaterialClientCommonModule、MaterialClientUiModule、AbpAutofacModule、AbpBackgroundWorkersModule）
- [ ] 3.2 实现 `ConfigureServices`：Serilog 配置、RecycleSyncOptions 绑定、Refit 客户端注册（IRecycleDataApi + RecycleHmacDelegatingHandler）
- [ ] 3.3 实现 `OnApplicationInitializationAsync`：数据库迁移、确保 DefaultWeighingMode=Recycle、授权检查、后台 Worker 启动
- [ ] 3.4 实现 `OnApplicationShutdownAsync`：停止后台服务、关闭 Serilog

## 4. RecycleTransportRecord DTO 与 Refit 接口

- [ ] 4.1 创建 `Models/RecycleTransportRecord.cs`（17 个字段：dataNo、pointNumber、carNo、productName、netWeight、tareWeight、grossWeight、outTime、outPhotos 等）
- [ ] 4.2 创建 `Models/RecycleApiResponse.cs`（Code、Msg、Data）
- [ ] 4.3 创建 `Api/IRecycleDataApi.cs` Refit 接口（POST addBatch，返回 RecycleApiResponse）
- [ ] 4.4 创建 `Models/RecycleSyncOptions.cs` 配置类（Enabled、ApiUrl、AccessKey、SecretKey、PointNumber、ProductName、PollIntervalSeconds、MaxFailCount、TimeoutSeconds）

## 5. HMAC-SHA256 签名服务

- [ ] 5.1 创建 `Services/RecycleHmacDelegatingHandler.cs`（DelegatingHandler 子类）
- [ ] 5.2 实现签名字符串构造：`{HTTP_METHOD}\n{sorted_query}\n{accessKey}\n{gmtDateTime}\n`
- [ ] 5.3 实现 HMAC-SHA256 计算 + Base64 编码
- [ ] 5.4 实现 GMT+8 时间戳生成（RFC 1123 格式）
- [ ] 5.5 实现四个 X-AKZTJG-* Header 注入
- [ ] 5.6 实现 accessKey/secretKey 缺失时的错误处理（LogError + InvalidOperationException）

## 6. Recycle 数据同步服务

- [ ] 6.1 创建 `Services/RecycleWeightMapper.cs`：WeighingRecord → RecycleTransportRecord 映射（kg→吨 ÷1000、时间格式化 yyyy-MM-dd HH:mm:ss、DataNo 生成、配置字段填充）
- [ ] 6.2 创建 `Services/RecycleDataSyncService.cs`：查询 SyncStatus=Pending 记录
- [ ] 6.3 实现附件 Base64 编码逻辑：读取 AttachmentFile → Convert.ToBase64String → 不带标识头 → 逗号分隔
- [ ] 6.4 实现调用 IRecycleDataApi.SubmitTransportRecordAsync 上报数据
- [ ] 6.5 实现同步成功处理：Code==200 → SyncStatus=Synced
- [ ] 6.6 实现同步失败处理：Code!=200 → FailCount++ → FailMsg 记录 → FailCount>=MaxFailCount 放弃
- [ ] 6.7 实现网络异常处理：HttpRequestException → LogWarning 不计 FailCount
- [ ] 6.8 创建 `Backgrounds/RecyclePollingBackgroundService.cs`（AsyncPeriodicBackgroundWorkerBase，轮询间隔绑定 PollIntervalSeconds）

## 7. 授权与启动

- [ ] 7.1 实现 Recycle 授权检查逻辑（复用 SolidWaste 的 SendAuthLicense / DownloadAuth 非 JWT 模式）
- [ ] 7.2 实现未授权启动处理（提示对话框 + 退出）
- [ ] 7.3 实现已授权启动后主窗口显示与称重管线初始化

## 8. BasePlatform 注册（服务端）

- [ ] 8.1 在 BasePlatform 注册 ProductCode 5020
- [ ] 8.2 修改授权管理 UI（ProjectAuthAdd / CompanyAuthAdd）5020 显示 AccessCode + MachineCode（同 5010 模式）
- [ ] 8.3 确认 SendAuthLicense Redis 载荷兼容 5020（沿用现网 JSON）

## 9. 回归验证

- [ ] 9.1 验证 ProductCode 5000（Standard）客户端启动和同步不受影响
- [ ] 9.2 验证 ProductCode 5010（SolidWaste）客户端启动和同步不受影响
- [ ] 9.3 验证 ProductCode 5001（Urban）客户端启动和同步不受影响
- [ ] 9.4 验证 Recycle 客户端启动流程（ProductCode 5020 → WeighingMode 301 → Recycle 模块加载）
