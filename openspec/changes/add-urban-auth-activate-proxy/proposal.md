## Why

MaterialClient.Urban 已通过 Refit 调用 `POST /api/urban/auth/activate` 完成在线激活客户端实现（`update-materialclient-urban-accesscode-jwt`），但 UrbanManagement 在 Urban V2 归档中**刻意延后**了该代理，导致端到端在线激活闭环断裂。BasePlatform `POST /api/auth/activate-urban` 与 JWT `iss=BasePlatform` 均已就绪，现需 Urban 暴露 BFF 代理并同步本地 `GovProject`，以完成 P0 闭环（见 vault `07-客户端服务端EPIC缺口对齐拟稿提案`）。

## What Changes

- 在 `IBasePlatformAuthHttpClient` 新增 `ActivateAsync`，调用 BasePlatform `POST /api/auth/activate-urban`
- 新增 Urban 对外端点 **`POST /api/urban/auth/activate`**，请求体 `{ productCode, code, machineCode }`，成功时透传 BasePlatform `data`（含 `jwtToken`、`proId`、`proName`、`accessCode`、`authEndDate`）
- 新增 `UrbanAuthActivateAppService`（或等价 AppService）：代理 BasePlatform → 按 `proId` 更新本地 `GovProject.MachineCode`（及响应中的授权元数据字段）
- 新增/扩展 DTO（`UrbanManagement.Core.Models`）：请求/响应与 BasePlatform 载荷对齐；C# 方法名统一为 `ActivateAsync`（HTTP 路径不变）
- 单元测试：Refit 客户端映射、AppService 成功/失败路径、`GovProject` 更新
- 更新 `repos/UrbanManagement/docs/BasePlatform-JWT-Endpoints.md` 记录新端点

**Non-Goals（本 change 不做）**：

- BasePlatform / MaterialClient 代码变更
- `GET /api/urban/auth/license-file` REST 别名（P2）
- Hub `UpdateClientLicense` 推送（P1 可选，另立 change）
- `FdBuildLicenseNo` 废弃、`LastMachineCodeUpdate` 字段

## Capabilities

### New Capabilities

- `urban-auth-activate-proxy`：Urban 对外 `activate` BFF 代理、BasePlatform 内部转发、激活后 `GovProject` 同步

### Modified Capabilities

- `urban-jwt-delegation`：`IBasePlatformAuthHttpClient` 除 `GetLicenseFileAsync` 外 SHALL 支持 `ActivateAsync` 调用 BasePlatform 在线激活

## Impact

| 范围 | 影响 |
|------|------|
| **UrbanManagement** | `IBasePlatformAuthHttpClient`、新 AppService、对外 `POST /api/urban/auth/activate`、可选 Controller 路由、`GovProject` 写库、测试、文档 |
| **BasePlatform** | 无代码变更；Urban 消费已有 `activate-urban` |
| **MaterialClient** | 无代码变更；已有 Refit 契约等待对端 |
| **发版** | Urban 部署后用户执行端到端联调（vault 07 §7） |
