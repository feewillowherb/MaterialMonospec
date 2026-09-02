## Context

称重记录接收 API 与实体在 `proid-association-static-license-fix` 时代引入了 `FdBuildLicenseNo`，意图镜像客户端 `LicenseInfo` 的凡东对接码。现网：

- MaterialClient `UrbanServerUploadService` 只设置 `BuildLicenseNo = licenseInfo?.AccessCode`，从不设置 `FdBuildLicenseNo`。
- `XiaoshanWeighbridgeSaveRecord.FromRecord` 仅使用 `record.BuildLicenseNo`。
- `UrbanWeighingRecordOutputDto` 不暴露该字段；全仓无 `record.FdBuildLicenseNo` 读取。

项目级对接码仍由 `GovProject.FdBuildLicenseNo` 维护（JWT、Legacy API、BasePlatform 拉取）。称重记录无需再存一份。

约束：Mode A；`type-owned-methods` 不适用（纯字段删除）；禁止 tuple。

## Goals / Non-Goals

**Goals:**

- 删除称重记录维度的 `FdBuildLicenseNo`（实体、DTO、DB 列、客户端 Submit DTO）。
- 更新 `urban-weighing-api` 与 `proid-data-pipeline` 规范，与实现对齐。

**Non-Goals:**

- 不删除或重命名 `GovProject.FdBuildLicenseNo`、`LicenseInfo.FdBuildLicenseNo`。
- 不改 JWT claim、Legacy `/Api/Post`、项目搜索/CRUD。
- 不在 Receive 时改为从 `GovProject` 查表填充对接码（如需项目级码，用 `ProId` 关联 `GovProject` 即可）。
- 不顺带重构 `ReceiveAsync` 为 type-owned factory（另 change）。

## Decisions

### 1. Drop column via EF migration（非可空回填）

**选择**：新增 UrbanManagement migration `DropColumn(FdBuildLicenseNo)` on `UrbanWeighingRecords`。

**理由**：列内数据均为 null 或历史无效快照；无下游读取。

**备选**：保留列但废弃 → 拒绝，继续误导。

### 2. API 破坏性删除，不保留兼容 shim

**选择**：从 Receive/Submit DTO 移除属性；客户端不再序列化 `fdBuildLicenseNo`。

**理由**：无生产消费者发送该字段；若第三方仍传，ASP.NET Core 默认忽略未知 JSON 属性。

### 3. `proid-data-pipeline` 收窄为 ProId + ProName + BuildLicenseNo

**选择**：上云管线只要求 `BuildLicenseNo`（接入码 / `AccessCode`）；`LicenseInfo.FdBuildLicenseNo` 仍存在于授权实体，但不进入称重 Submit DTO。

**理由**：与 passage 记录一致（仅 `BuildLicenseNo`）；对接码归属项目配置而非每条称重快照。

## Risks / Trade-offs

- [外部集成若依赖 Receive 存 fdBuildLicenseNo] → 文档 BREAKING；可用 `ProId` + `GovProject` 查对接码。
- [migration 在已有库执行] → SQLite drop column 由 EF 生成；部署前备份；列数据无业务价值。

## Migration Plan

1. 部署 UrbanManagement（migration drop column）与 MaterialClient 同版本或先 UM（多传 null 字段无害，先删客户端更干净）。
2. 回滚：恢复实体属性 + migration 加回可空列（数据无法恢复，可接受）。

## Open Questions

无。
