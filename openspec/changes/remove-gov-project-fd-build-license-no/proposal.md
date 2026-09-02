## Why

`GovProject.FdBuildLicenseNo`（凡东对接码）与 `BuildLicenseNo` 并存，造成 Legacy 双码校验、Pull 同步、JWT 签发与 Blazor CRUD 多处重复维护；称重记录级 `FdBuildLicenseNo` 已在 [`remove-urban-weighing-record-fd-build-license-no`](../archive/2026-09-02-remove-urban-weighing-record-fd-build-license-no/proposal.md) 移除。Entity 语义化 initiative P1（[D3](../../docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md#21-2026-09-02第一批)）要求从 **项目级** 模型彻底删除该字段，统一以 `BuildLicenseNo` 作为唯一对接码。

## What Changes

- 从 `GovProject` 实体、EF 映射、索引与 migration 中**删除** `FdBuildLicenseNo` 列。
- 从 GovProject CRUD DTO、Blazor 项目表单、Pull 同步落库逻辑中删除该字段；BasePlatform 目录 API 仍可返回 `fdBuildLicenseNo`，UrbanManagement **忽略**不持久化。
- 从 JWT 签发（`UrbanLicenseGenerator`）、反篡改（`JwtAntiTamperService` / Hub）中删除 `fdBuildLicenseNo` claim 与 DTO 属性。
- 从 `GovProjectManager.ValidateAccessCodeAsync` 删除凡东码优先校验，**仅**按 `BuildLicenseNo` 解析项目。
- **Legacy API**：WIP 占位不变；移除对 `GovProject.FdBuildLicenseNo` 的依赖（入站 `fdBuildLicenseNo` 静默忽略，与 D13 一致）。
- **MaterialClient**：`LicenseInfo` / `LicenseCheckResult` / `LicenseInfoDto` 停止持久化 `FdBuildLicenseNo`；旧 JWT 中多余 claim 忽略。
- **BREAKING**：GovProject API DTO 不再暴露 `fdBuildLicenseNo`；新签 JWT 不含 `fdBuildLicenseNo` claim；已发旧 JWT 在 claim 缺失时仍可通过校验（其余 claim 有效即可）。
- Git：**Mode B** — initiative 基线 `dev-urban-entity-semantic`（`UrbanManagement` + `MaterialClient`；change 分支 squash 入 `dev-*`）。

**本 change 不包含**：`BuildLicenseNo` → `AccessCode` 重命名（[INT-005](../../docs/intake/2026-09/INT-005-urban-entity-accesscode-rename.md)）；BasePlatform PublicApi 响应形状；Outbound `GovSyncWeightPayload`。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-management-crud`: GovProject 索引与 DTO/Update 映射删除 `FdBuildLicenseNo`。
- `entity-migration`: `GovProject` 实体形状不再包含 `FdBuildLicenseNo`。
- `gov-project-baseplatform-pull-sync`: Pull 同步不再持久化 `fdBuildLicenseNo`；仍接受 API 字段。
- `legacy-api-compat`: 移除双对接码校验要求（Legacy WIP；仅 `buildLicenseNo` 语义保留于 spec 叙述）。
- `jwt-license-generation`: JWT 签发不再包含 `fdBuildLicenseNo` claim。
- `jwt-offline-license`: 离线校验不再要求提取 `FdBuildLicenseNo`。
- `jwt-anti-tamper`: 反篡改结果与重签 JWT 不再携带 `FdBuildLicenseNo`。
- `blazor-project-management`: 项目创建/编辑表单删除「施工许可证号」字段。
- `materialclient-urban-desktop`: 启动授权流程不再写入 `LicenseInfo.FdBuildLicenseNo`。
- `static-license-test-data`: 测试授权数据模型删除 `FdBuildLicenseNo`。
- `proid-data-pipeline`: 澄清 Purpose/数据流描述，项目级对接码仅 `BuildLicenseNo`。

## Impact

- **UrbanManagement**：`GovProject` 实体、EF migration、DTOs、Pull sync、JWT 服务、Blazor `ProjectManagement`、`GovProjectManager`、Hub、Tests。
- **MaterialClient**：`LicenseInfo` 实体/DTO、JWT 解析、Urban 模块启动写入逻辑、相关 Tests。
- **FdSoft.BasePlatform**：无变更（目录 API 仍返回 `fdBuildLicenseNo`）。
- **历史数据**：migration drop column；不迁移凡东码到 `BuildLicenseNo`（运维需事先核对，见 design.md）。
