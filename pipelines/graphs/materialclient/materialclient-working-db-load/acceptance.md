# Acceptance — materialclient-working-db-load

Status: **pending**

Agent 不得把本文件改成通过。

| 项 | 值 |
|----|-----|
| run | |
| P0 | pending |
| P1 | pending |
| P2 | pending |
| P3 | pending（仅用户） |
| 对象 | Start-MaterialClient 环境中的 MaterialClient.db，内容来自 working 副本 |
| 原因 | |

### 验收提示

- P0：环境库已被工作副本替换，正式样本未改
- P1：`MaterialClient.exe` 已启动，且有本次新日志
- P2：新日志含 `Standard and SolidWaste database migration completed.`。Web Host 启动错误忽略。其余 `[ERR]` / `[FTL]` 仍失败
- P3：用户接受。Cook 不得填写
