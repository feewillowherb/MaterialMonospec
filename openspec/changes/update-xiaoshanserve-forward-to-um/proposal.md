## Why

切流决策 D7/D11 原定为「同机异端口 + 纯运维 HTTP 转发」（portproxy/反代）。现场约束变化：旧地磅客户端**直连** XiaoShanServe 端口，且目标机为生产称重机、**不保证可安装任何反代**；纯运维转发落不了地。需改为 Serve **代码内极薄转发**，才能兑现「转换只在 UM、Serve 不落盘不双报」的目标拓扑。上游 UM 侧 `add-urban-legacy-weighing-ingest` 已合入（squash `919f680`），`/Api/Post` 已可接收并转换旧报文，本 change 是切流闭环的 Serve 侧配套。

## What Changes

- `ApiController.Post` 重写为**纯转发**：原样读取请求 body（不反序列化、不做字段映射）→ HTTP POST 到配置的 UM `/Api/Post` → 以旧版契约返回（HTTP 200 + 透传 UM 响应 body）。
- **删除** Post 内全部本地处理：不再写 `GovSyncData`、不再落盘 `TempUpload` 图片、不再做凡东码换码/项目查询（转换职责全在 UM，对齐 D1/D8/D12）。
- `ExplortStatisticBgService`（进程内政府出站 worker）改为**配置开关停用**：代码级转发下 Serve 进程必须常驻监听，出站无法再靠「停进程」停掉；新增配置项（默认关闭）以落实 Q5「停 Serve 出站」。历史已出站行为不变，仅停新出站循环。
- 新增配置项：UM 转发目标地址（沿用 appsettings 扁平键风格，如 `UrbanManagementForwardUrl`）。
- **本 change 不做**：字段映射/换码（D1：转换只在 UM）；`Gov_SyncData` 历史批迁（INT-007 挂起）；其它控制器（FileViewer/Home/MainPage/Project/SyncInfo）改动；UM 侧任何代码改动。
- **BREAKING**（对 Serve 自身运维语义）：`/Api/Post` 从「本地入库」变为「转发 UM」；Serve 本地 `XiaoShan.db` 不再新增称重数据。

## Capabilities

### New Capabilities

- `xiaoshanserve-um-forward`: XiaoShanServe `/Api/Post` 极薄转发到 UM：verbatim body 转发、旧版响应契约、无本地持久化、目标地址可配置、出站 worker 配置停用。

### Modified Capabilities

（无 — UM 侧行为已由 `urban-legacy-weighing-ingest` / `urban-management-crud` 既有 spec 覆盖，本 change 不改 UM。）

## Impact

- **Fdsoft.Weight.GovClient / FdSoft.MaterialSys.Gov.XiaoShanServe**（Mode A，change 同名分支，trunk=`master`）：`ApiController.Post`、`Program.cs`（HttpClient 注册 + hosted service 开关）、`appsettings.json`（新配置键）。该仓无测试基建，验证以构建 + 样例报文联调为准。
- **决策修订**：D7/D11「运维 HTTP 转发」修订为「Serve 代码内转发」；调研夹总览补记修订行（不改 D1–D12 其余结论）。
- **UrbanManagement**：无代码改动；运行时依赖（转发目标须可达、`GovProject.AccessCode` 须已登记）。
- **运维**：切流步骤从「装反代」变为「配置 UM 地址 + 部署」；出站停用从「停进程」变为「配置开关（默认关）」；回滚 = 还原旧版本部署。
