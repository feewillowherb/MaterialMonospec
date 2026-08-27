---
name: /intake-register
id: intake-register
category: Workflow
description: 登记正式 Intake INT（全局序号）— 已够 1–3 句种子时用
---

将已够格的需求种子写入 `docs/intake/<YYYY-MM>/INT-<NextID>-<slug>.md`，占用全局序号。

设计权威：`docs/2026-08-27-intake-parking/`  
模板：`docs/intake/_template.md`  
Theme 表：`docs/2026-08-27-intake-parking/04-theme-注册表.md`

**Input**：`/intake-register` 后可为标题/摘要/slug，或留空（从对话提取）。若内容仍是半句碎聊，应改走 `/intake-draft`。

---

## 何时用本命令

- 已有 theme + 1–3 句「现状 + 期望」
- 用户明确「收件 / 落成 INT / 记进 intake」
- apply/调研中超出当前 change 范围、可独立成条的改进

**不要**用半截聊天硬占 INT → 先 `/intake-draft`。

---

## Steps

1. **读取约定与 Next ID**
   - 必读：`docs/AGENTS.md` Intake、`docs/intake/README.md`（**Next ID**）、`_template.md`
   - 可选：`04-theme-注册表.md`（优先选用已批准 theme）

2. **校验是否够种子**
   - 至少能填：`title`、`theme`、`summary`（1–3 句）、`source`、`created`
   - 不够 → 说明并建议 `/intake-draft`，**停止**占号

3. **分配路径**
   - 取 README 中 Next ID（如 `INT-004`）
   - `created` 默认今天 → `intake_month` = `YYYY-MM`
   - 路径：`docs/intake/<YYYY-MM>/INT-<id>-<slug>.md`
   - 确保月目录存在（可建月 `README.md`）

4. **落盘 INT**
   - 按 `_template.md` 填写；`status: open`
   - 挂起项目填 `parked_until`（`YYYY-MM`）
   - `kind`：`product` | `tech-debt` | `security` | `ops` | `docs`
   - 证据只放链接，不粘贴大段接口/PRD

5. **更新索引**
   - `docs/intake/README.md`：Next ID +1；按 theme / 按月 / 平铺表追加
   - 月 `README.md` 追加一行
   - **不**改 draft 目录（本命令不处理 promote；从 draft 来请用 `/intake-promote`）

6. **可选 GitHub Issue**
   - 仅当用户要求时：标题 `[INT-00N] …`，body `Intake: docs/intake/...`；INT 填 `github`
   - Label 约定见 `06-GitHub-衔接.md`

7. **汇报**
   - 路径、id、theme、Next ID 新值
   - 消化仍按 theme，见 `05-消化手册.md`；挂起月勿自行 `/opsx:propose`

---

## 约束

- INT 序号**全局**递增，不按月重置
- 不写完整 PRD；不自行升 `absorbed` / `proposed`
- 中文输出；标识符保持英文
