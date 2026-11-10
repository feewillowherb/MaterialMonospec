# pipelines

Trait：Graph 的 Contract、Run identity、Evidence 与 Acceptance。选型、family 词表与 Node.js cook 以 `pipelines/AGENTS.md` 为准。本 trait 不改变 cook 实现。

## Metadata

```yaml
trait:
  id: pipelines
  version: "1.0.0"
  date: "2026-11-02"
  status: Established
  type: Engineering Method
  runtime: nodejs
  experimentRuntime: net10.0
```

## What a pipeline is

一条现行验收 Graph：如何在已知输入下重跑，以及怎样解释证据。它不是 OpenSpec 规格，也不是调研笔记。

产品行为仍走 OpenSpec。密钥只放 `secrets.local.yaml`。不得覆盖已有 `runs/`。

## Model used in this repo

| 概念 | 含义 |
|------|------|
| Goal | 同一终态槽；同时只一条 `active` Graph |
| Graph | `pipelines/graphs/<domain>/<slug>/` |
| Cook | 按 `pipelines/AGENTS.md` §4 执行的 Node.js cook。§4.2 允许另加 net10.0 实验项目 |
| Contract | `contract.yaml`：输入、输出、不变量 |
| Evidence | 一次 Run 目录里的产物 |
| Acceptance | 用 P0–P3 解释 Evidence |
| Run identity | 可被 DOCS / OpenSpec 引用的稳定身份 |

现有 Graph 可以在 `config.yaml` 里已经写了 socket。新契约不得把 Socket、Wire 或 Context 变成所有 Graph 的必填项。

## Contract

有 `contract.yaml` 的 Graph，在生成或 cook 前读取：

1. `pipelines/AGENTS.md`
2. 该 Graph 的 `pipeline.md`
3. `config.yaml`
4. `contract.yaml`
5. 若存在，`acceptance.md`

`contract.yaml` 只机器化 `pipeline.md` 与 `config.yaml` 已经写明的接口和不变量。不新增密钥字段，不改变 cook 行为。

## Run identity

一次 Run 的稳定身份至少包含：

- `graphId`
- `graphPath`（仓库相对路径）
- `runId`（`runs/<yyyy-MM-ddTHHmmss>/` 的目录名）
- `result`：`pass` / `fail` / `blocked` / `unknown`

可以另记 `gitRevision` 与证据相对路径。身份与清单约定见 `pipelines/_shared/evidence/AGENTS.md`。

## Acceptance scale

Pipeline 使用 **P0–P3**。

| 等级 | 含义 |
|------|------|
| P0 | 前置满足，目标可被定位或端点可达 |
| P1 | 声明的操作已经作用到目标 |
| P2 | 声明的可观察结果出现 |
| P3 | 用户接受该结果。Agent 不得自评 P3 为产品通过 |

ICD 使用 L1–L4。`guess-governance` 使用自己的 L1–L3。三者不得互推。

历史 `config.yaml` 的 `expect.level: L0–L3` 继续留给现有 cook 读取。新的 `acceptance.md` 使用 P0–P3，并写明与旧标签的对应关系。不得为了改名去改 cook 脚本。

## Cook runtime

本仓默认 cook runtime 是 Node.js。复杂 cook 用 TypeScript，短探针可用 `.mjs`。本 trait 不把默认 cook 改成 Python。Human 已授权的附加实验运行时是 `net10.0`，位置与边界以 `pipelines/AGENTS.md` §4.2 为准。
