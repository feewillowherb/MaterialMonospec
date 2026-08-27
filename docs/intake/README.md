# Intake（需求收件）

OpenSpec / BMAD **之前**的种子池。设计权威：`docs/2026-08-27-intake-parking/`。

| 项 | 值 |
|----|-----|
| Next ID | `INT-004` |
| 机制 topic | `intake-parking` |

## 目录结构

```text
docs/intake/
├── README.md                 ← 本文件（按 theme + 按月索引）
├── _template.md
└── YYYY-MM/                  ← 登记月文件夹（由 created 推导）
    ├── README.md             ← 可选；该月条目列表
    └── INT-xxx-<slug>.md
```

**登记路径**：`docs/intake/<YYYY-MM>/INT-<NextID>-<slug>.md`  
**月文件夹名**：由 `created` 的年月推导，格式 `YYYY-MM`（例 `2026-08`）。`intake_month` 字段与文件夹名一致。

## 活跃挂起（park）

| park | 说明 | parked_until | 主 theme |
|------|------|--------------|----------|
| `park/xiaoshan-serve` | 萧山监管上报（地磅/卡口/成品）挂起 | 2026-09 | `xiaoshan-upload` |

> 挂起月：只登记 INT，不开半成品 Epic / 不为记账而 propose。

## 维护规则

1. 由 `created` 取年月 → 确保存在 `docs/intake/<YYYY-MM>/`（首条时可加该月 `README.md`）。  
2. 复制 `_template.md` → `<YYYY-MM>/INT-<NextID>-<slug>.md`，Next ID +1。  
3. 必填：`theme`、`intake_month`、`kind`、`summary`、`source`、`created`；挂起填 `parked_until`。  
4. 状态：`open` → `triaged` → `absorbed` → `proposed` → `closed`。  
5. 改状态后同步本 README 与对应月 `README.md`。  
6. 可选 GitHub Issue：body 链到完整路径；INT 填 `github`。  
7. **消化仍按 theme**（跨月合并），见 `docs/2026-08-27-intake-parking/05-消化手册.md`。

## 索引（按 theme）

### theme: `xiaoshan-upload`

| ID | 月 | 状态 | kind | priority | 一句话 | parked_until | 文件 |
|----|-----|------|------|----------|--------|--------------|------|
| INT-001 | 08 | open | product | P1 | 地磅称重上报 | 2026-09 | [2026-08/INT-001-…](./2026-08/INT-001-xiaoshan-weighbridge-upload.md) |
| INT-002 | 08 | open | product | P1 | 卡口进出记录上报 | 2026-09 | [2026-08/INT-002-…](./2026-08/INT-002-xiaoshan-gate-inout-record.md) |
| INT-003 | 08 | open | product | P1 | 成品进出（-02） | 2026-09 | [2026-08/INT-003-…](./2026-08/INT-003-xiaoshan-product-inout-record.md) |

## 索引（按登记月）

| 月 | 条目数 | 目录 |
|----|--------|------|
| 2026-08 | 3 | [2026-08/](./2026-08/README.md) |

## 平铺速查

| ID | month | theme | status | title |
|----|-------|-------|--------|-------|
| INT-001 | 2026-08 | xiaoshan-upload | open | 萧山地磅称重结果上报 |
| INT-002 | 2026-08 | xiaoshan-upload | open | 萧山卡口车辆进出记录上报 |
| INT-003 | 2026-08 | xiaoshan-upload | open | 萧山成品进出记录上报 |

## 消化 Checklist

- [ ] 选定 `park/*` 或 `theme`（扫描所有 `YYYY-MM/` 下条目）
- [ ] 列出该组全部 `open`/`triaged`
- [ ] 开 BMAD Epic/PRD；追溯表写入 INT id
- [ ] INT → `absorbed` + `absorbed_into`
- [ ] 按 slice `/opsx:propose` → `proposed` + `change`
- [ ] 更新本 README 与月 README；PR `Fixes #n` 关 Issue
