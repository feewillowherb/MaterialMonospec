# Acceptance — cutover-safety-drill

| 级 | 条件 | 判定 |
|----|------|------|
| P0 | SSH 可用且 sudo 免交互 | Agent |
| P1 | 远端演练跑完 | Agent |
| P2 | `report.md` 全部检查通过（回滚导出的行与存储格式） | Agent |
| P3 | 用户采纳 | 用户 |

每个 run 的结果见 `runs/<ts>/acceptance.md`。
