# Addendum — xiaoshanserve-iis-cutover

机制、运维默认与 Architecture/OpenSpec 输入。**不替代** `prd.md` 的能力叙述。

## A. 建议默认（可被 Architecture 推翻）

| ID | Topic | Default | Rationale |
|----|-------|---------|-----------|
| D3 | 双端口 | **IIS 同站双绑定**（OldPort+NewPort → UM） | 零应用改动；Legacy API 已在 UM |
| D3b | 后备 | URL Rewrite / 反代 OldPort→UM | 仅当无法改绑定 |
| D5 | SyncType | 源已成功→`1`；待同步/失败→`0` | 防政府重复推送 |
| D13 | PK | 新 Guid + LegacyId 映射 | 对齐现行 UM Guid 实体 |
| D14 | 图片 | 拷贝入 `FilesPhysicalPath` + 改写相对路径 | 可删 XSS 目录 |
| D15 | ETL | 停写后映射插入；禁止盲目 `SELECT *` |  schema/PK 漂移 |
| D18 | 备份保留 | ≥30 天 | D8 已锁定 |

## B. 稳态拓扑

```text
Before:
  GovClient ──► IIS XSS :OldPort
  MaterialClient ──► IIS UM :NewPort

After:
  GovClient ──► IIS UM :OldPort  ──┐
  MaterialClient ──► IIS UM :NewPort ──┴── UrbanManagement
  XSS stopped (backup retained, not listening)
```

## C. 切流顺序（runbook 骨架）

1. Inventory：站点名、OldPort/NewPort、XSS DB/图片根、UM DB/`Uploads/`  
2. 生产克隆 dry-run：计时、计数、接入码失败列表  
3. 窗口：可恢复备份 → 停 XSS → ETL+图片 → `New-WebBinding` OldPort → 冒烟  
4. 浸泡 → 关停 XSS 包 → 保留备份  
5. 回滚：去 UM OldPort 绑定 → 启 XSS →（必要时）还原 UM 备份  

## D. 与已归档功能迁移的关系

`xiaoshanserve-to-urbanmanagement-abp-migration` 已交付 Legacy API / Worker / 附件等**功能**。本 Epic **不重做**该能力，只做 **端口接管 + 历史数据/图片 + 关停**。

## E. OpenSpec 衔接提示

- 建议 change 名：`add-xiaoshanserve-iis-cutover`（或按 CE 拆分）  
- effort **只**写各 change 的 `.openspec.yaml`  
- **禁止** BMAD 产出 `tasks.md` / Story 任务列表  
- 与 `add-urban-v2-four-machine-code` **分 change**

## F. TR 索引

- `_bmad-output/planning-artifacts/research/technical-xiaoshanserve-urbanmanagement-iis-cutover-research-2026-08-26.md`
