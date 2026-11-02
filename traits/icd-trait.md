# ICD — Incremental Capability Delivery

## Metadata

```yaml
trait:
  id: icd
  version: "1.0.0"
  date: "2026-11-02"
  status: Established
  type: Engineering Method
```

## Core

交付单位是 Capability，不是 Task。

```text
Task completed ≠ Capability delivered
```

以下结果本身不能证明 Capability 已交付：文件已创建、TODO 已勾完、函数已实现、构建成功、单个测试通过、Agent 声称完成、`tasks.md` 全部勾选。

## Acceptance levels

只在声明了目标等级、且有对应该等级的 Evidence 时声称等级。

| Level | 证明 | 不证明 |
|-------|------|--------|
| L1 | 目标环境中的基本路径可以运行 | 业务能力已可用 |
| L2 | 声明的核心业务路径可被目标用户或系统使用 | 例外路径已完整 |
| L3 | 声明范围内的能力已完整可用，含已声明的失败行为 | 已有回归保护 |
| L4 | 声明的能力有回归保护 | 范围外的能力 |

更高一级不得由低一级推断。L1 不得说成 L2。

## Scale boundary

ICD 的 L1–L4 只描述 Capability Acceptance。

- Pipeline cook 使用 P0–P3，不得换算成 ICD 等级。
- `guess-governance` 的 L1–L3 是需求风险，不是本表。

## Archive

归档前可以核对 tasks 是否勾完。勾完只说明变更文件做完。被阻断的能力必须仍标为未交付。

## Non-goals

ICD 不决定 Epic 继续或停止，也不验证一个尚未选择的技术方案是否可行。
