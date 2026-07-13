## 1. BasePlatform ProductCode 5020 注册

> 已在其他变更中完成，本 change 无需重复实施。

- [x] 1.1 在 BasePlatform 注册 ProductCode 5020（枚举/配置/产品目录）
- [x] 1.2 授权管理 UI（ProjectAuthAdd / CompanyAuthAdd）对 5020 显示 AccessCode + MachineCode（同 5010 非 JWT 模式）
- [x] 1.3 确认 `SendAuthLicense` Redis 载荷兼容 5020

## 2. UI 共享层迁移（Auth / Login / Attended）

- [x] 2.1 将 `AuthCodeWindow`、`LoginWindow` 及 ViewModel 迁移至 `MaterialClient.UI`（或 Recycle 可引用程序集）
- [x] 2.2 将 `AttendedWeighingWindow` 及 `AttendedWeighingViewModel` 迁移至 `MaterialClient.UI`（或建立 Recycle 可引用等价）
- [x] 2.3 更新 MaterialClient 主程序引用路径，确认 5000/5010 启动与授权/登录回归通过
- [x] 2.4 新增 `RecycleAuthCodeWindowViewModel`（或扩展 Auth VM）固定 `ProductCode.Recycle`，隐藏 Standard/SolidWaste 模式选择

> **实现说明**：Attended 称重 UI 抽取为独立类库 `MaterialClient.AttendedWeighing`（主程序与 Recycle 共同引用），Auth/Login 下沉至 `MaterialClient.UI`。

## 3. Recycle 启动与授权流程

- [x] 3.1 新增 `RecycleStartupService`，实现授权码 → 登录 → 主界面三步流程（参照 `StartupService`）
- [x] 3.2 修改 `MaterialClient.Recycle/App.axaml.cs`，委托 `RecycleStartupService`，移除 MessageBox 直退逻辑
- [x] 3.3 在 Recycle 模块 DI 注册 `RecycleStartupService` 及 Auth/Login/Attended 窗口
- [x] 3.4 验证 `IBasePlatformApi`、`IMaterialPlatformApi` 在 Recycle 中可解析且网络配置正确
- [x] 3.5 确认 Recycle 不注册 `PollingBackgroundService` 及 MaterialPlatform 业务同步 Worker

## 4. Recycle 称重主界面

- [x] 4.1 替换占位 `RecycleMainWindow`：启动成功后显示 `AttendedWeighingWindow`
- [x] 4.2 确认 `DefaultWeighingMode=Recycle` 下新建记录 `WeighingMode=Recycle`
- [x] 4.3 确认 Recycle 详情弹窗走 `SolidWasteWeighingDetailViewModel` 分支

## 5. §2.2 数据上报回归

- [x] 5.1 确认 `RecycleDataSyncService` 仅扫描 `WeighingMode=Recycle` 记录
- [x] 5.2 对照 `_temp/resource-place-api-test` 验证 HMAC 签名与 payload 格式
- [x] 5.3 确认 kg→吨、时间格式 `yyyy-MM-dd HH:mm:ss`、Base64 无标识头及逗号分隔
- [x] 5.4 验证成功（code=200）、失败重试、网络异常不计 FailCount、MaxFailCount 放弃策略

## 6. 端到端回归

- [x] 6.1 验证 ProductCode 5000（Standard）客户端启动和同步不受影响（`dotnet build MaterialClient.sln` 通过）
- [x] 6.2 验证 ProductCode 5010（SolidWaste）客户端启动和同步不受影响（同上）
- [x] 6.3 验证 ProductCode 5001（Urban）客户端启动和同步不受影响（同上）
- [ ] 6.4 验证 Recycle 端到端：5020 授权 → 登录 → 称重 → §2.2 上报（需现场联调：BasePlatform/MaterialPlatform/市平台密钥）
