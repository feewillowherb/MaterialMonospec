---
title: XiaoShanServe IIS 双端口切流并入 UrbanManagement
created: 2026-08-26
updated: 2026-08-26
status: final
epic_id: xiaoshanserve-iis-cutover
---

# PRD：XiaoShanServe IIS 双端口切流并入 UrbanManagement

**Epic ID**: `xiaoshanserve-iis-cutover`  
**版本**: 1.0（final）  
**状态**: Final — Fast path 已审阅（pass）；可转 Architecture / OpenSpec  
**创建日期**: 2026-08-26  
**定稿日期**: 2026-08-26  
**影响范围**: UrbanManagement（部署/数据）+ 现场 IIS 运维；**不改** GovClient / MaterialClient 代码  
**上游调研**: `_bmad-output/planning-artifacts/research/technical-xiaoshanserve-urbanmanagement-iis-cutover-research-2026-08-26.md`  
**与其它 Epic**: **独立于** `urban-v2-four-machine-code`（四机器码绑定）

> 本 PRD 供 PM / 架构 / OpenSpec 衔接使用。机制、IIS 绑定细节、ETL 映射见同目录 `addendum.md`；审计见 `.decision-log.md`。  
> **BMAD Phase 4（sprint / story / dev-story）本仓库禁用**；实施任务仅由 OpenSpec `tasks.md` 产出。  
> 本文件不写人天/工期；effort 仅在后续 OpenSpec `.openspec.yaml`。

---

## 0. Document Purpose

定义 **XiaoShanServe（XSS）关停切流** 的产品能力与验收边界：在 **不修改存量 GovClient** 的前提下，由 UrbanManagement（UM）在同一 Windows IIS 主机上同时承接 **旧 XSS 端口** 与 **现 UM 端口** 流量；将 XSS 历史 **称重记录、同步记录（GovSyncData）、图片** 并入 UM；确认后下线 XSS。下游走 Architecture（可选）→ 主仓库 OpenSpec change；本文件不写实现步骤或 tasks。

## 1. Vision

XSS 与 UM 已同机部署、端口不同。UM 已具备 Legacy `POST /Api/Post`、附件存储与政府同步 Worker，功能上可替代 XSS；但现场仍有 GovClient 指向 **XSS 旧端口**。若直接关 XSS 而不接管该端口，现场客户端将断传。

本期目标是 **兼容性切流收口**：停写窗口内完成历史数据与图片迁入，IIS 将旧端口绑定到 UM 站点，冒烟通过后关停 XSS，实现「一个后端、两个端口入口、GovClient 配置不变」。

## 2. Target User

### 2.1 Primary Persona

- **现场运维 / 实施**：在同一 Windows Server 上执行备份、停写、迁移、IIS 绑端口、冒烟与回滚。
- **城管业务运营（UM 管理端）**：切流后仍在 UM 查看历史称重/同步数据与图片；接入码与项目以 UM 为准。
- **存量 GovClient 使用方**：客户端不升级、不改端口；继续向原 XSS 端口提交称重。

### 2.2 Jobs To Be Done

- 关停 XSS 后，GovClient 旧端口提交仍成功并落库。
- MaterialClient / 新端口路径不受破坏。
- 历史称重、同步记录、图片在 UM 可查、可开。
- 已成功上报政府的历史记录 **不被 Worker 重复推送**。
- 切流失败时可按 runbook 回滚到 XSS 接旧端口。

### 2.3 Non-Users (v1)

- 不面向「改 GovClient 改端口/URL」的迁移方案。
- 不面向 XSS 管理后台 UI / 无关表迁移。
- 不把 XSS `GovProject` 迁入覆盖 UM 项目真源。
- 不新建长期反向代理产品线（除非运维无法同站绑端口，见 Open Items）。

### 2.4 Key User Journeys

- **UJ-1. 停写窗口完成切流**  
  运维备份 → 停 XSS → ETL → UM 绑旧端口 → 冒烟 → 观察。**Climax**: 旧端口 `POST /Api/Post` 返回成功且落库。

- **UJ-2. GovClient 无感续传**  
  切流后现场机仍用原地址端口提交。**Climax**: 业务侧看到新记录进入 UM。

- **UJ-3. 历史可查**  
  运营在 UM 打开迁入的称重/同步记录并查看图片。**Climax**: 样例图片可打开。

- **UJ-4. 回滚** *[ASSUMPTION: 回滚触发由现场负责人口头/变更单裁定]*  
  冒烟失败 → 去掉 UM 旧端口绑定 → 恢复 XSS 监听旧端口（必要时还原 UM 备份）。

## 3. Glossary

| 术语 | 定义 |
|------|------|
| **XSS / XiaoShanServe** | 旧城管中继服务（即将关停） |
| **UM / UrbanManagement** | 新城管后端；切流后唯一在线服务端 |
| **OldPort** | 原 XSS IIS 绑定端口；GovClient 仍指向此端口 |
| **NewPort** | 现 UM IIS 绑定端口；MaterialClient / 新客户端使用 |
| **双绑定 Option A** | 同一 IIS 站点为 UM 同时绑定 OldPort + NewPort |
| **停写窗口** | 停止 XSS 写入并进行 ETL / 绑端口的维护窗口 |
| **Legacy API** | UM `POST /Api/Post`，兼容未改动的 GovClient |
| **ACL** | Legacy 请求到 UM 领域模型的防腐翻译（已存在于 UM） |
| **SoT** | Source of Truth；项目接入码以 UM `GovProject` 为准 |

## 4. Features & Requirements

### 4.1 F1 — IIS 双端口承接

- **FR-1** 系统（部署）MUST 使 UM 在 **OldPort** 与 **NewPort** 均可接收 HTTP(S) 请求，且路由到同一 UM 应用。*[ASSUMPTION: 默认 Option A 同站双绑定；端口数值由现场 inventory 填入]*
- **FR-2** 切流完成后，GovClient 指向 OldPort 的请求 MUST 由 UM 处理，MUST NOT 仍由 XSS 进程监听 OldPort。
- **FR-3** NewPort 上既有 UM 能力（含 MaterialClient 相关 API）MUST 保持可用。
- **FR-4** 若运维无法同站绑定 OldPort，MAY 采用反向代理将 OldPort 转发至 UM（Option B）；PRD 默认仍为 A。

### 4.2 F2 — Legacy 契约不变

- **FR-5** OldPort 上 `POST /Api/Post` MUST 保持与现网 GovClient 兼容的请求/响应契约（含接入码校验与 `success/msg/code/data` 形态）。
- **FR-6** Legacy 路径 MUST NOT 被 Urban JWT / 授权中间件误拦导致 GovClient 无法提交。
- **FR-7** 接入码解析 MUST 仅依赖 **UM** `GovProject`（凡东码优先等既有规则）；MUST NOT 依赖 XSS 项目表。

### 4.3 F3 — 历史数据迁移（范围收窄）

- **FR-8** 切流 MUST 将 XSS 中的 **称重记录** 迁入 UM 对应称重存储（`UrbanWeighingRecord` 语义）。
- **FR-9** 切流 MUST 将 XSS 中的 **同步记录** 迁入 UM `GovSyncData`（或现行等价实体）。
- **FR-10** 切流 MUST 迁移关联 **图片文件**，并保证 UM 能按存储约定解析路径打开。
- **FR-11** 切流 MUST NOT 迁移 **GovLog**（UM 无承接点）。
- **FR-12** 切流 MUST NOT 将 XSS **GovProject** 作为权威导入覆盖 UM（UM 为唯一真源）。
- **FR-13** 迁移 MUST 使用新主键策略，避免与 UM 现网 Guid 冲突；须可追溯到源侧标识 *[ASSUMPTION: LegacyId 映射表或导出文件即可，不必长期产品化 UI]*。
- **FR-14** ETL 前 MUST 校验：待迁记录所用接入码均可在 UM `GovProject` 解析；无法解析的记录 MUST 被报告并阻止「静默丢项目写入」 *[ASSUMPTION: 默认失败则整批或该批中止，不静默跳过成功冒充完成]*。

### 4.4 F4 — 同步状态与政府重推

- **FR-15** 源侧已判定为 **已成功同步政府** 的历史记录，迁入后 MUST 标记为已同步（如 `SyncType = 1`），MUST NOT 被 gov Worker 默认再次推送。
- **FR-16** 源侧仍为 **待同步 / 失败** 的记录，迁入后 MUST 保持可被 Worker 继续处理的状态（如 `SyncType = 0` 及合理重试字段）。

### 4.5 F5 — 切流运行与验收

- **FR-17** 切流 MUST 在 **停写窗口** 内执行（允许短暂停写 XSS）。
- **FR-18** 切流前 MUST 完成可恢复备份（至少 XSS DB+图片、UM DB+Uploads）。
- **FR-19** 切流后 MUST 通过冒烟：OldPort `POST /Api/Post` 成功；样例迁入图片可开；迁入计数与范围内源数据一致（允许显式跳过清单）。
- **FR-20** MUST 提供可执行回滚路径：解除 UM 对 OldPort 的占用并恢复 XSS 监听；若 UM 库已被污染则恢复切流前 UM 备份。

### 4.6 F6 — 关停 XSS

- **FR-21** 冒烟与约定浸泡通过后，MUST 停止 XSS 站点/进程，且 OldPort MUST NOT 再由 XSS 监听。
- **FR-22** XSS 安装包/数据备份 SHOULD 保留不少于约定天数以备审计/回滚（默认 **≥30 天**，D8）。

## 5. Non-Functional

- **NFR-1 兼容**: GovClient 零改动；Legacy 契约回归。
- **NFR-2 一致性**: 停写后单写者（仅 UM）写入合并后数据集；禁止 XSS+UM 双写同一逻辑库。
- **NFR-3 可回滚**: 窗口内命名决策人；触发条件与步骤书面化（机制见 addendum）。
- **NFR-4 安全**: OldPort 协议（HTTP/HTTPS）与客户端一致；UM 应用池对 Uploads/DB 有最小必要权限。
- **NFR-5 可观测**: 冒烟与关键失败可从 UM 日志定位；迁入报告含计数与接入码失败列表。
- **NFR-6 范围纪律**: 不借机做 V2 四槽、不扩迁无关表、不改 GovClient。
- **NFR-7 编码约定**: 若新增 UM 代码，跨仓 C# 多值用命名 `record`，禁止 tuple（AGENTS）。

## 6. Success Metrics

| 指标 | 目标 |
|------|------|
| OldPort Legacy POST | 冒烟 `code: 200` 且落库 |
| NewPort UM 能力 | 切流后抽检通过 |
| 迁入称重 / GovSyncData | 范围内 100%（减显式跳过） |
| 样例图片可开 | 100% 抽检 |
| 已同步历史被 Worker 重推 | 0 起非预期 |
| XSS 监听 OldPort | 切流成功后为 0 |

**Counter-metric**: 不得以「修改全部 GovClient 端口配置」或「长期双开 XSS+UM 写库」达成上述指标。

## 7. Out of Scope（本期）

- 修改 GovClient / MaterialClient 源码或强制改客户端端口
- 迁移 GovLog、XSS GovProject、XSS 后台 UI、无关配置表
- 系统侧自动废止/合并与四机器码 Epic 的交叉功能
- 长期双活写（XSS 与 UM 同时接写入）
- BMAD Phase 4 sprint / story 实施清单
- 云原生改造、换库（PostgreSQL 等）

## 8. Open Items / Locked Defaults

| ID | 项 | 结论 | 状态 |
|----|----|------|------|
| D1 | GovLog | **不迁** | **已锁定** |
| D2 | GovProject | **不迁 XSS 项目；UM 为 SoT** | **已锁定** |
| D3 | 双端口 | **默认 Option A 同站双绑定**；B 仅后备 | **已锁定默认** |
| D4 | 停写 | **允许** | **已锁定** |
| D5 | SyncType | 已同步→1；待同步/失败→0 | **已锁定默认** |
| D6 | OldPort/NewPort 数值 | 现场 inventory | **Open** |
| D7 | XSS 表列精确映射 | Schema probe 后定 | **Open** |
| D8 | 备份保留天数 | **≥30 天**（pass 确认假设） | **已锁定** |

完整机制见 `addendum.md`；TR 全文见上游调研路径。

## 9. Delivery Shape（规划侧，非 tasks）

建议下游 OpenSpec 切片（Architecture / CE 可再拆）：

1. **迁移工具与报告**：schema probe、ETL、图片拷贝与路径改写、接入码预检、SyncType 策略  
2. **IIS 切流与冒烟**：双绑定脚本、停写/回滚 runbook、Legacy/图片验收  
3. **关停与观察**：XSS 下线、浸泡检查清单  

实现顺序硬约束：**预检与 dry-run → 停写 ETL → 绑端口冒烟 → 关停 XSS**。

## 10. References

- `_bmad-output/planning-artifacts/research/technical-xiaoshanserve-urbanmanagement-iis-cutover-research-2026-08-26.md`
- `openspec/changes/archive/2026-05-29-xiaoshanserve-to-urbanmanagement-abp-migration/`
- `openspec/specs/legacy-api-compat/spec.md`
- `docs/operation-manual.md`（BMAD Phase 1–3 → OpenSpec；禁用 Phase 4）
