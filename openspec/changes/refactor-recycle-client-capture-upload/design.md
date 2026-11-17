## Context

Topic [`docs/2026-11-16-materialclient-recycle-resource-alignment`](../../../docs/2026-11-16-materialclient-recycle-resource-alignment/00-调研总览.md) 已确认：Web 管业务表单；工控只采毛重/车牌/照片；第一跳上我方平台；第二跳市平台在平台侧；**无兼容性**。当前 `MaterialClient.Recycle` 仍走 `RecycleModeFormView` 业务表单 + `RecycleDataSyncService` HMAC 直连市接口；`UrbanManagement.XiaoShanResource` 已有运输清单内存 Store，但无工控接收 API。对照实现：`UrbanServerUploadService` → `IUrbanManagementApi.ReceiveWeighingRecordAsync`。

Initiative 基线：`dev-recycle-resource-alignment`（Mode B）。

## Goals / Non-Goals

**Goals:**

- Recycle 有人值守详情变为采集端：车牌 + 毛重 + 照片；完成不再校验供应商/材料。
- 默认上传路径改为我方平台接收 API；成功后本地标记已同步。
- XiaoShanResource 接收过磅数据并写入与运输清单同源的 Store（皮重查车辆池算净重）。
- 市平台 HMAC 同步默认关闭，代码可保留但不得作为产品主路径。

**Non-Goals:**

- 市平台 Worker / §2.2 第二跳实现。
- Web 工程 `Resource`→`Recycle` rename。
- 复用或替换为 `UrbanAttendedWeighingWindow`（本单只对齐行为，不强制窗体类合并）。
- BasePlatform 5020 注册运维（沿用既有）。
- 持久化 SQL 表（本单接收落点沿用 XiaoShanResource 进程内 Store；正式库表另 change）。

## Decisions

1. **接收宿主选 XiaoShanResource（5041）**  
   Recycle Web 现状即该站；运输清单已在此。相对在城管 Admin 加 Recycle AppService，优先同站 API，配置 `RecyclePlatform:BaseUrl` 指向该站。  
   *备选*：UrbanManagement.HttpApi 新 AppService — 拒绝，产品边界与 5041 不一致。

2. **上传触发对齐 Urban：完成运单后异步上传**  
   本地 `Complete` 成功后发上传请求（或入队由轻量 BackgroundService 重试）；DTO 用命名 `record`（禁止 tuple）。毛重以 kg 或吨在契约中写死一种（与 Store 现有吨一致则用吨）。  
   *备选*：仅手动「上报」按钮 — 拒绝，工控应对齐 Urban 自动第一跳。

3. **表单瘦身而非删掉 RecycleModeFormView**  
   保留独立 DataTemplate，控件仅留称重类型（若仍需进/出语义）、车牌、备注（可选）；去掉供应商/材料/单价/合同。完成校验只保留车牌规范。  
   *备选*：直接复用 Urban 表单控件 — 本单不做类合并，降低耦合风险。

4. **市同步：默认 `RecycleSync:Enabled=false`，模块不再因缺省开启而注册轮询**  
   保留类型便于日后平台侧复用签名工具；客户端不得再把 §2.2 当主路径。无兼容包袱，可删除完成路径上对 `SetPendingSync` 服务市接口的依赖，改为平台上传状态。

5. **平台同步状态**  
   优先复用/新增 Recycle 侧扩展字段或本地标记（如 `RecyclePlatformSyncStatus`），不借用市平台 `IsPendingSync` 语义混用。具体属性名在实现时选最短清晰方案。

6. **接收 API 形状（草图）**  
   `POST /api/recycle/weighing/receive` body：`RecycleWeighingReceiveRequest` record（`ClientRecordId`, `PlateNo`, `GrossWeightTons`, `WeighedAt`, `PhotoNames` 或后续 multipart）。响应：`RecycleWeighingReceiveResult` record（`Ok`, `TransportId`, `NetWeightTons`, `Message`）。照片本单可先文件名/可选 multipart；完整附件管道可跟进。

## Risks / Trade-offs

- [Risk] 进程内 Store 重启丢数 → 本单为 initiative 联调基线；正式持久化另 change。  
- [Risk] 皮重缺失导致无法算净重 → 接收 API 明确失败信息；工控提示可上传但平台记失败（或拒绝），与车辆池前置一致。  
- [Risk] Attended 基类仍展示皮重/净重列 → 工控可只采毛重；皮/净显示可只读或隐藏，避免误导为工控录入皮重。  
- [Trade-off] 保留 HMAC 类型但默认关闭 → 略增死代码；换取后续平台侧复用 signer 的成本更低。

## Migration Plan

- 无生产发布包袱：**BREAKING** 直接合入 `dev-recycle-resource-alignment`。  
- 配置：`RecyclePlatform:BaseUrl` 必填于联调；`RecycleSync:Enabled` 默认 false。  
- 回滚：切回 change 前 commit（基线分支保留历史）。

## Open Questions

- 正式环境接收是否迁出 XiaoShanResource 到独立 Recycle HttpApi（命名收敛后）——本单不阻塞，接口路径保持 `/api/recycle/...` 便于搬家。  
- 照片是否本单就上 multipart/tus —— 若工期紧，先 JSON 元数据 + 后续附件 change。
