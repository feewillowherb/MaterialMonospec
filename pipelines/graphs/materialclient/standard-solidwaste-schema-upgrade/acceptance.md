# Acceptance — standard-solidwaste-schema-upgrade

Status: **pending**

Agent 不得把本文件改成通过。用户回复 `pass` / `fail` 后，只改本次 run 下的副本。

| 项 | 值 |
|----|-----|
| run | |
| P0 | pending |
| P1 | pending |
| P2 | pending |
| P3 | pending（仅用户） |
| 对象 | `_tmp/1110/MaterialClient.db` 的工作副本 |
| 原因 | |

### 验收提示

- P0：`summary.json` 里 `sourceUnchanged` 为 true，且 `workingDb` 只出现在本次 `runs/<runId>/working/`
- P1：内核历史 id 与内核迁移文件一致，且运行后不变；Standard / SolidWaste 历史表含配置里的迁移 id
- P2：`WeighingRecords` 与 `Waybills` 的主键哈希和行数不变；`WeighingMode = 1` 的未删除行有扩展；第二次补数的扩展内容哈希不变；`WeighingMode = 0` 没有扩展行
- P3：用户接受该次 run。Cook 不得填写
