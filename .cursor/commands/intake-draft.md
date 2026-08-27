---
name: /intake-draft
id: intake-draft
category: Workflow
description: 登记 Intake 草稿纸（不占 INT 序号）— 碎聊 / 未想清时用
---

将碎片需求写入 `docs/intake/<YYYY-MM>/drafts/`，**不**占用全局 `INT-00N`。

设计权威（机制）：`traits/intake-parking-trait.md`（**必读**）  
项目绑定：`docs/intake/themes.md`、`docs/intake/parks.md`  
模板：`docs/intake/_draft-template.md`

**Input**：`/intake-draft` 后的参数可为碎片描述、slug 提示，或留空（从对话上下文提取）。

---

## 何时用本命令

- 「先记一下 / 还没想清楚 / 帮我理理 / 碎片聊」
- theme 未定、半句需求、跨会话续聊

**不要**用本命令占 `INT-00N`。够种子时改用 `/intake-register` 或 `/intake-promote`。

---

## Steps

1. **读取约定**
   - **必读** `traits/intake-parking-trait.md`
   - 必读 `docs/intake/themes.md`、`parks.md`（业务标签）
   - 必读 `_draft-template.md`、`docs/intake/README.md`

2. **确定日期与路径**
   - `created`：默认今天（用户可改）
   - `YYYY-MM`：由 `created` 取年月
   - 确保存在 `docs/intake/<YYYY-MM>/drafts/`（可建 `README.md`）
   - 文件名：`<YYYY-MM-DD>-<slug>.md`（kebab-case slug；**无**全局序号）

3. **收集碎片内容**
   - 若参数/对话已够：直接写入「碎片」条列
   - 若不清：简短追问一句即可，**不要**逼成完整 INT 字段
   - `theme_guess` / `park_guess` 可空；猜测时对照 `themes.md` / `parks.md`

4. **落盘**
   - 复制模板结构写入目标路径，`status: scratch`
   - **禁止**修改 `docs/intake/README.md` 的 Next ID
   - 可选：在月 `drafts/README.md` 活跃表加一行

5. **汇报**
   - 给出文件路径
   - 提示：够种子后用 `/intake-promote`（或 `/intake-register`）

---

## 约束

- 中文输出；路径/theme/slug 保持英文标识
- 不写完整 PRD / OpenSpec / BMAD
- 不 `/opsx:propose`
- 不把业务专名写入可迁移的 trait 文件
