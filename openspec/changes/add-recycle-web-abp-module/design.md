## Context

资源化网页的工程仍是 `UrbanManagement.XiaoShanResource`。`Program.cs` 是普通 `WebApplication`，注册 `ResourceMockStore`，由 `ResourceMockEndpoints` 提供 `/api/vehicles`、`/api/contracts`、`/api/productions`、`/api/transports`。工程只引用 Telemetry。SSO 会话 Cookie 为 `XiaoShanResource.Session`，只有用户标识、用户名和产品码 5041，没有项目标识。compose 服务名是 `um-xiaoshanresource`。

2026-11-16 已确认英文工程与类型统一为 Recycle。对外中文继续「萧山资源化利用网页端」，产品码 5041 不改。桌面 `MaterialClient.Recycle` 已经是规范名。

`add-recycle-business-persistence` 已在 Core 提供 `RecycleDbContext`、可信 `IRecycleProjectContext` 和各业务 AppService。Admin 与 Ingest 已是 ABP 宿主。资源化站点还不是。

## Goals / Non-Goals

**Goals:**

- 站点工程、程序集、命名空间、Cookie、DataProtection 应用名和 compose 服务名改为 Recycle。
- 让该站点以 ABP 模块启动，并解析既有 Recycle AppService。
- 登录仍走 5041 SSO。Cookie 名为 `Recycle.Session`。
- 项目归属只使用 `RecyclePersistence:BoundSourceProId`，并校验为 5020 的 `GovProject.SourceProId`。
- 四个业务接口改为调用这些服务。Vue 在同一变更里改用 Guid 和精确重量。
- 去掉内存 mock。

**Non-Goals:**

- 不改登录页、顶栏的中文产品名，不改 5041。
- 不新建表，不改 `RecycleDbContext` 与迁移。
- 不改 `MaterialClientRecycleModule`，不让 Recycle 桌面引用 Urban 工程。
- 不把资源化站点并进 Admin，不在该站点暴露 Urban 称重、授权或设备列表 API。
- 不实现市平台发送，不把批量上报标成成功。
- 不从浏览器或请求体接受 ProId。不在本 change 做 MaterialClient 上传联调。
- 不重命名已有 OpenSpec change 目录 `add-xiaoshan-resource-web`。

## Decisions

1. 工程目录、csproj、程序集和根命名空间使用 `UrbanManagement.Recycle`。模块类为 `UrbanManagementRecycleModule`，依赖 `UrbanManagementHostingModule`。这与桌面 `MaterialClient.Recycle` 成对，也和已确认的英文名一致。示例名 `UrbanManagement.XiaoShanRecycle` 不再使用，避免英文标识里继续留下 Resource 的过渡拼法。
   备选是先在 `XiaoShanResource` 上接 ABP，以后再改名。那样会把旧名写进新模块、Cookie 和镜像，不采用。

2. Cookie 名改为 `Recycle.Session`，认证方案改为 `Recycle`，DataProtection 应用名改为 `UrbanManagement.Recycle`。compose 服务改为 `um-recycle`，镜像改为 `urbanmanagement-recycle`。对外端口仍由环境变量给出，默认保持 5334；变量名改为 `UM_RECYCLE_PUBLIC_PORT`。已有浏览器会话失效后重新登录。中文页面文案不动。

3. `Program.cs` 改为该模块的 ABP 启动，保留现有 Razor Pages、静态文件、健康检查、登录和登出。
   备选是在普通 WebApplication 里手写 Autofac 注册。那样会复制宿主已经做过的 DbContext 与工作单元配置，不采用。

4. 该模块不调用 `ExposeCoreAppServices`。Vue 继续请求本站 `/api/vehicles`、`/api/contracts`、`/api/productions`、`/api/transports`。这些端点只做认证后的适配，并调用对应 AppService。这样不会把 Admin 的全部 conventional API 挂到资源化站点。
   备选是让 Vue 改打 `/api/app/recycle-*`。那会把 Core 的管理面暴露到这个站点，不采用。

5. 适配层不读取请求里的项目字段。`IRecycleProjectContext.RequireSourceProIdAsync` 只看 `RecyclePersistence:BoundSourceProId`。未配置、找不到 5020 `SourceProId`，或值等于派生 `GovProject.Id` 时，按既有 `RECYCLE:PROJECT_UNBOUND` / `RECYCLE:PROJECT_ID_MIXED` 失败。配置值由部署填写，不写进提交的示例秘密。

6. 页面重量使用服务返回的精确吨字段。输入控件不得固定一位小数。整数 mock id 改为 Guid。车辆皮重修改不得回写已有运输清单快照，该行为由既有实体方法保证，适配层不得另写一份更新。

7. `ResourceMockStore` 与 `ResourceMockEndpoints` 删除。没有真实外部响应时，适配层不得调用会把同步状态写成成功的方法。

## Risks / Trade-offs

- [改 Cookie 和 DataProtection 应用名使旧会话失效] → 这是实验室站点的重新登录。不保留双 Cookie 名称。
- [compose 服务名变化] → 发布时替换服务定义。默认宿主机端口仍是 5334。
- [站点在持久化迁移未应用时启动] → 部署顺序是先完成 `add-recycle-business-persistence` 的迁移，再切换本宿主。启动失败时保持旧进程，不在本 change 里自动建表。
- [配置了错误的 SourceProId] → 失败关闭，列表和写入都拒绝，不用空 Guid 或 Urban 项目顶上。
- [Vue 与接口同时改形状] → 同一 change 内改页面。站点外没有这个 mock 的调用方。
- [ABP 管道改变现有 SSO 顺序] → 登录、会话中间件和 `/logout` 保持在业务端点之前；未登录访问业务接口返回 401，不创建数据。

## Migration Plan

1. 确认目标库已有 Recycle 表和一条 5020 `GovProject.SourceProId`。
2. 将工程重命名为 `UrbanManagement.Recycle` 并改为 ABP 启动。
3. 为该站点配置 `ConnectionStrings:Default` 与 `RecyclePersistence:BoundSourceProId`。
4. 发布新镜像 `urbanmanagement-recycle`，compose 使用 `um-recycle`。宿主机端口默认仍为 5334。
5. 回退时恢复上一版站点程序和 compose 服务名。已写入的 Recycle 行保留，不随程序回退删除。

## Open Questions

无。具体绑定哪个 SourceProId 由部署环境决定，本设计不冻结某个项目值。
