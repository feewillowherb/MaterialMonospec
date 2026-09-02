# Acceptance — urban-db-accesscode-migrate

Status: **pending**

Agent 不得将本文件改为通过。用户回复 `pass` / `fail` 后，只改**本次 run** 下的副本。

| 项 | 值 |
|----|-----|
| run | |
| L0 | pending |
| L1 | pending |
| L2 | pending |
| L3 | pending（仅用户） |
| 对象 | `_tmp/UrbanManagement.db` 本地副本 + AccessCode rename migrate + UM 冒烟 |
| 原因 | |

### 验收提示

- L0：工作副本存在；`logs/` 含 `Database migration completed successfully`（不得仅有 failed）
- L1：`schema/post-schema.json` 中三流水表 `hasAccessCode=true` 且 `hasBuildLicenseNo=false`；`UrbanWeighingRecords.rowCount` 与 pre 一致
- L2：history 含 `20260902100000_RenameEntityBuildLicenseNoToAccessCode`；`http/` 中 `/` 与 weighing-list 有响应文件
- L3：浏览器打开本机 UM，称重列表接入码数据可见 — **仅用户**
