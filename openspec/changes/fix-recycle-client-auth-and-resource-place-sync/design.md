## Context

MaterialClient 采用 ABP + Avalonia 模块化架构。SolidWaste（5010）运行在 MaterialClient 主程序内，启动链为 `StartupService`：授权码（`IBasePlatformApi`）→ 登录（`IMaterialPlatformApi.UserLoginAsync`）→ `AttendedWeighingWindow`。Recycle（5020）在归档变更 `2026-07-09-materialclient-to-urbanmanagement-migration` 中已创建独立项目 `MaterialClient.Recycle`，并实现 §2.2 HMAC 上报管线，但 `App.axaml.cs` 仅做 `IsLicenseValidAsync()` 校验，未实现授权/登录 UI；主窗口为占位 `RecycleMainWindow`。

Recycle 约束：
- 独立 exe，与 `MaterialClient.Urban` 并列
- 授权模式同 5010（非 JWT，AccessCode + MachineCode）
- `IMaterialPlatformApi` 仅登录，业务数据走 §2.2 外部接口
- 前端称重能力同 SolidWaste

参考文档：`docs/SyncDoc/杭州市资源化利用厂数据接入接口V1.0.md` §2.2；联调脚本 `_temp/resource-place-api-test`。

## Goals / Non-Goals

**Goals:**

- Recycle 启动链与 SolidWaste 行为一致（授权 → 登录 → 称重主界面）
- Auth/Login/Attended UI 可被 Recycle 独立项目引用
- 明确并 enforced MaterialPlatform 业务同步边界
- §2.2 单端点回归验证通过
- BasePlatform 注册 ProductCode 5020

**Non-Goals:**

- §2.1/§2.3–§2.10 其他资源化利用厂接口
- UrbanManagement / MaterialPlatform 同步链路改动
- JWT 授权（5020）
- 5000/5010/5001 客户端行为变更

## Decisions

### D1: 新增 RecycleStartupService 而非直接复制 StartupService

**选择**：在 `MaterialClient.Recycle` 新增 `RecycleStartupService`，参照 `MaterialClient.Services.StartupService` 实现三步流程，但固定 `ProductCode.Recycle`，且不启动 `MinimalWebHostService`。

**理由**：主程序 `StartupService` 依赖主程序专属窗口类型与 Web Host；Recycle 需独立入口且 ProductCode 固定。

**替代方案**：将 `StartupService` 泛化至 Common/UI 层。未采用：改动面过大，影响 5000/5010 回归。

### D2: Auth/Login 窗口迁移至 MaterialClient.UI

**选择**：将 `AuthCodeWindow`、`LoginWindow` 及对应 ViewModel 从 `MaterialClient` 主项目迁移至 `MaterialClient.UI`（或新建 Recycle 专用 ViewModel 子类固定 ProductCode）。

**理由**：归档 task 7.3 阻塞根因是窗口位于主程序项目；Urban 模式已通过 UI 共享层复用组件。

**替代方案**：Recycle 引用 MaterialClient 主项目。未采用：循环依赖与部署耦合。

### D3: Recycle 授权 ViewModel 固定 ProductCode.Recycle

**选择**：Recycle 使用 `RecycleAuthCodeWindowViewModel`（或扩展 `AuthCodeWindowViewModel`）在验证时传入 `ProductCode.Recycle`，隐藏 Standard/SolidWaste ComboBox。

**理由**：5020 独立客户端无需模式选择；避免误用 5010 授权码。

### D4: MaterialPlatform 边界通过模块注册约束

**选择**：`MaterialClientRecycleModule` 仅注册 `AddMaterialClientRefitClients`（含 `IMaterialPlatformApi`），**不**注册 `PollingBackgroundService`、`WeighingMatchingService` 的 MaterialPlatform 同步路径；后台 Worker 仅 `RecyclePollingBackgroundService`。

**理由**：登录需要 `IMaterialPlatformApi`；业务同步由 Recycle 专属服务承担，架构边界清晰。

### D5: 称重主界面复用 AttendedWeighingWindow

**选择**：Recycle 启动成功后显示 `AttendedWeighingWindow`（迁移至 UI 层），`DefaultWeighingMode=Recycle`，详情 VM 已有 `SolidWasteWeighingDetailViewModel` 分支。

**理由**：`AttendedWeighingViewModel` 已实现 Recycle 分支；占位窗口无业务价值。

### D6: §2.2 上报范围不变，仅回归验证

**选择**：不重构已有 `RecycleDataSyncService` / HMAC Handler，对照 `_temp/resource-place-api-test` 做 payload 与签名回归。

**理由**：归档变更已交付核心管线；本变更重点是授权与 UI。

### D7: BasePlatform 5020 同 5010 非 JWT 模板

**选择**：BasePlatform 复制 5010 授权 UI 与 Redis 载荷逻辑至 5020。

**理由**：提案明确 Recycle 授权与 SolidWaste 一致；无 JWT 需求。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| UI 迁移至 MaterialClient.UI 影响主程序编译 | 分步迁移：先复制再删主程序引用；5000/5010 回归 |
| BasePlatform 5020 未注册阻断授权激活 | tasks 优先实施 BasePlatform；开发环境可用 test license 路径 |
| HMAC 密钥/pointNumber 缺失 | `RecycleSyncOptions` 配置化；联调前 mock |
| Auth 窗口迁移引入 Urban/Standard 行为回归 | 主程序继续使用原 ViewModel 或共享层保持 API 兼容 |
| SolidWaste UI 与 Recycle 同步状态字段差异 | Recycle 记录 `WeighingMode=Recycle`，由 `RecycleDataSyncService` 独立扫描 |

## Migration Plan

1. BasePlatform 注册 5020（可并行 unblock 授权联调）
2. UI 共享层迁移 Auth/Login/Attended 组件
3. 实现 `RecycleStartupService` 并替换 `App.axaml.cs` 启动逻辑
4. 移除占位 `RecycleMainWindow` 或改为壳层
5. §2.2 联调回归 + 5000/5010/5001/5020 端到端验证

**回滚**：Recycle 为独立项目，回退 Recycle 启动/UI 变更不影响其他 ProductCode。

## Open Questions

| # | 问题 | 负责方 |
|---|------|--------|
| 1 | HMAC accessKey / secretKey | 市平台 |
| 2 | pointNumber / productName | 运营 |
| 3 | Base64 图片大小上限 | 联调 |
| 4 | Auth/Login 窗口是否需 Recycle 品牌化文案 | 产品 |
