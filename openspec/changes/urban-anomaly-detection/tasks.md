## 1. 配置模型与 appsettings.json

- [ ] 1.1 在 `MaterialClient.Common/Configuration/` 下新建 `UrbanAnomalyDetectionConfig.cs`，定义 `UpperLimit`（decimal, 默认 30.0）、`LowerLimit`（decimal, 默认 2.0）、`DeviationPercentage`（decimal, 默认 10.0）三个属性
- [ ] 1.2 在 `MaterialClient.Urban/appsettings.json` 中新增 `UrbanAnomalyDetection` 配置节，包含 `UpperLimit`、`LowerLimit`、`DeviationPercentage` 三个键值

## 2. 异常检测服务

- [ ] 2.1 在 `MaterialClient.Common/Services/` 下新建 `IUrbanAnomalyDetector.cs` 接口，定义 `bool IsAnomaly(WeighingRecord record, UrbanAnomalyDetectionConfig config)` 方法
- [ ] 2.2 在 `MaterialClient.Common/Services/` 下新建 `UrbanAnomalyDetector.cs` 实现类，实现异常判断逻辑：车牌号为空 → 异常；TotalWeight 超过上限偏差 → 异常；TotalWeight 低于下限偏差 → 异常；否则 → 正常
- [ ] 2.3 在 `MaterialClientUrbanModule.ConfigureServices` 中注册 `IUrbanAnomalyDetector` 为 Singleton

## 3. 实体与 EF Core 配置

- [ ] 3.1 在 `UrbanWeighingExtension.cs` 中新增 `IsAnomaly` 属性（bool，默认 false）
- [ ] 3.2 在 `MaterialClientDbContext.OnModelCreating` 中为 `IsAnomaly` 列添加索引配置
- [ ] 3.3 用户需手动执行 EF Core 迁移命令（`dotnet ef migrations add AddIsAnomalyToUrbanExtension`）生成迁移脚本

## 4. 称重记录创建集成

- [ ] 4.1 在 `WeighingRecordService` 构造函数中注入 `IUrbanAnomalyDetector` 和 `IConfiguration`
- [ ] 4.2 在 `CreateWeighingRecordAsync` 中，Urban 模式创建 `UrbanWeighingExtension` 时，调用 `IUrbanAnomalyDetector.IsAnomaly()` 并将结果写入 `IsAnomaly` 字段
- [ ] 4.3 配置读取使用 `IConfiguration.GetSection("UrbanAnomalyDetection")` 绑定到 `UrbanAnomalyDetectionConfig`，读取失败时使用默认值并记录 Warning 日志

## 5. UI 标签页过滤与状态展示

- [ ] 5.1 修改 `WeighingRecordService.GetPagedUrbanWeighingRecordsAsync` 中的 tab filter 逻辑：`"正常"` 改为过滤 `UrbanExtension.IsAnomaly == false`，`"异常"` 改为过滤 `UrbanExtension.IsAnomaly == true`
- [ ] 5.2 修改 `UrbanAttendedWeighingWindow.axaml` 中状态徽章的绑定逻辑，改为基于 `UrbanExtension.IsAnomaly` 而非 `SyncStatus`
- [ ] 5.3 如需要，新增或修改 Avalonia Value Converter 用于 `IsAnomaly` 布尔值到可见性的转换
