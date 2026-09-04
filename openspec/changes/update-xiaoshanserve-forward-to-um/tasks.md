## 1. Branch and configuration

- [x] 1.1 Mode A：`Fdsoft.Weight.GovClient` 回 `master` 后自 trunk 创建并切换分支 `update-xiaoshanserve-forward-to-um`（首次改代码前；不动现有 `feat/*` 分支）
- [x] 1.2 `appsettings.json` 新增扁平键 `UrbanManagementForwardUrl`（示例值注释指向 UM `{portB}/Api/Post`）与 `EnableGovExport`（缺省不写 = false）

## 2. Forward implementation

- [x] 2.1 `Program.cs`：注册 `IHttpClientFactory` 命名客户端（`UmForward`，超时 60s）；`AddHostedService<ExplortStatisticBgService>()` 改为仅 `EnableGovExport=true` 时注册
- [x] 2.2 重写 `ApiController.Post`：原始 `Request.Body` 流式构造 `StreamContent` → POST `UrbanManagementForwardUrl` → 恒 HTTP 200 透传 UM body（`application/json`）
- [x] 2.3 传输失败分支：HTTP 200 + `{ success:false, msg:"forward failed: ...", code:-1 }`；`UrbanManagementForwardUrl` 缺失时同形状失败 + 日志告警
- [x] 2.4 删除 Post 内本地处理：`GovSyncData` 构造与插入、凡东码/城管码查库换码、`TempUpload` 图片落盘（不留开关）；不再使用的 `using` 一并清理

## 3. Verification (no test infra in repo)

- [x] 3.1 `dotnet build` 通过；确认 `ApiController.Post` 无 `GovSyncData`/`DbHelper`/落盘引用残留
- [x] 3.2 样例报文联调三场景：成功入库（UM `IngestSource=1` + Lpr 附件 + `success=true`）；未知码拒收（UM 暂存 + `success=false`）；停 UM（Serve `code:-1` 失败形状）
- [x] 3.3 双写零残留：转发后 `XiaoShan.db` `Gov_SyncData` 无新行、`TempUpload` 无新文件；默认配置启动无出站请求

## 4. Docs and monospec

- [x] 4.1 调研夹 `00-调研总览.md` D7/D11 补记修订行（运维转发 → Serve 代码转发，指向本 change）；上一 change `ops-notes.md` 切流段补代码转发替代方案指针
- [x] 4.2 提交本 change 工件至 MaterialMonospec

## 5. Merge

- [x] 5.1 Mode A squash 单提交入 `Fdsoft.Weight.GovClient` trunk（`master`）并推送；归档前跑 `/opsx-verify-agents`（若适用）
