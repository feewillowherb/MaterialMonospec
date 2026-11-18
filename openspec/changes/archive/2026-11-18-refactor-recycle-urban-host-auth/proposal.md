## Why

Recycle 工控仍挂在 Standard/SolidWaste 的 `AttendedWeighing` 与 Material 登录链上，授权又走直连 `GetAuthClientLicense`（不绑机器码）。已确认目标是：与 Urban 同构的只填激活码宿主，项目与授权归 Admin，激活对齐 BasePlatform PublicApi 的在线激活（码 + 机器码 → JWT），且 Urban/Recycle 可并存。现有 PublicApi / 项目拉取只认 5001，5020 走不通。

## What Changes

- **BREAKING**：`MaterialClient.Recycle` 放弃以 `AttendedWeighingWindow` + Material 登录为主宿主；按 `MaterialClient.Urban` 重做独立称重壳（不引用 Urban 工程），启动仅激活码门禁。
- **BREAKING**：Recycle 激活主路径改为平台在线激活（对齐 `ActivateUrban`：激活码 + 本机 `MachineCode` → JWT）；不再以直连 `GetAuthClientLicense` 为产品主路径。
- `FdSoft.BasePlatform.PublicApi`：在线激活与 JWT 签发放行 ProductCode **5020**（流程与 5001 同形）。
- `FdSoft.BasePlatform`：`SendAuthLicense` 对 5020 发码载荷带上 `AccessCode`；**管理端 UI 不改**。
- `UrbanManagement.Admin` / Core：项目拉取与展示同时保留 **5001** 与 **5020**（产品不互斥）；Recycle 行不进城管称重页。
- 不实现 Admin 观察 Recycle 同步情况（以后）。
- Mode B：`dev-recycle-resource-alignment`；本 change 分支 `refactor-recycle-urban-host-auth`，squash 入 `dev-*`。

## Capabilities

### New Capabilities

- `recycle-urban-shaped-host`: Recycle 桌面宿主与主窗对齐 Urban（激活码-only、WeighingWindowBase 壳、无 Material 登录/同步入口）
- `recycle-online-activation-5020`: Recycle（5020）在线激活（码 + 机器码 → 回写 → JWT）与客户端调用契约
- `admin-recycle-project-auth`: Admin 同时管理城管与 Recycle 项目授权（拉取/列表/产品区分）

### Modified Capabilities

- `recycle-startup-auth-flow`: 启动门禁改为仅激活；去掉 MaterialPlatform 登录步骤
- `gov-project-baseplatform-pull-sync`: 拉取规范化同时接受 Urban(5001) 与 Recycle(5020)
- `recycle-platform-api-boundary`: 授权边界改为平台在线激活，不再依赖直连 GetAuthClientLicense 主路径

## Impact

- **子仓库**：`FdSoft.BasePlatform.PublicApi`、`FdSoft.BasePlatform`、`UrbanManagement`、`MaterialClient`（`MaterialClient.Recycle`；尽量不改坏 `MaterialClient.Urban`）、MaterialMonospec docs/openspec。
- **输入**：[`docs/2026-11-16-materialclient-recycle-resource-alignment/`](../../docs/2026-11-16-materialclient-recycle-resource-alignment/00-调研总览.md) 与 [`10-recycle激活与BasePlatform.md`](../../docs/2026-11-16-materialclient-recycle-resource-alignment/10-recycle激活与BasePlatform.md)。
- **相关 change**：`refactor-recycle-client-capture-upload` 的采集上传/接收 API 成果可保留；本单取代其「在 AttendedWeighing 上改壳」的授权/UI 方向。
- **不动**：Admin Recycle 同步观察页；市平台 Worker 第二跳；BasePlatform 项目授权页 UI 改版。
