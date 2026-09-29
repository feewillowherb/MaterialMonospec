# Ops Notes — Legacy 切流说明（D7 / D11 / Q5）

实施 change：`add-urban-legacy-weighing-ingest`（消化 INT-006）。
权威调研：[docs/2026-09-03-xiaoshanserve-forward-to-urban-weighing-record/00-调研总览.md](../../../docs/2026-09-03-xiaoshanserve-forward-to-urban-weighing-record/00-调研总览.md)（D1–D12）、[02-字段映射与缺口.md](../../../docs/2026-09-03-xiaoshanserve-forward-to-urban-weighing-record/02-字段映射与缺口.md) §2.3。

## 切流拓扑（D11）

- 同机异端口：Client → XiaoShanServe:`{portA}` `/Api/Post` → **纯 HTTP 转发** → UrbanManagement:`{portB}` `/Api/Post`。
- Serve 不做映射、不落盘、不写 `GovSyncData`、不出站（D7/D8）；转换只在 UM。
- **2026-09-04 替代方案**：现场不可装反代时，转发改由 Serve **代码内极薄转发**实现（change `update-xiaoshanserve-forward-to-um`）；本节反代/portproxy 方式作废，其余步骤（停出站、验证、回滚）不变，出站停用改为 `EnableGovExport` 配置开关（默认 false）。

## 切流当日动作（Q5：停 Serve 出站，默认是）

1. 部署 UM（migration：`UrbanWeighingRecords.IngestSource` 列默认 0 + `LegacyWeighingRejectStagings` 新表，仅主键）。
2. 停 XiaoShanServe 出站 `ExplortStatisticBgService`；停 Serve 本地落盘（不再写 `TempUpload/`）。
3. Serve 入口改为仅转发 `/Api/Post` → UM 端口。
4. 验证成功路径：样例报文（城管接入码 + `snapImages` base64）打 Serve 端口 → UM `UrbanWeighingRecords` 新行 `IngestSource=1`（Legacy）、附件 `AttachType=Lpr`、响应 `{ success:true, code:200 }`。
5. 验证拒收路径：未知接入码样例 → `LegacyWeighingRejectStagings` 有行（含 Base64）且响应 `success=false`。

## 回滚

- 回退本 change 部署即恢复 Legacy stub 501；删除新表/列前先备份 `LegacyWeighingRejectStagings` 数据。

## 范围外

- INT-007 历史批迁（`Gov_SyncData` → `UrbanWeighingRecord`）不在本 change；`Migrated` 枚举值仅占位，无业务写入路径。
