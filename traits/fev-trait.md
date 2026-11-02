# FEV — Feasibility

## Metadata

```yaml
trait:
  id: fev
  version: "1.0.0-core"
  date: "2026-11-02"
  status: Proposed
  type: Engineering Method
  adopted: core-loop
```

来源含并行调查与 resource lease。本仓只采用核心环。状态不得写成 Established。

## Core

先用证据判断方案是否可行，再进入产品实现。

```text
Unknown → Experiment → Evidence → Verdict
```

`researched` / `plausible` 不等于 `FEASIBLE`。

## What FEV owns

- 要回答的可行性问题
- 最小可判别实验
- 实验证据
- Verdict：`FEASIBLE` / `INFEASIBLE` / `INCONCLUSIVE`

## What FEV does not own

- Capability 是否交付（ICD）
- Epic 是否继续（CED）
- 产品 SHALL（OpenSpec）
- 知识是否可复用（DOCS）
- 需求假设与 Guess Risk（`guess-governance`）

`FEASIBLE` 不是 ICD `PASS`，也不取消 Pipeline / DOCS 进入产品行为前的 Human `APPROVED`。

## When to run

存在会改变实现路线的技术不确定性时使用。已知修复、单点查找、已有可复用结论，不为此发明一套实验。

## Evidence

- 记录观察、输入与失败，而不只记录结论。
- 证据路径使用仓库相对路径。不得写入密钥、token 或本机私有绝对路径。
- 失效的 Run 不得再当作当前证据。

## Verdict

| Verdict | 含义 |
|---------|------|
| `FEASIBLE` | 目标环境中的证据支持该方案可继续设计 |
| `INFEASIBLE` | 证据否定该方案 |
| `INCONCLUSIVE` | 证据不够，不得写成可行 |

没有证据时不得给出 `FEASIBLE`。

## Stop

实验已回答路线问题，或继续实验不会改变路线时停止。不得用重试次数代替停止条件。

## Out of scope for this repo

- 并行 Sub-FEV
- resource lease
- 并行协调器
- 取消 Human `APPROVED` 人闸
