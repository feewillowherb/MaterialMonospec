## Why

本仓已有 OpenSpec、docs、pipelines 与编码类 traits，但缺少 BlenderTools-MonoSpecs 那一层可判别的完成语义：任务勾选会被当成交付，调研笔记会变成第二套规格，Pipeline 结果也没有稳定身份。需要把 Monospec 编排设计对齐到那套权威分层，同时保持本仓产品语言、框架、Node.js cook 与子仓架构不变。

## What Changes

- 增加裁剪后的 FEV、ICD、CED、DOCS、pipelines traits，以及 `openspec/AGENTS.md`、`openspec/project.md`。
- 根 `AGENTS.md` 增加「Where things are」与调查/验收入口；归档句改为任务勾选不等于 Capability 交付。硬约束摘要保留。
- 安装 IWE skill。它组织调查，不签发 Verdict、审批或交付结论。
- `docs/AGENTS.md` 增加 knowledge state、lifecycle、Topic 读约与 Pipeline handoff。新日期夹要求 `topic.yaml`。
- Pipeline 增加 Contract / Run identity / P0–P3 Acceptance 语义。两条现有 Graph 只补 `contract.yaml` 与验收刻度，不改 cook 脚本。
- 明确三套刻度不互推：Pipeline P0–P3、ICD L1–L4、`guess-governance` L1–L3。
- 已安装 OpenSpec CLI 1.3.1 没有 `openspec create`。Agent 命令改为实际存在的 `openspec new change`。
- 不引入自动 commit、Python cook、并行 lease、DCC Context 必填，也不把 CED / DOCS 标成 Established。

## Capabilities

### New Capabilities

- `monospec-authority-stack`: 编排仓用 FEV / ICD / CED / DOCS / Pipeline Contract 区分可行性、能力交付、Epic 停止条件、知识状态与 cook 验收，且不改本仓技术栈。

### Modified Capabilities

- （无）

## Impact

- **仓库**：仅 MaterialMonospec 编排仓（`traits/`、`openspec/`、`docs/AGENTS.md`、`pipelines/` 契约与两条试点 Graph 的契约文件、`scripts/`、根 `AGENTS.md`）。
- **不改**：`repos/` 产品代码、Node.js cook 实现、family 词表、现有 Graph 脚本与 `config.yaml` 行为。
- **协作**：仍仅在用户明确要求时 commit。Pipeline PASS 或 DOCS `CONFIRMED` 不能代替 Human `APPROVED` 去改产品行为。
