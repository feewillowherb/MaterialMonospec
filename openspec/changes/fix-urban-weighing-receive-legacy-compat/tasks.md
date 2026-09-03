## 1. Branch & inventory



- [x] 1.1 UrbanManagement：自 trunk 切出同名分支 `fix-urban-weighing-receive-legacy-compat`（Mode A）

- [x] 1.2 确认 `ReceiveAsync` 绑定的是 `UrbanWeighingRecordReceiveInputDto`；检查 `App.Models.UrbanWeighingRecordDto` 是否仍有 HTTP/JSON 反序列化路径并记下对齐需求



## 2. Legacy-tolerant Receive wire DTO



- [x] 2.1 将 `UrbanWeighingRecordReceiveInputDto` 的 `SiteType` 改回宽松入参（`string?` 或等价 tolerant 绑定），`SyncType`/`ClientSyncType` 改为可空 int 或 tolerant 形态，`ClientRetryCount` 改为 `int?`

- [x] 2.2 若 1.2 确认 App DTO 仍参与绑定：对同形字段做相同放宽；否则跳过并在 PR/注释说明

- [x] 2.3 实现 static 解析（无 DI）：`siteType` wire → `UrbanSiteType`；`sync` wire（含 `Synced` 别名）→ `SyncStatus`；缺省规则按 design D2



## 3. ReceiveAsync 映射与类型归属



- [x] 3.1 在 `ReceiveAsync`（及重复提交更新路径）使用解析结果写入实体；若触及逐字段赋值，迁到 `UrbanWeighingRecord` 的 `FromReceive` / 实例更新方法（type-owned-methods）

- [x] 3.2 保持 `ProId` / `ClientRecordId` 硬校验、幂等、附件关联、`IsAnomaly` 语义不变；不恢复 `FdBuildLicenseNo`



## 4. Tests & verify



- [x] 4.1 单测：`"1"`/`"2"`/枚举名/省略 `siteType`；`syncType` int；`clientSyncType`=`Synced`；非法/空 `proId` 仍拒绝

- [x] 4.2 手工或集成：旧客户端样例 JSON → multipart（可选）→ `receive` 返回非空 `RecordId`，无模型绑定 400

- [x] 4.3 确认未引入 `ReceiveV2`、未改 passage receive、无 DB migration



## 5. Close-out



- [x] 5.1 更新本 `tasks.md` 勾选；UrbanManagement squash 合入 trunk；monospec 按需同名分支仅含 OpenSpec 工件

