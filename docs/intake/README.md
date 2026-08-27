# Intake（需求收件）

OpenSpec / BMAD **之前**的种子池。设计权威：`docs/2026-08-27-intake-parking/`。

| 项 | 值 |
|----|-----|
| Next ID | `INT-005` |
| 机制 topic | `intake-parking` |

## 目录结构

```text
docs/intake/
├── README.md
├── _template.md              ← 正式 INT
├── _draft-template.md        ← 草稿纸（不占序号）
├── themes.md                 ← 项目绑定（业务）
├── parks.md                  ← 项目绑定（业务）
└── YYYY-MM/
    ├── README.md
    ├── drafts/               ← 活跃 scratch
    │   ├── YYYY-MM-DD-<slug>.md
    │   └── archive/          ← 已 promote / discarded
    └── INT-xxx-<slug>.md
```

**机制 trait**：`traits/intake-parking-trait.md`（可迁移）。  
**INT 路径**：`docs/intake/<YYYY-MM>/INT-<NextID>-<slug>.md`  
**Draft 路径**：`docs/intake/<YYYY-MM>/drafts/<YYYY-MM-DD>-<slug>.md`（**不**动 Next ID）  

## 活跃挂起（park）

权威表：[`parks.md`](./parks.md)（项目绑定）。Theme 表：[`themes.md`](./themes.md)。

| park | 说明 | parked_until | 主 theme |
|------|------|--------------|----------|
| `park/xiaoshan-serve` | 见 parks.md | 2026-09 | `xiaoshan-upload` |

> 挂起月：碎聊 → draft；够种子 → INT。不开半成品 Epic / 不为记账而 propose。  
> Cursor：`/intake-draft` · `/intake-register` · `/intake-promote`

## 维护规则

### Draft（草稿纸）

1. 「先记一下 / 还没想清楚 / 帮我理理」→ 复制 `_draft-template.md` → `<YYYY-MM>/drafts/<YYYY-MM-DD>-<slug>.md`。  
2. **不**占用 Next ID；**不**进下方 theme 消化索引。  
3. 够种子后 promote：拆 1–N 条 INT → 源 draft **archive** 或 **delete**（未指定默认 archive）。

### INT（正式收件）

1. 由 `created` 取年月 → 确保 `docs/intake/<YYYY-MM>/`。  
2. 复制 `_template.md` → `<YYYY-MM>/INT-<NextID>-<slug>.md`，Next ID +1。  
3. 必填：`theme`、`intake_month`、`kind`、`summary`、`source`、`created`；挂起填 `parked_until`。  
4. 状态：`open` → `triaged` → `absorbed` → `proposed` → `closed`。  
5. 更新本 README 与月 README。  
6. 可选 GitHub Issue。  
7. **消化按 theme**（跨月合并）。

## 活跃 drafts

| 月 | 目录 |
|----|------|
| 2026-08 | [2026-08/drafts/](./2026-08/drafts/README.md) |

## 索引（按 theme）

### theme: `xiaoshan-upload`

| ID | 月 | 状态 | kind | priority | 一句话 | parked_until | 文件 |
|----|-----|------|------|----------|--------|--------------|------|
| INT-001 | 08 | absorbed | product | P1 | 上报配置双端编辑 | 2026-09 | [2026-08/INT-001-…](./2026-08/INT-001-xiaoshan-upload-config-dual-edit.md) |
| INT-002 | 08 | absorbed | product | P1 | 配置 sync/version/变更日志 | 2026-09 | [2026-08/INT-002-…](./2026-08/INT-002-xiaoshan-upload-config-sync-version.md) |
| INT-003 | 08 | absorbed | product | P1 | 三模式多选与字段映射 | 2026-09 | [2026-08/INT-003-…](./2026-08/INT-003-xiaoshan-upload-modes-field-mapping.md) |
| INT-004 | 08 | absorbed | product | P1 | 旧客户端兼容 | 2026-09 | [2026-08/INT-004-…](./2026-08/INT-004-xiaoshan-upload-legacy-client-compat.md) |

## 索引（按登记月）

| 月 | INT 数 | 目录 |
|----|--------|------|
| 2026-08 | 4 | [2026-08/](./2026-08/README.md) |

## 平铺速查

| ID | month | theme | status | title |
|----|-------|-------|--------|-------|
| INT-001 | 2026-08 | xiaoshan-upload | absorbed | 萧山上报配置模型与双端编辑 |
| INT-002 | 2026-08 | xiaoshan-upload | absorbed | 上报配置同步、version 与变更日志 |
| INT-003 | 2026-08 | xiaoshan-upload | absorbed | 萧山三模式多选与字段映射 |
| INT-004 | 2026-08 | xiaoshan-upload | absorbed | 萧山上报配置旧客户端兼容 |

## 消化 Checklist

- [ ] 选定 `park/*` 或 `theme`（仅扫 INT，不含 drafts）
- [ ] 列出该组全部 `open`/`triaged`
- [ ] 开 BMAD Epic/PRD；追溯表写入 INT id
- [ ] INT → `absorbed` + `absorbed_into`
- [ ] 按 slice `/opsx:propose` → `proposed` + `change`
- [ ] 更新本 README 与月 README；PR `Fixes #n` 关 Issue
