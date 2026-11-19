## Why

`add-recycle-business-persistence` 已把 Recycle 业务模型和 AppService 放在 UrbanManagement.Core，但资源化网页仍是 `UrbanManagement.XiaoShanResource`：普通 WebApplication、内存 mock，也无法绑定可信的 5020 SourceProId。英文工程名已定为 Recycle，接入 ABP 时继续沿用 Resource 会把旧名称写进新模块。

## What Changes

- 将站点工程、程序集、命名空间和目录从 `UrbanManagement.XiaoShanResource` 改为 `UrbanManagement.Recycle`。ABP 模块名为 `UrbanManagementRecycleModule`。
- 会话 Cookie 从 `XiaoShanResource.Session` 改为 `Recycle.Session`，认证方案改为 `Recycle`，DataProtection 应用名改为 `UrbanManagement.Recycle`。compose 服务 `um-xiaoshanresource` 与镜像 `urbanmanagement-xiaoshanresource` 改为 `um-recycle` 与 `urbanmanagement-recycle`。**BREAKING**：已登录浏览器需要重新登录。对外中文仍是「萧山资源化利用网页端」，产品码仍是 5041。
- 该宿主依赖共享 UrbanManagement 宿主模块，使 Recycle 材料、公司、车辆、合同、日产量、运输清单和附件服务可在该站点解析。
- 可信项目只来自服务端配置 `RecyclePersistence:BoundSourceProId`，并经 5020 `GovProject.SourceProId` 校验。请求体中的项目标识不得作为归属。
- 用上述 AppService 替换 `/api/vehicles`、`/api/contracts`、`/api/productions`、`/api/transports` 的内存实现。页面继续只显示业务名词和操作。重量按持久化规则精确换算，页面不得把公斤四舍五入成一位小数吨。
- **BREAKING** 仅限本站 mock JSON：整数 id 与内存字段改为 Guid 与持久化 DTO。调用方只有本站 Vue，在同一 change 内改接。
- 不新建表、不改 `RecycleDbContext`、不实现市平台发送，也不改 MaterialClient 的 `MaterialClientRecycleModule`。已有 change 目录名 `add-xiaoshan-resource-web` 保持不动。

## Capabilities

### New Capabilities

- `recycle-web-abp-host`: 资源化站点以 `UrbanManagement.Recycle` 作为 ABP 宿主解析 Recycle AppService，并只接受服务端绑定的 5020 SourceProId。
- `recycle-web-persistence-api`: 车辆、合同、日产量、运输清单页面改为调用真实 AppService，重启后数据仍在。

### Modified Capabilities

无。`recycle-abp-module` 仍是 MaterialClient.Recycle 桌面模块，本 change 不改其需求。

## Impact

- 实现仓：`repos/UrbanManagement`（现 `src/UrbanManagement.XiaoShanResource`、解决方案、`deploy/docker`、子仓 `AGENTS.md` 中的工程名）。Core 的 Recycle 模型与 AppService 只消费，不重做。
- 前置：`add-recycle-business-persistence` 已合入 `dev-recycle-resource-alignment`。Mode B：Apply 时从该基线创建同名分支，squash 回 initiative。本提案不授权提交或推送。
- 不包含：MaterialClient 上传联调、第二跳市平台 Worker、Admin 设备页（已在持久化 change 落地）、BasePlatform、对外中文和产品码变更、历史 OpenSpec change 目录改名。
