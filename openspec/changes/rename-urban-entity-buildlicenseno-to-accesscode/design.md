## Context

`GovProject.AccessCode` 已落地；`UrbanWeighingRecord` / `UrbanPassageRecord` / `GovSyncData` 仍持久化 `BuildLicenseNo` 表示同一接入码。INT-005 / docs `05` 收敛为 **仅 Entity + DB 列** 固化。本 change 为 Mode A（独立小单，基线 trunk），仓库仅 UrbanManagement。

## Goals / Non-Goals

**Goals:**

- 三流水 Entity 属性名为 `AccessCode`；三表列手写 `RenameColumn` 为 `AccessCode`。
- 编译层凡 `entity.BuildLicenseNo` 改为 `entity.AccessCode`；边界映射 `dto.BuildLicenseNo` ↔ `entity.AccessCode`。
- Outbound / JWT / Hub wire 键仍为 `buildLicenseNo`。

**Non-Goals:**

- MaterialClient；DTO/API/Tus/Blazor 属性或 JSON 键改名。
- 删除 `UseAccessCodeMigration`；改 `XiaoshanBuildLicenseNo` 类名；改 `GovProject`（已完成）。

## Decisions

### 1. 属性与列同步 rename（不用 HasColumnName 挂旧列）

- **选择**：C# `AccessCode` + DB 列 `AccessCode`（`RenameColumn`）。
- **替代**：仅改属性、`HasColumnName("BuildLicenseNo")` —— 否决，与 `GovProject` 及 05 定稿不一致。
- **理由**：域内权威名与物理列一致，避免半拉子映射。

### 2. DTO / wire 保持 `BuildLicenseNo`

- **选择**：Receive/Submit/协议 DTO 属性与 JSON 不变；Service/`From*` 显式桥接。
- **替代**：连带 Modern API 改 `accessCode` —— 推迟到后续 INT。
- **理由**：零客户端联调；本 change 可控在单仓 Entity 面。

### 3. 手写 migration

- **选择**：显式 `RenameColumn` 三表；对照 `Migration-Guide-AccessCodeAndJwtDelegation.md`。
- **替代**：依赖 EF scaffold —— 否决（多 string 列时曾误匹配）。

### 4. Git Mode A

- **选择**：分支名 = change 名，自 UrbanManagement trunk 切出，squash 回 trunk。
- **理由**：entity-semantic initiative 已归档；本单独立。

## Risks / Trade-offs

- **[Risk] EF 误 rename** → 手写 `RenameColumn`；PR 核对生成 SQL。
- **[Risk] 漏改 Entity 引用** → 全仓搜 `BuildLicenseNo`，区分 entity vs DTO。
- **[Risk] 外部 SQL 依赖旧列名** → 发布说明列出三表。
- **[Trade-off] DTO 仍叫 BuildLicenseNo** → 域内清晰但边界双名仍在；接受并文档化桥接。

## Migration Plan

1. 部署含 migration 的 UrbanManagement。
2. 应用启动跑 `RenameColumn`；验证三表列名为 `AccessCode`、样本行值未丢。
3. 回滚：反向 `RenameColumn` AccessCode → BuildLicenseNo（同版本回退包）。

## Open Questions

（无阻塞项；Modern JSON 改名另开 change。）
