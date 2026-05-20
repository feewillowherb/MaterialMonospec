# Implementation Readiness：materialclient-urban-epic

**日期**: 2026-05-20  
**结论**: ✅ **可交给 OpenSpec**（按 4 个 slice 顺序执行）

## 检查清单

| 项 | 状态 | 说明 |
|----|------|------|
| PRD 完成 | ✅ | `prd.md` |
| 架构完成 | ✅ | `architecture.md`，含 ADR 与 API 概要 |
| Epic 已切片 | ✅ | 4 个 slice，各含 proposal + design |
| 跨仓库边界清晰 | ✅ | 每个 slice proposal 标注 Impact |
| project-context | ✅ | `project-context.md` |
| 无 BMAD tasks | ✅ | 未生成 tasks.md / sprint |
| UX 阶段 | ⏭️ 跳过 | 需求明确首期无 UI |
| 开放问题 | ⚠️ | OQ-1~4 见 PRD；可在 slice 03 design 中闭合 |

## 未决项（不阻塞 OpenSpec propose）

1. **无 UI 下称重触发方式**：slice 02 采用 headless/后台服务 + 集成测试钩子。
2. **UrbanWeighingRecord 表字段**：slice 03 与现有 `WeighingRecord` 字段对齐后定稿。

## 下一步（用户衔接 — 操作手册 §5）

对每个 slice：

```bash
openspec create add-materialclient-urban-host
# 将 slices/01-.../proposal.md 导入 /opsx:propose
# 将 design.md 作为 apply 参考
```

完成后按顺序 `/opsx:apply` → 子仓库编码 → `/opsx:archive`。

## bmad-help 等效指引

规划阶段已完成。请**不要**使用 `bmad-dev-story`。下一步：**OpenSpec propose 第一个 change** `add-materialclient-urban-host`。
