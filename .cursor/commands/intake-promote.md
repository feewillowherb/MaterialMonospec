---
name: /intake-promote
id: intake-promote
category: Workflow
description: 将 draft 晋升为 1–N 条 INT，源 draft 可 archive 或 delete
---

从 `docs/intake/<YYYY-MM>/drafts/` 活跃草稿纸拆出正式 INT，并处理源 draft。

设计权威：`docs/2026-08-27-intake-parking/08-draft.md`

**Input**：`/intake-promote` 后可为 draft 路径/文件名，以及 `archive` 或 `delete`；留空则扫描活跃 drafts 并询问。

---

## Steps

1. **定位 draft**
   - 若给了路径：读取该文件（须在某月 `drafts/` 根下，**不是** `archive/`）
   - 若未给：列出当前月（或用户指定月）`drafts/*.md`（排除 `archive/`、`README.md`），请用户选一条或多条
   - 若无活跃 draft：说明并建议 `/intake-draft` 或 `/intake-register`

2. **确认 disposition（源 draft 处置）**
   - `archive`：填晋升记录后移入同月 `drafts/archive/`
   - `delete`：INT 写好后删除源文件
   - **未指定时默认 `archive`**；可用 AskQuestion 确认

3. **拆种子（可 1→N）**
   - 从碎片整理出 1 条或多条 INT 候选（每条：title / theme / summary）
   - theme 优先查 `04-theme-注册表.md`
   - 请用户确认拆分结果后再占号

4. **登记 INT（对每条）**
   - 按 `/intake-register` 相同规则：读 Next ID → 写 `INT-xxx` → 更新根/月 README → Next ID +1
   - 孵化记录可注：`由 draft <原路径> promote`

5. **处理源 draft**
   - 填 `status: promoted`、`promoted_to`、`promoted_on`、`disposition`
   - **archive**：`archived_to` 指向目标 → **移动**到 `drafts/archive/`（文件名通常不变）→ 更新 `drafts/README.md` 与 `archive/README.md`
   - **delete**：确认所有 INT 已落盘后 **删除** 源文件 → 从 `drafts/README.md` 活跃表移除
   - **禁止**把 `promoted` 文件继续留在 `drafts/` 根下

6. **汇报**
   - 新建 INT 路径列表
   - 源 draft：已 archive 的路径，或已 delete
   - 当前 Next ID

---

## 约束

- promote **不**等于消化：勿自行开 BMAD Epic / `/opsx:propose`
- 一对多时一次性占连续 INT 号，避免中途失败导致空洞（失败则回滚未完成的 INT 与 Next ID，或向用户说明）
- 中文输出；标识符保持英文
