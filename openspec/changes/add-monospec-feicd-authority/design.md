## Context

对照来源是 BlenderTools-MonoSpecs 的 Monospec。本仓 cook runtime 已是 Node.js（`pipelines/AGENTS.md` §4）。来源 FEV 为 Proposed，且含并行调查；CED 与 DOCS 为 PENDING。本 change 只采用能在本仓写成文、且不与 `strategic-fallback`、显式 commit、`guess-governance` 冲突的切片。

## Goals / Non-Goals

**Goals:**

- 把可行性、能力交付、Epic 停止、知识状态、Pipeline 验收分成不同权威。
- 给两条现有 Graph 补机器可读契约与 P0–P3 验收说明。
- 让 Agent 在 cook 前能读到 contract，并用稳定 Run identity 引用证据。

**Non-Goals:**

- 不改产品技术栈与 Node.js cook 实现。
- 不迁入 Python cook、DCC / 引擎域约定、并行 lease、Socket 必填模型。
- 不把来源整份 trait 标成本仓 Established。
- 不建 `repos-meta/` 或 `bootstrap/`。
- 不自动 commit。

## Decisions

1. **FEV 只保留核心环。** Unknown → Experiment → Evidence → Verdict。并行 Sub-FEV 与 resource lease 不进入本仓。状态保持 Proposed。
2. **ICD 采用「Task 完成 ≠ Capability 交付」。** 归档前 tasks 勾选只说明变更文件做完。
3. **CED 保持 PENDING。** 只在用户已授权的 Epic 内做显式 STOP / Defer。它不授权 commit、push 或生产变更，也不覆盖 `strategic-fallback`。
4. **防守外壳仍是 `strategic-fallback`。** 不另写 Blocker Local Policy。
5. **DOCS 保持 PENDING。** `docs/AGENTS.md` 是 Local Policy，继续持有 BMAD 路由。
6. **Pipeline 刻度用 P0–P3。** 与 ICD L1–L4、`guess-governance` L1–L3 不互推。现有 config 里的 `expect.level` 不改，避免改变 cook。
7. **试点 Graph** 为 `materialclient/login-devtools`（observe）与 `urban/urban-passage-um-reconcile`（reconcile）。只新增契约文件。
8. **CLI** 写成 `openspec new change`，因为本机 OpenSpec CLI 1.3.1 提供的就是这个命令。
9. **Phase 4** 只加不替代现有路由的薄 trait，并写明不做 `repos-meta/` 与 `bootstrap/`。

## Risks / Trade-offs

- 根 `AGENTS.md` 仍然较长。本次只加入口与归档句，不删除编码硬约束摘要，避免瘦身时丢掉每日都会加载的规则。
- 试点验收文件改用 P0–P3 后，与 config 里旧的 L0–L3 标签并存。契约里写明映射，脚本继续读 config。
- CED 未在本仓验证前保持 PENDING。Agent 不得把它当成默认继续授权。

## Migration Plan

1. 先落 traits 与 `openspec/AGENTS.md`，再装 IWE。
2. 更新 docs 与 pipelines 的 Local Policy。
3. 为两条 Graph 增加 `contract.yaml`，并把对应 `acceptance.md` 的刻度写成 P0–P3。
4. 不回填历史 `runs/`，不修改已归档 change。

## Open Questions

- 无。Phase 0 决议已写在 `docs/2026-11-02-monospec-design-upgrade/02-升级路线图.md`。
