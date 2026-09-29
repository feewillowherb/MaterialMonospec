## Context

- 上游已就绪：UM `LegacyGovSyncAppService` 实装（change `add-urban-legacy-weighing-ingest`，squash `919f680`）接收 `/Api/Post` 旧报文 → `UrbanWeighingRecord`（`IngestSource=Legacy`）+ Lpr 附件 + 拒收暂存；端点 `AllowAnonymous`。
- 现状 `ApiController.Post`：凡东码换码 → 建 `GovSyncData` → 图片解 Base64 落盘 `TempUpload` → 插 SQLite（`XiaoShan.db`）；`ExplortStatisticBgService` 每 ~5 秒把 `GovSyncData` 出站推政府（读 `GovAddress` 配置）。
- 原切流方案 D7/D11 为同机反代/portproxy 纯运维转发；现场不可安装反代，修订为 Serve 代码内转发。
- 该仓为遗留栈：.NET 6 minimal hosting、Newtonsoft、SqlSugar、自有 `AppSettings` 扁平键配置、`FdController.JsonDate` 恒 HTTP 200 序列化 `ApiResultDto`。**无测试项目**。
- 旧客户端契约：POST `/Api/Post`，期待 HTTP 200 + body `{ success, msg, code, ... }`（Newtonsoft 序列化，属性本为小写开头）。

## Goals / Non-Goals

**Goals:**

- 旧客户端零改动：仍打 Serve 端口 `/Api/Post`，响应契约不变（HTTP 200 + 业务结果在 body）。
- Serve 转发路径**零持久化**：不写 `GovSyncData`、不落盘、不查库、不映射（对齐 D1/D8/D12）。
- 政府出站唯一化：UM Worker 为唯一出站；Serve 出站 worker 配置停用（Q5 在常驻进程拓扑下的落地）。
- 目标地址可配置、失败可回滚。

**Non-Goals:**

- 字段映射 / 凡东码换码（转换只在 UM，D1）。
- INT-007 历史批迁；`XiaoShan.db` 存量数据不动。
- 其它控制器（FileViewer/Home/MainPage/Project/SyncInfo）与 UI。
- UM 侧任何代码改动；鉴权（两端均无鉴权，D10）。
- 为遗留仓引入测试基建 / DI 重构（保持最小侵入）。

## Decisions

### D1 — 转发实现：`ApiController.Post` 原样 body 转发，不经模型绑定

- 现签名 `Post([FromBody] dynamic model)` 会先经 Newtonsoft 反序列化；改为读取**原始请求体**（`Request.Body` 流拷贝为 `StreamContent`）直接 POST，避免任何解析/再序列化引入的报文漂移（字段丢失、编码、大小写）。
- 备选（否决）：反序列化成 `mGovRequestWeight` 再转发 —— 违背「零映射」且引入双向序列化风险；YARP 包引入 —— 对单端点转发过重。

### D2 — HttpClient：`IHttpClientFactory` 命名客户端，超时放宽

- `Program.cs` 注册 `services.AddHttpClient("UmForward")`，超时 60s（含 base64 多图大报文 + UM 存图耗时）。
- 配置键沿用扁平风格：`UrbanManagementForwardUrl`（完整 URL 含 `/Api/Post`，与既有 `GovAddress` 键风格一致；缺省空 → 启动日志警告，转发请求返回失败响应）。

### D3 — 响应契约：恒 HTTP 200，透传 UM body；传输失败返回旧版失败形状

- 旧客户端只认 HTTP 200 + body（`JsonDate` 历史行为）。转发成功：原样返回 UM 响应 body（UM 已产出 `{ success, msg, code, data }`，旧客户端按 `success`/`code` 解析，多余字段无碍）。
- 传输失败（UM 不可达/超时）：HTTP 200 + `{ success:false, msg:"forward failed: <原因>", code:-1 }`（`-1` 对齐既有 Post 失败分支的 code 语义），客户端按既有重试逻辑处理。
- 备选（否决）：透传 UM HTTP 状态码（400/500）—— 旧客户端从未见过非 200，兼容风险不可控。

### D4 — 出站 worker 停用：配置开关，默认关闭

- `Program.cs`：`services.AddHostedService<ExplortStatisticBgService>()` 改为受 `EnableGovExport`（bool，默认 **false**）控制。
- 代码级转发下 Serve 进程必须常驻，出站停用只能进程内解决；默认关 = 部署即达成 Q5「停出站」，开 = 仅供回滚窗口期使用。
- `ExplortStatisticBgService` 类本身不删（回滚开关需要）。

### D5 — 旧本地处理代码随重写移除，不留开关

- Post 内 `GovSyncData` 构造、凡东码/城管码查库、图片落盘逻辑**直接删除**，不保留「本地入库」开关 —— 双写开关误开即双报政府，风险不可接受（对齐上游 change Risks「转发层误落盘」验收项）。
- 影响的仅 `ApiController.Post` 一个方法；`GovSyncData` 模型/其它引用处不清理（遗留仓最小侵入，清扫另立 change）。

### D6 — Git Mode A

- `Fdsoft.Weight.GovClient` trunk = `master`；change 同名分支自 master 切出，squash 单提交回 master。当前仓停在 `feat/catch-capture-expection` 分支，切分支前先回 master（该分支不动）。

## Risks / Trade-offs

- [UM 不可达 → 旧客户端重试风暴] → 与现状「UM 挂」等价；失败响应含原因便于定位；QPS 量级为单工地地磅，可接受。
- [大报文 buffer 内存峰值] → `Request.Body` 流式拷贝至 `StreamContent`，不全文驻留字符串；报文量级（数张 base64 图）在 .NET 6 默认配额内。
- [配置错 URL → 全量拒收进 UM 暂存表或转发失败] → 部署清单含连通性验证步骤（样例报文 + 确认 UM 侧入库）；`UrbanManagementForwardUrl` 缺失时启动即告警。
- [出站开关误开 + UM 同步并行 → 双报] → 默认 false；运维文档明确「仅回滚窗口可临时开启」。
- [遗留仓无测试基建] → 以构建通过 + 双机样例报文联调（成功/未知码拒收/UM 停机三场景）作为验收，不为本仓新增测试项目。

## Migration Plan

1. 配置：`appsettings.json` 增加 `UrbanManagementForwardUrl`（指向 UM `{portB}/Api/Post`）；确认 `EnableGovExport` 缺省（false）。
2. 部署新版本 Serve（替换 bin / 站点）；进程常驻即可，无需反代。
3. 验证：样例报文（城管码 + base64 图）打 Serve 端口 → UM `UrbanWeighingRecords` 新行 `IngestSource=1`、附件 Lpr、Serve 响应 `success=true`；未知码样例 → UM 拒收暂存 + `success=false`；临时停 UM → Serve 返回 `code:-1` 失败形状。
4. 确认无新增：Serve `XiaoShan.db` `Gov_SyncData` 无新行、`TempUpload` 无新文件。
5. 回滚：部署旧版本二进制（本地入库+出站行为恢复）；回滚窗口内如需临时出站，置 `EnableGovExport=true` 前须先停 UM Worker 防双报。

## Open Questions

- 无阻塞项。UM 目标端口（`{portB}`）由部署环境确定，走配置不进代码。
