# 05 · AccessCode 统一 — 详细变动清单

> **状态**：挂起（[INT-005](../intake/2026-09/INT-005-urban-entity-accesscode-rename.md)）；**不在** `dev-urban-entity-semantic` initiative 内执行（D4/D7/D8）。  
> **预期 OpenSpec**：`rename-buildlicenseno-to-accesscode`（名称可调整）。  
> **仓库**：UrbanManagement、MaterialClient（BasePlatform PublicApi 形状默认不动）。  
> **落地规模（参考）**：**L 档（~40万–100万 token）**；建议分仓/分会话。

## 1. 目标与边界

### 1.1 要解决的问题

项目权威源已是 `GovProject.AccessCode` / `LicenseInfo.AccessCode`，但称重、通行、遗留同步、Modern 入站 DTO、附件路径仍使用 `BuildLicenseNo`。值同源，名称分裂，Service / Hub / Upload 靠「AccessCode → BuildLicenseNo」桥接注释维持。

### 1.2 目标命名分层（定稿建议）

| 层 | 名称 | 动作 |
|----|------|------|
| **域内权威** | `AccessCode` | Entity、内部 DTO、C# 属性、DB 列（流水表）统一至此 |
| **MC↔UM Modern API** | 属性 `AccessCode`；JSON 优先 `accessCode` | 两端同改；若需过渡期可用 `[JsonPropertyName("buildLicenseNo")]` 一轮后删 |
| **政府 / JWT / Hub 协议** | wire `buildLicenseNo` | **永久保留**；C# 协议 DTO 可继续叫 `BuildLicenseNo`，值从 `AccessCode` 投影 |
| **Catalog 兼容字段** | `ProjectCatalogItemResponse.BuildLicenseNo` | **不**当作接入码权威；仅 `UseAccessCodeMigration=false` 回退源；可选后续删 flag |

### 1.3 明确不做（Non-goals）

- 不改萧山 / 政府 outbound JSON 键 `buildLicenseNo`（含成品 `-02` 变换逻辑语义不变）。
- 不改 JWT claim 名 `buildLicenseNo`。
- 不改 BasePlatform PublicApi 响应形状（除非另开 BP change）。
- 不把 `FdBuildLicenseNo` 复活或并入 `AccessCode`（Fd 已按 P1 移除）。
- 不在当前 entity-semantic initiative 内动任何 AccessCode 相关 rename（D8）。

### 1.4 与「已完成」部分的关系

| 已完成 | 仍待 INT-005 |
|--------|----------------|
| `GovProject.BuildLicenseNo` → `AccessCode`（列 rename + 索引） | `UrbanWeighingRecord` / `UrbanPassageRecord` / `GovSyncData` 列与属性 |
| `GovProjectDto` / Create / Update / Blazor `AccessCode` | 称重/通行 Receive·Submit·Output DTO |
| `LicenseInfo.AccessCode`（MC） | `LicenseInfoDto.BuildLicenseNo`、`ClientProjectLicenseInfoDto.BuildLicenseNo` 等残留 |
| Pull：`UseAccessCodeMigration` → 映射 `remote.AccessCode` | 流水侧去掉桥接赋值；可选收尾删 flag |

---

## 2. 概念对照（避免改错字段）

| 标识符 | 语义 | INT-005 |
|--------|------|---------|
| `AccessCode` | 城管接入码（权威） | 目标名 |
| 流水 `BuildLicenseNo` | **同一接入码**，legacy 属性/列名 | **改名** |
| Catalog `BuildLicenseNo` | 兼容/MD5 旧字段；非权威接入码 | **不改语义**；可保留反序列化 |
| `FdBuildLicenseNo` | 凡东对接码 | 已移除（非本 INT） |
| `XiaoshanBuildLicenseNo.*` | 对接入码**值**的通道变换 | **保留类名或仅改入参属性访问**；outbound 键不变 |
| Tus meta `buildlicenseno` | 附件上传元数据键 | 见 §5.3：建议 wire 过渡策略 |

---

## 3. UrbanManagement — 变动明细

### 3.1 Entity + EF + Migration

| 对象 | 现状 | 变动 |
|------|------|------|
| `Entities/GovProject.cs` | 已是 `AccessCode` | 无 |
| `Entities/UrbanWeighingRecord.cs` | `string? BuildLicenseNo` | → `string? AccessCode`；注释改为「城管接入码」 |
| `Entities/UrbanPassageRecord.cs` | 同上；工厂/`From*` 赋值 | 属性 + 工厂参数/赋值一并改 |
| `Entities/GovSyncData.cs` | `string? BuildLicenseNo` | → `AccessCode`（只读表也统一，避免双名） |
| `UrbanManagementDbContext` | Weighing/Passage 配 `BuildLicenseNo` MaxLength | 改属性名；**手写** `RenameColumn` |
| Migration | — | 见下表 |

**DB 物理 rename（手写，勿信 EF 启发式多列匹配）：**

| 表 | 旧列 | 新列 | 备注 |
|----|------|------|------|
| `UrbanWeighingRecords` | `BuildLicenseNo` | `AccessCode` | MaxLength 200 保持 |
| `UrbanPassageRecords` | `BuildLicenseNo` | `AccessCode` | 同上 |
| `GovSyncData`（或实际表名） | `BuildLicenseNo` | `AccessCode` | 只读历史表；仍 rename 求一致 |
| `GovProjects` | 已是 `AccessCode` | — | 已完成 |

索引：若流水表无独立索引可不动；`GovProjects.AccessCode` 索引已存在。

### 3.2 内部 / Modern DTO（建议属性 → `AccessCode`）

| 文件 | 现状 | 变动 |
|------|------|------|
| `Models/UrbanWeighingRecordDtos.cs`（Receive 等） | `BuildLicenseNo` | → `AccessCode`；JSON 策略见 §5.1 |
| `Models/UrbanWeighingRecordOutputDto.cs` | 映射 `entity.BuildLicenseNo` | → `AccessCode` |
| `Models/UrbanPassageDtos.cs` | `BuildLicenseNo` | → `AccessCode` |
| `Models/UrbanAttachmentUploadDtos.cs` | `BuildLicenseNo` | → `AccessCode`（multipart / JSON 字段名同步策略见 §5） |
| `Models/GovSyncDataDto.cs` | `BuildLicenseNo` | → `AccessCode` |
| `App/Models/UrbanWeighingRecordDto.cs` | 同上 | → `AccessCode` |
| `Models/GovProject*.cs` | 已是 `AccessCode` | 无 |
| `App/Models/ProjectFormModel.cs` | 已是 `AccessCode` | 无 |

### 3.3 协议 / 边界 DTO（**保留** `BuildLicenseNo` 属性名 + wire）

| 文件 | 动作 |
|------|------|
| `Models/GovSyncWeightPayload.cs` | **保留** `[JsonPropertyName("buildLicenseNo")]`；`FromRecord` 改为读 `record.AccessCode` |
| `Models/XiaoshanGovSaveRecords.cs` | **保留** wire `buildLicenseNo`；`FromRecord` 读 `record.AccessCode` 再交 `XiaoshanBuildLicenseNo` |
| `Xiaoshan/XiaoshanBuildLicenseNo.cs` | 变换逻辑不变；调用方入参改为 AccessCode 值 |
| `Models/JwtAntiTamperResult.cs` | **保留**协议字段名；注释已写明值来自 `GovProject.AccessCode`；确认赋值路径无回归 |
| `Models/UrbanLicenseRequestDto.cs` | 协议参数名可保留；`From(project)` 继续 `project.AccessCode` |
| `Models/LegacyGovSyncDtos.cs` / `App/Models/GovRequestWeightDto.cs` | Legacy WIP：可保留 `buildLicenseNo` / `fdBuildLicenseNo` 解析占位；**不**落库 |
| `Models/ClientProjectLicenseInfoDto.cs` | 对 MC 的授权信息：建议属性 → `AccessCode`，JSON 过渡见 §5.1 |
| `Hubs/DeviceStatusHub.cs` | 已有 `BuildLicenseNo = project.AccessCode`；协议出参保持；内部仅核对注释 |

### 3.4 Service / App 逻辑

| 区域 | 变动要点 |
|------|----------|
| `UrbanWeighingRecordAppService` | Receive/查询映射字段名；路径/校验消息「AccessCode」 |
| `UrbanPassageRecord` 工厂 + AppService | 入参 `AccessCode` |
| `UrbanAttachmentAppService` / `FileService` | 目录分段参数由 `buildLicenseNo` → `accessCode`（磁盘路径字符串值不变） |
| `UrbanAttachmentController` | 校验/日志文案与绑定属性 |
| `TusAttachment*` | meta 键策略见 §5.3；内部变量改名 |
| `GovSyncManager` / Product·Checkpoint Sync | payload 构建读 `record.AccessCode` |
| `GovProjectPullManager` | **已**映射 AccessCode；INT-005 可选：删除 `UseAccessCodeMigration=false` 回退（独立小步或同 change 收尾） |
| `GovProjectManager.ValidateAccessCodeAsync` | 已按 AccessCode 查项目；核对无 `BuildLicenseNo` 残留查询 |
| `JwtAntiTamperService` / `UrbanLicenseGenerator` | claim 仍 `buildLicenseNo`；值来自 AccessCode |
| `LegacyApiController` | WIP 占位；不强制改 wire；禁止写 Entity |

### 3.5 测试（UrbanManagement）

触及约 **13** 个测试文件（含 Pull、Auth flag、GovSync payload、Attachment、Legacy、Xiaoshan converter、Weighing AppService）。全部：

- 构造数据字段改为 `AccessCode`（域内）
- 协议断言仍用 `buildLicenseNo` JSON / 属性（边界）
- 更新 `UrbanAuthFeatureFlagTests`：若删 flag，删除「flag off 用 BuildLicenseNo」用例

---

## 4. MaterialClient — 变动明细

### 4.1 已对齐 vs 残留

| 对象 | 现状 | 变动 |
|------|------|------|
| `Entities/LicenseInfo.cs` | 已是 `AccessCode` | 无（确认无旧列 `BuildLicenseNo`） |
| `IStaticLicenseChecker` / `LicenseCheckResult` | 已是 `AccessCode` | 无 |
| `Api/Dtos/LicenseInfoDto.cs` | 仍有 `BuildLicenseNo` | → `AccessCode`；与服务端 DTO 对齐 |
| `Models/ClientProjectLicenseInfoDto.cs` | `[JsonPropertyName("buildLicenseNo")]` | 属性 → `AccessCode`；JSON 策略与 UM 同步（§5.1） |
| `Models/JwtAntiTamperResult.cs` | 协议字段 `BuildLicenseNo` → 写入 `LicenseInfo.AccessCode` | **保留** wire 属性名；映射注释更新即可 |

### 4.2 Urban 上传 / 附件

| 文件 | 变动 |
|------|------|
| `Urban/Dtos/UrbanWeighingRecordSubmitDto.cs` | 属性 → `AccessCode`；去掉「AccessCode 赋给 BuildLicenseNo」心智 |
| `Urban/Dtos/UrbanPassageSubmitDto.cs` | 同上（现 `BuildLicenseNo = license?.AccessCode`） |
| `Urban/Dtos/UrbanAttachmentUploadDtos.cs` | → `AccessCode` |
| `Urban/Services/UrbanServerUploadService.cs` | Submit 填 `AccessCode` |
| `Urban/Services/UrbanPassageUploadService.cs` | 同上 |
| `Urban/Services/UrbanAttachmentSyncService.cs` | 内部已用 accessCode 语义；DTO/meta 字段对齐；占位常量名可改为 `UnknownAccessCode`（已有） |
| `Urban/Services/UrbanTusAttachmentClient.cs` | Tus metadata 键与 UM 约定一致（§5.3） |
| `Urban/Api/IUrbanManagementApi.cs` | 契约注释/属性名 |

### 4.3 其它

| 文件 | 变动 |
|------|------|
| `LicenseService.cs` | 仍读 `licenseDto.BuildLicenseNo` 写入 AccessCode 的路径 → 统一读 `AccessCode` |
| `MaterialClientUrbanModule.cs` | 启动写 LicenseInfo：已用 `result.AccessCode` 则核即可 |
| `DeviceStatusSignalRClient.cs` | Hub JSON `buildLicenseNo` → `LicenseInfo.AccessCode` 映射保持 |
| UI ViewModels（ProjectInfo / Settings） | 展示绑定若仍暴露 BuildLicenseNo 文案/属性 → AccessCode |
| 测试 | Common.Tests（StaticLicenseChecker）、Urban.Tests（PassageSubmit、Attachment 契约）等约 **3+** 文件 |

---

## 5. Wire / 兼容策略（必须写进 design）

### 5.1 MC ↔ UM Modern JSON（称重 / 通行 / 附件）

**推荐（一次切干净，两端可控）：**

1. C# 属性一律 `AccessCode`
2. 默认序列化 `accessCode`（System.Text.Json camelCase）
3. 发布说明：旧客户端若仍发 `buildLicenseNo`，UM 可短暂双读（自定义 converter 或并行属性 `[JsonPropertyName("buildLicenseNo")]` Obsolete 一轮）后删除

**保守（属性 rename，JSON 键暂不动）：**

- `[JsonPropertyName("buildLicenseNo")] public string? AccessCode`
- 心智改善有限，但零 wire break；可作为 Phase A，Phase B 再改键

### 5.2 政府 outbound / JWT / Hub

| 通道 | JSON / claim | C# |
|------|----------------|-----|
| `GovSyncWeightPayload` | `buildLicenseNo` | 保留属性名或仅改 From 源 |
| Xiaoshan SaveRecord | `buildLicenseNo` | 同上 |
| JWT | claim `buildLicenseNo` | 不变 |
| SignalR Hub 授权结果 | `buildLicenseNo` | `JwtAntiTamperResult.BuildLicenseNo` 保留 |

### 5.3 Tus metadata

现状：`MetaBuildLicenseNo = "buildlicenseno"`。

| 方案 | 说明 |
|------|------|
| A. 键改 `accesscode`，双读旧键 | 与 Modern JSON 一次切干净一致 |
| B. 键名保持 `buildlicenseno` | 仅改 C# 常量/变量名，降低联调风险 |

**建议**：与 §5.1 同选——若 Modern JSON 改 `accessCode`，Tus 走 A；若 JSON 保守，Tus 走 B。

---

## 6. OpenSpec / 文档触点（归档时 sync）

晋升后 delta 预计触及（非穷尽）：

| Spec | 调整方向 |
|------|----------|
| `urban-weighing-api` | 实体/DTO 字段名 → AccessCode |
| `urban-passage-cloud` | 同上；叙述勿再「buildLicenseNo 分支」指域内字段 |
| `proid-data-pipeline` | 项目级对接码叙述：权威名 AccessCode；wire 另述 |
| `attachment-file-storage` | 路径段/元数据 |
| `jwt-*` / `jwt-anti-tamper` | 澄清：claim 仍 `buildLicenseNo`，值 = AccessCode |
| `gov-sync-worker` / `xiaoshan-*` | outbound 键不变；源字段 AccessCode |
| `gov-project-baseplatform-pull-sync` | 已 AccessCode；可写明与流水字段统一 |
| `legacy-api-compat` | wire 可保留 `buildLicenseNo` |
| `materialclient-urban-desktop` / `static-license-test-data` | License DTO 对齐 |
| `urban-management-crud` / `entity-migration` | 历史叙述若仍写 GovProject.BuildLicenseNo → 勘误为 AccessCode |
| `sample-data` / `view-migration` / `blazor-project-management` | 展示列名 |

调研侧：本文件 + [03 §1.1](./03-业务语义化缺口.md) + [04 D4/D7/D8](./04-改进建议与优先级.md)；playbook 参考 `repos/UrbanManagement/docs/Migration-Guide-AccessCodeAndJwtDelegation.md`。

---

## 7. 建议实施切分（仍属同一 INT / 可一个或两个 change）

| 阶段 | 内容 | 档位 |
|------|------|------|
| **A** | UM：三表 Entity + migration + 内部 DTO + Sync FromRecord 源字段；协议 DTO 只改赋值源 | M |
| **B** | MC：Submit/Attachment/LicenseInfoDto/Upload 全路径对齐；与 A 联调 | M |
| **C（可选）** | Modern JSON / Tus 键 `accessCode`；删 `UseAccessCodeMigration` 回退 | S–M |
| **D** | OpenSpec sync + 测试/文档 | 含在上或单独 S |

跨仓依赖：A/B 宜同名分支 Mode A（或独立 initiative）；**禁止**只改一仓导致 Submit 字段对不上。

---

## 8. 验收清单（INT-005 / 预期 change）

- [ ] `UrbanWeighingRecord` / `UrbanPassageRecord` / `GovSyncData` 属性与 DB 列为 `AccessCode`
- [ ] `GovProject` / Pull / CRUD 仍为 `AccessCode`（无回退成 BuildLicenseNo）
- [ ] MC `LicenseInfo` 与 Submit/Attachment 域内属性为 `AccessCode`；无「AccessCode 写入 BuildLicenseNo」业务赋值
- [ ] Outbound `GovSyncWeightPayload` / Xiaoshan / JWT claim / Hub JSON：**仍为** `buildLicenseNo`
- [ ] `XiaoshanBuildLicenseNo` 成品 `-02` / 闸道无后缀行为不变
- [ ] Legacy WIP：可不改 wire；**不**因 rename 恢复落库
- [ ] 无新增 tuple；无 UI→Repository；migration 为手写 `RenameColumn`
- [ ] 相关 OpenSpec delta 已写且 `openspec validate --strict` 通过

---

## 9. 风险与缓解

| 风险 | 缓解 |
|------|------|
| EF 自动 migration 误 rename 到其它 string 列 | 手写 `RenameColumn`；对照 GovProject 迁移指南 |
| MC/UM JSON 键不同步 | A/B 同 PR 窗口或先保守 `[JsonPropertyName]` |
| 运维/报表 SQL 仍写旧列名 | 发布说明列出三表 rename |
| 与 entity-semantic 未归档 change 冲突 | **等** P0–P2 归档 + promote 后再 propose（INT 依赖） |
| Catalog `BuildLicenseNo` 与流水 `AccessCode` 混淆 | design 专节写清三层命名；Code review 检查表 |

---

## 10. 文件触点速查（src，不含 Migrations/obj）

### UrbanManagement（约 40 文件级）

- Entity：`UrbanWeighingRecord`、`UrbanPassageRecord`、`GovSyncData`（`GovProject` 已完成）
- EF：`UrbanManagementDbContext` + 新 migration
- Models：Weighing/Passage/Attachment/GovSyncDataDto；**保留协议名**：GovSyncWeightPayload、Xiaoshan*、JwtAntiTamperResult、UrbanLicenseRequestDto、Legacy*
- Services：Weighing/Passage/Attachment/File/GovSync*/Jwt*/Pull/License*
- App：AttachmentController、Tus*、UrbanWeighingRecordDto、Legacy 占位
- Tests：~13 files
- Docs：`Migration-Guide-AccessCodeAndJwtDelegation.md`（可追加「流水表 rename」一节）

### MaterialClient

- Dtos：Weighing/Passage/Attachment Submit；`LicenseInfoDto`；`ClientProjectLicenseInfoDto`
- Services：UrbanServerUpload、UrbanPassageUpload、UrbanAttachmentSync、UrbanTus*、LicenseService、SignalR
- 协议保留：`JwtAntiTamperResult.BuildLicenseNo`
- UI 绑定若暴露旧名则改
- Tests：StaticLicenseChecker、PassageSubmit、Attachment 契约等

---

## 11. 相关链接

- [00-调研总览](./00-调研总览.md)
- [03-业务语义化缺口 §1.1](./03-业务语义化缺口.md)
- [04-改进建议与优先级 D4/D7/D8](./04-改进建议与优先级.md)
- [INT-005](../intake/2026-09/INT-005-urban-entity-accesscode-rename.md)
- `repos/UrbanManagement/docs/Migration-Guide-AccessCodeAndJwtDelegation.md`
