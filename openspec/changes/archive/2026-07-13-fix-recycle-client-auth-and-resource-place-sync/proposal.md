## Why

`MaterialClient.Recycle`（ProductCode=5020, WeighingMode=301）在归档变更中已完成 §2.2 数据上报管线，但授权启动流程实现错误：当前仅调用 `IsLicenseValidAsync()`，失败则 MessageBox 退出，跳过了 SolidWaste（5010）同款的授权码激活（`IBasePlatformApi`）与平台登录（`IMaterialPlatformApi.UserLoginAsync`）流程；称重主界面仍为占位窗口。Recycle 作为独立客户端，需对齐 SolidWaste 授权/登录体验，同时业务数据仅上报杭州市资源化利用厂 §2.2 端点，不走 MaterialPlatform 同步链路。

## What Changes

- 新增 `RecycleStartupService`，复刻 MaterialClient 主程序 `StartupService` 三段式流程：授权码窗口 → 登录窗口 → 称重主界面
- 修改 `MaterialClient.Recycle/App.axaml.cs`，移除「仅本地 License 校验 + MessageBox 退出」逻辑
- 将 Auth/Login/Attended 称重窗口迁移或共享至 `MaterialClient.UI`，供 Recycle 独立项目引用
- Recycle 路径下授权码验证固定 `ProductCode.Recycle`（5020），保留非 JWT 模式（同 5010）
- 明确 `IMaterialPlatformApi` 在 Recycle 中仅用于 `UserLoginAsync`，禁止调用 `SynchronizationOrderAsync` 等业务同步接口
- 替换占位 `RecycleMainWindow` 为 SolidWaste 等价称重 UI；新建记录 `WeighingMode=Recycle` 进入 `RecycleDataSyncService` 扫描
- 回归验证 §2.2 `POST /dataCenter/resourcePlace/productTransportRecord/v1/addBatch`（HMAC、kg→吨、Base64）与 `_temp/resource-place-api-test` 联调脚本一致
- BasePlatform 注册 ProductCode 5020，授权 UI 显示 AccessCode + MachineCode（同 5010）

## Capabilities

### New Capabilities

- `recycle-startup-auth-flow`：Recycle 独立客户端启动链（授权码 → BasePlatform 激活 → MaterialPlatform 登录 → 主界面），ProductCode 固定 5020，行为对齐 SolidWaste
- `recycle-platform-api-boundary`：Recycle 对 `IBasePlatformApi` / `IMaterialPlatformApi` 的调用边界（登录可用，MaterialPlatform 业务同步禁用）

### Modified Capabilities

- `recycle-abp-module`：启动初始化顺序调整——先完成授权/登录再显示主界面；启动失败 UX 改为授权/登录窗口而非 MessageBox 直退
- `recycle-data-sync`：明确扫描 `WeighingMode.Recycle` 记录；与 §2.2 文档及联调脚本对齐（回归验证）
- `detail-viewmodel-hierarchy`：Recycle 独立客户端挂载完整 Attended 称重 UI，而非占位窗口

## Impact

- **MaterialClient.Recycle**（`repos/MaterialClient/`）：`App.axaml.cs`、`RecycleStartupService`、Views/ViewModels、启动 DI
- **MaterialClient.UI**：Auth/Login/Attended 窗口与 ViewModel 共享化迁移
- **MaterialClient.Common**：复用 `LicenseService`、`AuthenticationService`、`AddMaterialClientRefitClients`（无 API 签名变更）
- **BasePlatform**：ProductCode 5020 注册与授权管理 UI
- **外部依赖**：杭州市资源化利用厂 §2.2 接口（`docs/SyncDoc/杭州市资源化利用厂数据接入接口V1.0.md`）
- **无影响**：UrbanManagement、MaterialPlatform 同步链路、5000/5010/5001 客户端行为
