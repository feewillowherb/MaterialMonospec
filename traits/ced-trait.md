# CED — Epic stop and defer

## Metadata

```yaml
trait:
  id: ced
  version: "0.1.0"
  date: "2026-11-02"
  status: PENDING
  type: Engineering Method
```

本仓继续边界尚未在实际 Epic 中验证。在验证前，状态保持 PENDING，不得写成 Established。

## Core

CED 只管理**已经由用户授权的 Epic** 里，显式的 STOP 与 Defer。

它不把「默认继续」当作总原则。下一步只有在同时满足下面条件时才继续：

- 用户已经授权这个 Epic
- 下一步独立且可逆
- 不需要 commit、push 或生产变更
- `strategic-fallback` 未触发
- `guess-governance` 未把该项判为高风险（其 L3，或 Risk≥40）

## Stop or defer

出现下列任一情况时 STOP 或 Defer，并写明原因：

- 可行性仍是 `INCONCLUSIVE` 或 `INFEASIBLE`
- ICD 目标等级没有 Evidence
- 继续会改写已验证行为
- 需要用户决定范围、发布或不可逆数据

CED 不得把 ICD FAIL 改写成 PASS。

## What CED does not own

- 技术可行性结论（FEV）
- Capability 验收（ICD）
- 伪实现时的代码外壳（`strategic-fallback`）
- Git commit 或 push
- 产品 SHALL

## Output

STOP 或 Defer 时写明：当前 Epic、停止原因、已完成且有证据的部分、留给后续 change 的部分。不得用空实现表示继续。
