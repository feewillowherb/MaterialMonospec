# Epic 追溯：xiaoshan-platform-upload-epic

> 脚手架：PRD FR 尚未编号；下表以 **INT** 为追溯主键。补 PRD 后可增「PRD 需求」列。

| INT | 摘要 | 锁定决策 | 规划 Slice | 建议 OpenSpec change-id | 主要子仓库 |
|-----|------|----------|------------|-------------------------|------------|
| [INT-001](../../../docs/intake/2026-08/INT-001-xiaoshan-upload-config-dual-edit.md) | 上报配置模型与双端编辑；服务端权威 | D1 | `01-upload-config-dual-edit` | `add-xiaoshan-upload-config-dual-edit` | MaterialClient, UrbanManagement |
| [INT-002](../../../docs/intake/2026-08/INT-002-xiaoshan-upload-config-sync-version.md) | `configVersion` 同步裁决 + 配置变更审计日志 | D2, D3, D5 | `02-upload-config-sync-version` | `add-xiaoshan-upload-config-sync-version` | MaterialClient, UrbanManagement |
| [INT-003](../../../docs/intake/2026-08/INT-003-xiaoshan-upload-modes-field-mapping.md) | Weighbridge/Gate/Product 多选与字段映射；缺源跳过标注 | D4 | `03-upload-modes-field-mapping` | `add-xiaoshan-upload-modes-field-mapping` | MaterialClient, UrbanManagement |
| [INT-004](../../../docs/intake/2026-08/INT-004-xiaoshan-upload-legacy-client-compat.md) | 旧客户端协议/服务端降级兼容 | D6 | `04-upload-legacy-client-compat` | `add-xiaoshan-upload-legacy-client-compat` | MaterialClient, UrbanManagement |

## 分支策略（集成）

| 项 | 约定 |
|----|------|
| Epic 集成分支 | `epic/xiaoshan-platform-upload` |
| 四个 slice / INT | **共用**上述集成分支（或短期 `…-step-N` 完工后 **merge 回该集成分支**） |
| 合入目标 | 每阶段完工 → 合入 **`epic/xiaoshan-platform-upload`** |
| **禁止** | 按阶段直接合入 **`main`** |
| Epic 收尾 | 四阶段都完成后，再将集成分支合入 `main`（PR） |
| 子仓库 | MaterialClient / UrbanManagement 各自开同名或对应 `epic/xiaoshan-platform-upload` 集成分支，同样按阶段合入各自 Epic 分支，不按阶段合 `main` |

## 建议实施顺序

```
01-upload-config-dual-edit          ← INT-001（底座）
        ↓  merge → epic/xiaoshan-platform-upload
02-upload-config-sync-version       ← INT-002
        ↓  merge → epic/xiaoshan-platform-upload
03-upload-modes-field-mapping       ← INT-003（可与 02 部分并行，仍依赖 01）
        ↓  merge → epic/xiaoshan-platform-upload
04-upload-legacy-client-compat      ← INT-004（依赖 01；相关 02/03）
        ↓  merge → epic/xiaoshan-platform-upload
        ↓
      （整包）→ main
```

## 决策速查（来自 draft D1–D6）

| # | 项 | 结论 |
|---|-----|------|
| D1 | 权威端 | 服务端权威；客户端可改，须回写并对齐后生效 |
| D2 | 一致性 | 仅单调递增 `configVersion`（无强制 payload hash） |
| D3 | 冲突 | 高 version 胜；客户端落后 → 拉服务端覆盖本地 |
| D4 | 非必填无源 | 可跳过；上报路径与配置 UI 标注；不阻断主流程 |
| D5 | 变更日志 | 必须；审计用；不替代 version 裁决 |
| D6 | 旧客户端 | 必须兼容未及时升级端；协议/服务端降级 |

## 状态约定

- INT **不**物理 archive；进本 Epic 后 `status: absorbed`，`absorbed_into` 指本目录。
- OpenSpec propose 后 → `proposed` + `change`。
- change archive 后 → `closed(completed)`。
