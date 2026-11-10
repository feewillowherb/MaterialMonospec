# technology-first

## Metadata

```yaml
trait:
  id: technology-first
  version: "0.1.0"
  date: "2026-11-02"
  status: Proposed
```

## Core

多个实现、库、API 或依赖都可能满足同一目标时，先列出可观察的选择标准，再选定一个。未证实的关键差异回到 FEV，不靠偏好写成 Verdict。

## Already decided

`pipelines/AGENTS.md` §4 已经写定默认 Node.js cook：复杂 cook 用 TypeScript，短探针可用 `.mjs`。本 trait 不得把默认 cook 改成 Python，也不得把现有 Node cook 改写成 C#。§4.2 的 `net10.0` 是附加实验运行时，不是这次选型的替代。

产品语言与框架以根 `AGENTS.md` 的子仓说明为准。权威分层升级不改变这些选择。
