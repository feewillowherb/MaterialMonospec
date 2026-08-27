# 03 · README 索引草案

> 落地时作为 `docs/intake/README.md` 的起点。  
> 机制 topic：`intake-parking`。  
> 设计权威：`docs/2026-08-27-intake-parking/`。

---

## Intake（需求收件）

OpenSpec / BMAD **之前**的种子池：挂起碎片与衍生改进先登记于此。

| 项 | 值 |
|----|-----|
| Next ID | `INT-001` |
| 机制 topic | `intake-parking` |

### 活跃挂起（park）

| park | 说明 | parked_until | 主 theme（可多个） |
|------|------|--------------|-------------------|
| （例）`park/xiaoshan-serve` | 萧山相关上报/对接挂起 | 2026-09 | `xiaoshan-upload` |

> 挂起月：只登记 INT，不开半成品 Epic / 不为记账而 propose。

### 维护规则（摘要）

1. 复制 `_template.md` → `INT-<NextID>-<slug>.md`，Next ID +1。  
2. 必填：`theme`、`kind`、`summary`、`source`、`created`；挂起填 `parked_until`。  
3. 状态：`open` → `triaged` → `absorbed` → `proposed` → `closed`。  
4. 改状态后同步本索引。  
5. 可选 GitHub Issue：`[INT-00N]` 标题 + body 链回本文件；INT 填 `github`。  
6. 消化：按 **theme** → BMAD Epic → OpenSpec。

### 索引（按 theme 分组）

#### theme: `xiaoshan-upload`

| ID | 状态 | kind | priority | 一句话 | parked_until | github | 文件 |
|----|------|------|----------|--------|--------------|--------|------|
| — | — | — | — | （尚无条目） | — | — | — |

### 平铺速查（可选）

| ID | theme | status | title |
|----|-------|--------|-------|
| — | — | — | — |

### 消化 Checklist

- [ ] 选定 `park/*` 或 `theme`  
- [ ] 列出该组全部 `open`/`triaged`（可对 `gh issue list --label theme:xxx`）  
- [ ] 开 BMAD Epic/PRD；追溯表写入 INT id  
- [ ] INT → `absorbed` + `absorbed_into`  
- [ ] 按 slice `/opsx:propose` → `proposed` + `change`  
- [ ] 更新本 README；PR `Fixes #n` 关 Issue  
