## Why

UrbanManagement 流水实体仍用 `BuildLicenseNo` 表示城管接入码，而 `GovProject` 已固化为 `AccessCode`，域内同义不同名增加理解与维护成本。按 [INT-005](../../docs/intake/2026-09/INT-005-urban-entity-accesscode-rename.md) / [05 收敛清单](../../docs/2026-09-02-urbanmanagement-entity-semantic-analysis/05-AccessCode统一变动清单.md)，在独立 change 中仅统一 **Entity 属性与 DB 列**，不扩大到 DTO/客户端/协议 wire。

## What Changes

- 将 `UrbanWeighingRecord`、`UrbanPassageRecord`、`GovSyncData` 的属性 `BuildLicenseNo` **重命名**为 `AccessCode`（语义不变：城管接入码）。
- EF 手写 migration：对应表列 `BuildLicenseNo` → `AccessCode`（`RenameColumn`，保留数据与 MaxLength）。
- 所有读写 **entity** 该字段的代码改为 `AccessCode`；边界继续 `dto.BuildLicenseNo` ↔ `entity.AccessCode`、outbound/JWT/Hub 仍用 `buildLicenseNo`。
- `GovProject` 已是 `AccessCode`：**无**再改。
- **不做**：MaterialClient；Modern/Legacy/JWT/Hub/萧山 JSON 键；DTO/API/Tus/Blazor 属性改名；删除 `UseAccessCodeMigration`。

**BREAKING**（仅库列名）：部署后依赖旧列名 `BuildLicenseNo` 的外部 SQL/报表需改用 `AccessCode`。应用 API JSON 键不变。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-weighing-api`: `UrbanWeighingRecord` 接入码属性/列名为 `AccessCode`；Receive DTO 可仍为 `BuildLicenseNo`。
- `urban-passage-cloud`: `UrbanPassageRecord` 接入码属性/列名为 `AccessCode`；入站 DTO 可仍为 `BuildLicenseNo`。
- `gov-sync-worker`: 出站映射源字段改为 Entity.`AccessCode` → wire `buildLicenseNo`。
- `sample-data`: 样例 `GovSyncData`（及叙述）使用 `AccessCode`。

## Impact

- **Repos**: UrbanManagement only（Mode A：自 trunk 切同名分支 `rename-urban-entity-buildlicenseno-to-accesscode`）。
- **Code**: Entities、DbContext、migration、凡引用 `entity.BuildLicenseNo` 的 Service/From*/测试。
- **DB**: `UrbanWeighingRecords`、`UrbanPassageRecords`、`GovSyncData` 表列 rename。
- **API/MC**: 无 wire 变更；MaterialClient 无改动。
- **Source**: INT-005；docs `05-AccessCode统一变动清单.md`。
