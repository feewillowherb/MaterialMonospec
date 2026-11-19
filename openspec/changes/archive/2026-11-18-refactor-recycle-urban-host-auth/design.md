## Context

Topic [`docs/2026-11-16-materialclient-recycle-resource-alignment/`](../../docs/2026-11-16-materialclient-recycle-resource-alignment/00-调研总览.md) 已确认：Urban(5001) 与 Recycle(5020) 并存；Admin 共管项目授权；Recycle 工控按 Urban 宿主重做；激活绑机器码对齐 PublicApi `ActivateUrban`；BasePlatform 管理端 UI 不改。PublicApi 源码现状只认 5001。Mode B 基线 `dev-recycle-resource-alignment`。

## Goals / Non-Goals

**Goals:**

- PublicApi / 发码 / JWT 对 5020 与 5001 同形（码 + MachineCode → 回写 → JWT）。
- Admin 拉取与列表同时保留 5001 与 5020，不互斥。
- Recycle 客户端：激活码-only 启动 + Urban 同构称重壳；上传仍打 Recycle Web（承接既有 receive）。
- 无兼容性包袱：可破坏现有 Recycle 启动链。

**Non-Goals:**

- Admin 观察 Recycle 同步状态（以后）。
- BasePlatform 项目授权页 UI 改版。
- 市平台 Worker 第二跳。
- 引用 `MaterialClient.Urban` 工程或发布 Urban exe。
- 改写城管称重业务页行为。

## Decisions

1. **PublicApi 扩展现有 `ActivateUrban` 放行 5020**（优先），而非新路由。  
   - 备选：`ActivateRecycle` 专用路由 — 客户端与代理要多一套；拒绝以减少分叉。  
   - `LicenseFileAppService` / `ValidateUrbanProductCode` 同步允许 5020。

2. **`SendAuthLicense`：5020 与 5001 同形载荷（含 AccessCode）**。管理端 UI 不改。

3. **Admin 项目模型：`ProId` + `ProductCode` 区分授权行**。  
   - 现状 `GovProject.Id = ProId` 且拉取丢弃非 5001。  
   - 决策：存 ProductCode；唯一性按 (ProId, ProductCode)。若短期难改主键，可用并列实体或复合键迁移；实现时选对城管冲击最小的方案（优先给 `GovProject` 增加 `ProductCode` + 调整主键/唯一约束）。  
   - 列表展示产品列；Recycle 行无「称重」进城管页。

4. **Recycle 宿主：复制 Urban 壳模式到 `MaterialClient.Recycle`**（独立 Window/VM），去掉对 `AttendedWeighing` 主窗依赖。保留 Common.Recycle 采集实体与平台上传服务；设备/诊断 MinimalWebHost 继续。

5. **客户端激活：经 UrbanManagement 或直连 PublicApi 的代理**，与 Urban 一致优先「经平台再转 PublicApi」，避免工控直连密钥面扩大。若既有 Urban 走 Ingest `urban/auth/activate`，Recycle 增加等价 5020 代理或共用校验改产品码。

6. **Mode B**：各仓分支 `refactor-recycle-urban-host-auth` ← `dev-recycle-resource-alignment`；squash 回 `dev-*`。

## Risks / Trade-offs

- [GovProject 主键与并存] → 迁移设计不当会冲掉城管行；须有 (ProId, ProductCode) 测试与回滚说明。  
- [ActivateUrban 名含 Urban] → 扩展 5020 语义略糊；文档与注释标明「城管/资源化在线激活」；Open Question 若坚持专用路由可再拆。  
- [Recycle 壳工作量大] → 先主路径：激活 + 称重区 + 列表上传；城管页签不照搬。  
- [与 `refactor-recycle-client-capture-upload` 重叠] → 本单接管宿主/授权；采集上传 API 不重复推翻。

## Migration Plan

1. BasePlatform：产品库确认 5020；发码载荷与 PublicApi 放行后部署 PublicApi。  
2. UrbanManagement：迁移 GovProject 产品维度；Admin 列表可见 5020。  
3. MaterialClient.Recycle：切换宿主与激活；废弃 Attended 主窗路径。  
4. 回滚：PublicApi 可再收窄为仅 5001；客户端回退需保留旧包（无兼容要求，现场以新包为准）。

## Open Questions

- PublicApi 最终扩展 `ActivateUrban` 还是新增同形路由（默认扩展）。  
- `GovProject` 复合唯一键的具体 EF 迁移形态（同表加列 vs 旁表）。
