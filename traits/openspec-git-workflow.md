# openspec-git-workflow

Trait: OpenSpec Propose / Apply / Archive，以及跨仓（含 monospec）建分支、squash 合入、promote。本文件是 **编排仓**契约；**不要**同步到各产品子仓的 C# `traits/` 工作副本。

项目绑定（主干名、merge-check 命令路径、initiative 文档）写在本仓 `AGENTS.md` 摘要或专项 docs，**不要**写进本 trait。

## When this trait applies

动手前 **MUST** 阅读本文件，当任务涉及任一：

- 创建或实施 OpenSpec change（Propose / Apply / Archive）
- 在子仓或 monospec 创建 / 切换 **change 同名分支**
- 将 change 合入目标分支，或将 `dev-*` promote 到主干
- 执行 merge-check 或等价「是否已合入」检查

## 主干名（trunk）

各仓主干以 **`origin/HEAD`** 为准（常见为 `main` 或 `master`）。下文用 **trunk** 统称。

## 模式选择

| 模式 | 何时用 | 分支基点 | Squash 目标 |
|------|--------|----------|-------------|
| **Mode A — Trunk-direct（默认）** | 独立小 change；无多 Phase；无长生命周期共享冲突 | 各仓 trunk | 各仓 trunk |
| **Mode B — Initiative baseline** | 多 Phase / 多 change 共享文件排队；需长周期集成 | 同名 `dev-<initiative>` | 先入 `dev-*`；收尾再 promote 入 trunk |

- 未声明 initiative 时 **MUST** 用 Mode A。
- Mode B **MUST** 在 `proposal.md` / `tasks.md` 写明 `dev-<initiative>` 名称。
- 某轮 initiative 已 promote 后，后续独立小单默认 Mode A，除非新建下一轮 initiative。

## 通用规则（两模式共用）

### OpenSpec

| 规则 | 说明 |
|------|------|
| MUST 有 change | 跨仓或改集成契约时先建 change；例外同编排仓 `AGENTS.md`（单仓小修、纯文档、非破坏依赖升级） |
| 命名 | `add-*` / `update-*` / `refactor-*` / `fix-*` |
| Archive | 目录 `openspec/changes/archive/YYYY-MM-DD-<change-id>`；**默认** sync delta → `openspec/specs/`（`archive.sync_specs: always`），**不要询问**；仅用户明确「不同步」时跳过 |

### 同名分支

| 规则 | 说明 |
|------|------|
| 分支名 = change 名 | 去掉归档日期前缀；例 change `add-foo` → 分支 `add-foo` |
| 何时创建 | Apply 阶段、**首次改该仓代码之前** |
| 哪些仓 | 仅 `proposal.md` / `tasks.md` 列出且有实际代码改动的仓（含 monospec）；无改动不建 |
| 共享依赖仓 | 提案列出的共享库仓若有改动，同样建同名分支 |

### Squash 合入

| 规则 | 说明 |
|------|------|
| MUST squash | 合入目标分支为**单提交**；历史留在 change 分支 / 归档记录 |
| MUST NOT `--no-ff` | 禁止默认 merge commit 合入 |
| MUST NOT 在目标上直接开发 | 功能 commit 只在 change 分支；目标分支不堆开发提交 |
| 提交标题 | `feat\|fix\|chore(<scope>): squash <change-id> into <target-branch>` |
| 提交正文 | 写清 Why / 范围（涉及仓、能力）；可附 Co-authored-by |

### 合入后

1. 跑 merge-check（或等价：确认各仓目标分支已含该 change）
2. 各仓切回 **trunk**（Mode B 日常合入后切回 `dev-*` 亦可；**promote 完成后必须切回 trunk**）
3. 可删除本地 change 分支（squash 后常用 `-D`）

## Mode A — Trunk-direct

```
trunk ──●────────────────●──▶
         \              /
          change ──────┘   squash into trunk
```

1. 各涉及仓：自 trunk 创建并切换 `change-id`
2. 实施 → 自测 →（monospec）勾选 tasks
3. 各仓：squash `change-id` → trunk 并推送
4. Archive（若尚未归档）→ merge-check → 切回 trunk

## Mode B — Initiative baseline

```
trunk ──●─────●─────●──▶
         \     \     \
dev-* ────●──S1──S2──●──▶   S* = change squash；周期性 merge trunk → dev-*
           \    \
         change1 change2
```

| 规则 | 说明 |
|------|------|
| 建立基线 | 涉及仓同名 `dev-<initiative>`，从当时 trunk HEAD 切出并推送 |
| change 基点 | **MUST** 自 `dev-*` 创建（覆盖「仅从 trunk 切」的默认说法） |
| 合入方向 | 验证后 **squash → `dev-*`**；**MUST NOT** 直接 squash 进 trunk（除非用户明确 hotfix / 跳过基线） |
| `dev-*` 纪律 | **MUST NOT** 在 `dev-*` 上手写功能 commit；只接受：change squash、以及 `merge <trunk> → dev-*` |
| 同步 | 主干有他人正式合入后尽快 `merge trunk → dev-*`；**禁止 rebase** 抹掉合并历史 |
| Promote | 里程碑或 initiative 收尾：各仓将 `dev-*` **squash（等价单提交）→ trunk**；标题 `… squash dev-<initiative> into <trunk>` |
| Promote 前 | **SHOULD** 先 `merge trunk → dev-*` 再 squash 上主干 |
| 生命周期 | change 合入 `dev-*` 且 monospec 已 Archive 后可删 change 分支；initiative 结束后可删 `dev-*` |

Mode B 的项目样例文档（若有）放在该仓 `docs/`，不写入本 trait。

## Hotfix / 例外

用户**明确**要求下列情形时可偏离 Mode B「不入主干」：

- 生产 hotfix
- 「跳过基线 / 直接合主干」

仍 **MUST** 使用 change 同名分支 + squash 单提交；并在 commit body 注明例外原因。

## Agent 检查清单

- [ ] 已选 Mode A 或 Mode B（Mode B 已写 `dev-*` 名）
- [ ] Apply 前已在各改动仓切到同名分支
- [ ] 合入目标为 squash 单提交，消息符合模板
- [ ] Archive 已 sync specs（除非用户禁止）
- [ ] merge-check 通过；工作区已回 trunk（或 Mode B 的 `dev-*`，promote 后回 trunk）

## 关联

- 总览：编排仓 `AGENTS.md`（工作流约定；细节以本 trait 为准）
- Archive skill：`.cursor/skills/openspec-archive-change/SKILL.md`
- 合并检查：项目内 merge-check 命令（若已安装）
