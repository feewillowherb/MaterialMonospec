# 05 · AccessCode 统一 — 详细变动清单（收敛版）

> **状态**：已 propose → [`openspec/changes/rename-urban-entity-buildlicenseno-to-accesscode`](../../openspec/changes/rename-urban-entity-buildlicenseno-to-accesscode/)（[INT-005](../intake/2026-09/INT-005-urban-entity-accesscode-rename.md)）。  
> **预期 OpenSpec**：`rename-urban-entity-buildlicenseno-to-accesscode`。  
> **仓库**：**仅 UrbanManagement**。  
> **落地规模（参考）**：**M 档（~15万–40万 token）**（见 change `.openspec.yaml`）。

## 1. 收敛范围（定稿）

**只做一件事**：把 UrbanManagement **持久化 Entity** 上仍叫 `BuildLicenseNo` 的接入码，属性名 + DB 列 **固化为 `AccessCode`**，与已完成的 `GovProject.AccessCode` 对齐。

| 做 | 不做 |
|----|------|
| `UrbanWeighingRecord` / `UrbanPassageRecord` / `GovSyncData`：`BuildLicenseNo` → `AccessCode` | MaterialClient 任何改动 |
| 对应表列手写 `RenameColumn` | Modern / Legacy / JWT / Hub / 萧山 **JSON 键** |
| EF `DbContext` 属性配置改名 | DTO / API / Tus meta / Blazor 表单属性改名 |
| 所有 **读写作 `entity.BuildLicenseNo`** 的编译点改为 `entity.AccessCode` | 删除 `UseAccessCodeMigration` |
| Entity 工厂/`From*` 若直接赋本实体字段 | 改 `XiaoshanBuildLicenseNo` 类名 |

边界 DTO 继续叫 `BuildLicenseNo`（含 wire `buildLicenseNo`）。映射形态：

```csharp
entity.AccessCode = dto.BuildLicenseNo;
payload.BuildLicenseNo = record.AccessCode;
```

---

## 2. 现状与目标

| Entity | 现状属性 | 目标 | DB |
|--------|----------|------|-----|
| `GovProject` | `AccessCode` | 已完成 | 已是 `AccessCode` |
| `UrbanWeighingRecord` | `BuildLicenseNo` | → `AccessCode` | `BuildLicenseNo` → `AccessCode` |
| `UrbanPassageRecord` | `BuildLicenseNo` | → `AccessCode` | 同上 |
| `GovSyncData` | `BuildLicenseNo` | → `AccessCode` | 同上（只读历史表也统一） |

语义不变：仍是城管接入码；仅去掉流水实体上的 legacy 名。

---

## 3. 变动明细（UM only）

### 3.1 Entity

| 文件 | 变动 |
|------|------|
| `Entities/UrbanWeighingRecord.cs` | 属性 → `AccessCode`；注释改为「城管接入码」 |
| `Entities/UrbanPassageRecord.cs` | 属性 → `AccessCode`；同文件工厂/`From*` 对本字段的赋值一并改 |
| `Entities/GovSyncData.cs` | 属性 → `AccessCode` |
| `Entities/GovProject.cs` | 无 |

### 3.2 EF + Migration

| 项 | 动作 |
|----|------|
| `UrbanManagementDbContext` | Weighing / Passage 的 `Property(...BuildLicenseNo)` → `AccessCode`；`GovSyncData` 若有显式配置则同步 |
| Migration | **手写** `RenameColumn`（勿依赖 EF 多 string 列启发式） |

| 表 | 旧列 | 新列 |
|----|------|------|
| `UrbanWeighingRecords` | `BuildLicenseNo` | `AccessCode` |
| `UrbanPassageRecords` | `BuildLicenseNo` | `AccessCode` |
| `GovSyncData`（实际表名以 DbContext 为准） | `BuildLicenseNo` | `AccessCode` |

MaxLength(200) 等约束保持不变；流水表无强制新建索引。

### 3.3 编译跟随（非范围扩张）

仅因 Entity 属性改名而必须改的引用，**不**顺手改 DTO 属性名：

| 类别 | 典型动作 |
|------|----------|
| AppService / Manager 落库、查询 | `entity.AccessCode = input.BuildLicenseNo`；`Where(x => x.AccessCode == …)` |
| `GovSyncWeightPayload.From*` / Xiaoshan `FromRecord` | 读 `record.AccessCode`，写出仍 `BuildLicenseNo` / `buildLicenseNo` |
| `GovSyncDataDto.From` 等 | `BuildLicenseNo = entity.AccessCode`（DTO 属性名不变） |
| `UrbanPassageRecord` 工厂入参若来自仍含 `BuildLicenseNo` 的 input DTO | 实体字段写 `AccessCode = input.BuildLicenseNo` |
| 测试里 **构造 Entity** 的对象初始化 | `AccessCode = "..."`；断言协议 JSON 仍用 `buildLicenseNo` |

**禁止**借机改：`UrbanWeighingRecordDtos`、`UrbanPassageDtos`、`UrbanAttachmentUploadDtos`、`ClientProjectLicenseInfoDto`、Hub/JWT 协议 DTO、Legacy wire、MC Submit DTO。

---

## 4. OpenSpec 触点（收窄）

晋升后 delta **以 Entity / 表列叙述为准**，例如：

- `urban-weighing-api` / `urban-passage-cloud`：实体字段名 → `AccessCode`；Receive DTO 可仍写 `BuildLicenseNo`（若本 change 不改 DTO）
- `gov-sync-worker` / `xiaoshan-*`：源字段改为 Entity.`AccessCode`；outbound 键不变
- `entity-migration` / sample 叙述：流水表列名勘误

不要求本 change 改 `materialclient-*`、attachment Tus 键、JWT claim 名相关 spec。

---

## 5. 验收清单

- [ ] 三流水 Entity 属性名为 `AccessCode`；`GovProject` 仍为 `AccessCode`
- [ ] 三表 DB 列已 `RenameColumn` 为 `AccessCode`；数据保留
- [ ] 所有 `entity.BuildLicenseNo` 编译引用已清除
- [ ] DTO / API / MC：**无**为本 change 改名；映射为 DTO.`BuildLicenseNo` ↔ Entity.`AccessCode`
- [ ] Outbound / JWT / Hub wire 仍为 `buildLicenseNo`；萧山 `-02` 行为不变
- [ ] Legacy WIP 不因本改动恢复落库
- [ ] 手写 migration；无新增 tuple；`openspec validate --strict` 通过（若已 propose）

---

## 6. 风险

| 风险 | 缓解 |
|------|------|
| EF 误 rename 列 | 手写 `RenameColumn`；对照 GovProject 既有迁移指南 |
| 漏改 Entity 引用导致编译失败 | 全仓搜 `\.BuildLicenseNo`，区分 entity vs DTO |
| 运维 SQL 仍用旧列名 | 发布说明列三表 rename |
| 与未归档 entity-semantic 变更冲突 | 仍建议 P0–P2 归档后再 propose |

---

## 7. 明确推迟（后续 INT / change，不写进本范围）

- MC Submit / `LicenseInfoDto` 等与 UM Modern DTO 属性统一为 `AccessCode`
- Modern JSON / Tus meta 键改为 `accessCode`
- 删除 `UseAccessCodeMigration` 回退路径
- 协议 DTO C# 属性也改名为 `AccessCode`（仅保留 JsonPropertyName）

---

## 8. 相关链接

- [00-调研总览](./00-调研总览.md)
- [03-业务语义化缺口 §1.1](./03-业务语义化缺口.md)
- [04-改进建议与优先级 D4/D7/D8](./04-改进建议与优先级.md)
- [INT-005](../intake/2026-09/INT-005-urban-entity-accesscode-rename.md)
- `repos/UrbanManagement/docs/Migration-Guide-AccessCodeAndJwtDelegation.md`（列 rename 手法）
