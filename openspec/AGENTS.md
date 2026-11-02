# openspec — 产品 SHALL 与 Change

`openspec/` 是产品 requirement、active spec、change 与归档的权威子树。项目背景见 [`project.md`](project.md)。现行规格在 `specs/`，进行中的 change 在 `changes/`。

任务勾选不是 Capability 已交付。

## Policy

- 创建、实施或归档 change 前，阅读 [`../traits/icd-trait.md`](../traits/icd-trait.md) 与 [`../traits/ced-trait.md`](../traits/ced-trait.md)。
- 分支、squash 与归档同步遵循 [`../traits/openspec-git-workflow.md`](../traits/openspec-git-workflow.md)。
- Capability 是否交付按 ICD 与对应 Evidence 判断。
- 实现受阻时的外壳以 [`../traits/strategic-fallback-trait.md`](../traits/strategic-fallback-trait.md) 为准。不在本文件再写一套 Pattern。
- 可复用结论可以链到 `docs/`。DOCS 不是 Epic 状态库。
- Pipeline PASS、Agent 建议或 DOCS `CONFIRMED` 不能代替 Human `APPROVED`。这道人闸只用于 Pipeline / DOCS 结论进入产品行为。日常 propose 不先等它。`APPROVED` 不授权 commit 或 push。

## CLI

本仓安装的 OpenSpec CLI 1.3.1 使用：

```powershell
openspec new change <change-name>
openspec status --change <change-name>
openspec instructions apply --change <change-name>
openspec validate <change-name> --strict
openspec archive <change-name>
```

`openspec create` 在该 CLI 中不存在。

## Change workflow

- change id 使用小写 kebab-case，并以动词开头。
- proposal 写 Why、What Changes、Capabilities、Impact。
- delta spec 使用 `ADDED`、`MODIFIED`、`REMOVED` 或 `RENAMED`。
- scenario 标题使用 `#### Scenario:`，并用 WHEN / THEN 描述可观察行为。
- 实现与 spec 不一致时先改权威工件。
- OpenSpec 引用 Evidence 的稳定 Run identity，不复制整份含密钥的 Run 输出。

## Archive

`openspec/changes/archive/` 一经归档即只读。

- 不得为了改措辞、重命名或事后补规格而回填已归档的 proposal、tasks、spec delta 或 metadata。
- 当前规格以 `openspec/specs/` 为准。
- 归档后要纠错时新建 change。
- 归档前运行 `openspec validate <change-name> --strict`。
- tasks 全勾只说明变更文件做完。Capability 交付另需 Acceptance 证据。`commit_when_archive` 只提交 specs，不把勾选变成交付声明。

## Completion checks

- strict validate 通过。
- 被阻断的能力仍标为未交付。
- 来自 DOCS 或 Pipeline 的产品 change 能追溯到 Human `APPROVED` 与稳定 Run identity。
- 归档目录未被回填。
