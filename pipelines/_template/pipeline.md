# {{slug}}

## 目的 / Goal

{{goal}}

Status: **active**

若替换旧验法：retired ← （无）

## 非目标

- 不修改 `repos/` 业务代码
- 不提交 secrets / runs
- 不替代 OpenSpec 与 CI
- Agent 不宣布 L3 通过

## 配置指针

- `./config.yaml`
- `./secrets.local.yaml`（gitignore）
- `./secrets.example.yaml`

路径约定见 [`pipelines/AGENTS.md`](../../AGENTS.md)：`graphs/<domain>/<slug>/`。

## Sockets

| | |
|--|--|
| Start | {{socket_start}} |
| End | {{socket_end}} |
| Cook | {{cook}} |

## Context

- 指针：见 `config.yaml` 的 `target`
- 指纹：按 family 的必达地标（页面选择器 / 表头 / 状态码）
- 显示名：仅人读，禁止当唯一键
- 歧义：停止并问用户

## 状态机 / Cook chain

```mermaid
flowchart LR
  BindN[Bind]
  CookN[Cook]
  ValidateN[Validate]
  GateN[Gate]
  BindN -->|"{{socket_start}}"| CookN
  CookN -->|"{{socket_end}}"| ValidateN --> GateN
```

失败策略：`retries: 2`（ingest 写库常用 0）；`stopOnError` 见 config。

## 证据包

相对本次 `runs/<yyyy-MM-ddTHHmmss>/`：

| collector | required | sink |
|-----------|----------|------|
| （生成时按 family 填） | | |

缺证仍写文件：`source: missing` / `count: 0`。

## Invoke

- 命令：`/run-pipeline {{domain}}/{{slug}}`（或 slug；选型见 AGENTS.md）
- 脚本：`./scripts/`（experimental；无则省略）

## 人闸 / Gate

- 缺密钥 / Context 歧义
- `environment` ≠ `local` 时确认
- ingest 且 `dryRun: false` 时确认写入
- 最终验收：用户 `pass` / `fail`

## 判定级别

| 级 | 谁判 |
|----|------|
| L0 可达 | Agent |
| L1 非空壳 | Agent 提示 |
| L2 契约可见 | Agent 提示 |
| L3 业务正确 | **用户** |

## Handoff

Output socket：`{{socket_end}}`。下游 Graph 若要接，须声明对齐该态。
