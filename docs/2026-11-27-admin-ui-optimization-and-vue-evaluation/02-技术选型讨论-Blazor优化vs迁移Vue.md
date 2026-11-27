# 02 - 技术选型讨论：Blazor 优化 vs 迁移 Vue 3

知识状态：API 暴露与宿主架构事实为 `CONFIRMED`；方案优劣评估与推荐排序为 `PENDING_VALIDATION`（待 Human 决策）。生命周期：`ACTIVE`。

---

## 1. 三个备选方案定义

| 方案 | 简述 | 架构形态 |
|------|------|----------|
| **方案 A：留在 Blazor Server + 定向优化** | 不换框架，修掉已知 Bug、拆分大文件组件、补齐卡口/成品筛选与异常派单视图、清理无效外链 CDN | 保持 `UrbanManagement.Admin` Blazor Server + 手写 CSS |
| **方案 B：整体迁移至 Vue 3 + Element Plus** | 参照同仓 `UrbanManagement.Recycle`，用 Vite + Vue 3 + Element Plus 重写 Admin 前端，输出至 `UrbanManagement.Admin/wwwroot`，保留原 `Login.cshtml` 与 ABP API | `UrbanManagement.Admin` 变为「SSO Razor Login + ABP/BFF API + Vue SPA 静态托管」，移除 Blazor Server 与 `/_blazor` |
| **方案 C：先止血修复，再整体迁 Vue** | 先用极小改动修复当前影响线上/138 运维的确定性 Bug（不做大重构），待核心后端协议（心跳/日志/OTA）收口后，集中切至 Vue 3 | 短期方案 A（最小集）→ 中期方案 B |

> [!NOTE]
> **为何不推荐「在 Blazor Server 内引入 MudBlazor / AntDesign Blazor」？**
> 引入第三方 Blazor 组件库同样需要重写全部 7 个业务页和 6 个弹窗组件（改动量接近迁 Vue），但**仍无法消除** Blazor Server 的 SignalR Circuit 断连/状态丢失、服务端内存开销、以及与 `Recycle`（Vue 3）双前端栈分裂问题，属于「付出了重写成本，却只拿到一半收益」。

---

## 2. 多维度深度对比

| 评估维度 | 方案 A（留 Blazor 优化） | 方案 B（迁 Vue 3 + Element Plus） | 说明与证据 |
|----------|--------------------------|-----------------------------------|------------|
| **UI 组件能力与开发效率** | 🔴 弱：继续手写表格、日期区间、冻结列、弹窗、上传、灯箱 | 🟢 强：Element Plus 开箱即用（`el-table`、`el-date-picker`、`el-image` 预览、`el-drawer`、`el-upload`、`el-pagination`） | 当前手写 `components.css` 已 1,362 行且仍缺冻结列/日期快捷选择/原生灯箱缩放 |
| **运行时稳定性（内网/长时挂机）** | 🟠 中偏弱：锁屏/弱网/重启后 SignalR Circuit 断开丢状态 | 🟢 强：纯无状态 HTTP REST + URL Query 持久筛选，服务端重启后刷新即恢复 | 运维人员常把监控页挂在浏览器一整天，SPA 体验明显更稳 |
| **与同仓技术栈一致性** | 🔴 分裂：Admin=Blazor，Recycle=Vue 3 | 🟢 统一：Admin 与 Recycle 同为 Vue 3 + Element Plus + Vite | 降低维护心智与 AI Agent 跨项目修改成本 |
| **鉴权与部署改动** | 🟢 零改动 | 🟢 极小改动：复用 `Login.cshtml` + `UrbanAdmin.Session` Cookie，沿用单容器 `um-admin` | `UrbanManagement.Recycle` 已完整验证该部署与 Docker 流程（`Dockerfile` 第 4 行） |
| **API 改造工作量** | 🟢 零改动（进程内直调 AppService） | 🟡 小：绝大多数 Core AppService 已通过 ABP 自动暴露；仅需补 3–4 个薄端点（见 §3） | `UrbanManagementAdminModule.cs` 已调用 `ExposeCoreAppServices` |
| **前后端类型共享** | 🟢 强：直接共享 C# DTO | 🟡 中：需维护 TypeScript 类型定义（可由 Swagger/OpenAPI 生成或手写轻量 `types/*.ts`） | Admin 仅有 ~15–20 个接口，TS 类型维护成本较低 |
| **文件上传/下载与媒体交互** | 🟠 需 JS Interop（已有 `file-picker.js` 与 `eval` hack） | 🟢 原生浏览器 API（`Blob`、`fetch`、`FileReader`、`el-image` 缩放旋转） | 彻底消除 `eval` 下载与 `DotNetObjectReference` 回调复杂度 |
| **自动化观察（Pipeline / 浏览器测试）** | 🟠 需等待 Blazor Circuit 水合与 DOM 差异更新 | 🟢 标准 REST + SPA，网络请求与状态清晰可断言 | 利于 `admin-ui-layout-observe` 等 Observe Graph 稳定采证 |
| **短期改动成本（Effort）** | 🟢 **S–M**（~10万–30万 token） | 🟠 **L**（~45万–80万 token，分 3 会话） | 方案 A 见效最快，方案 B 是一次性还清技术债 |

---

## 3. 迁 Vue 的后端 API 就绪度核对（`CONFIRMED`）

经核对 `UrbanManagementAdminModule.cs` 与 `UrbanManagement.Gateway/appsettings.json`，Admin 现有页面依赖的后端能力与 HTTP 暴露现状如下：

| 业务模块 | 当前 Blazor 注入服务 | HTTP API 现状 | 迁 Vue 需补充工作 |
|----------|----------------------|---------------|-------------------|
| **会话信息** | Razor 服务端 `HttpContext.User` | 暂无 `/api/session` | 补 1 个 `GET /api/session`（参照 `Recycle` 5 行代码） |
| **项目管理 & 设备状态 & 授权** | `IGovProjectAppService`、`IDeviceStatusAppService`、`IGovProjectLicenseAppService` | **已自动暴露**（`/api/app/gov-project/*`、`/api/app/device-status/*`、`/api/app/gov-project-license/*`），均走 `Admin` 鉴权 | 无（直接调用，验证路由与序列化即可） |
| **称重记录 & 异常审批** | `IUrbanWeighingRecordAppService` | **已自动暴露**（`/api/app/urban-weighing-record/*`） | 无（审批照片提交注意请求体大小与 Base64 保持兼容） |
| **卡口 / 成品进出** | `IUrbanCheckpointPassageAppService`、`IUrbanFinishedProductPassageAppService` | **已自动暴露** | 若要补齐筛选/分页，需确认 `UrbanPassageListInputDto` 是否已支持筛选字段 |
| **客户端日志** | `IClientLogAppService`（由 `RemoteClientLogAppService` 转发至 `Realtime`） | Gateway 已映射 `/api/app/client-log/**` 与 `/api/client-log/**` → `realtime`，但**历史调研已指出 Gateway 直通 realtime 缺乏 Admin Cookie 鉴权** | **推荐**：在 `Admin` 侧暴露 `/api/admin/client-logs/*` 薄 BFF 代理（继续复用 `RemoteClientLogAppService` + `UrbanAdmin.Session` 鉴权），顺带封堵越权缺口 |
| **客户端更新（OTA）** | `IClientOtaAppService`、`IOtaPackageCatalogService` | `ClientOtaAppService` 在 `Admin` 被排除自动暴露，`OtaPackageCatalogService` 为进程内服务 | 在 `Admin` 侧补 2–3 个薄端点（`/api/admin/client-ota/catalog`、`/online-clients`、`/trigger`），复用现有 `RemoteClientOtaAppService` |
| **冗余页** | `IRecycleDeviceStatusAppService` | 已定论移除 | 直接删除，不迁移 |

**关键结论**：迁 Vue **不需要重写任何核心业务逻辑或数据库查询**，后端仅需补大约 **6–8 个极薄的 Minimal API / Endpoint 包装**（全部在 `UrbanManagement.Admin` 内完成），即可实现前后端完全解耦且鉴权闭环。

---

## 4. 容易忽略的 4 个实操风险与对策

1. **构建链引入 Node.js 依赖**：
   - 现状：`deploy/docker/Dockerfile` 已经要求先对 `UrbanManagement.Recycle/client` 执行 `npm run build`（即 CI / 打包机已具备 Node 环境）。
   - 对策：Admin 新增 `src/UrbanManagement.Admin/client/`，与 Recycle 复用同一套 `npm ci && npm run build` 打包步骤，不增加新基础设施要求。
2. **SSO Cookie 401 跳转体验**：
   - `AdminSsoAuthentication.cs:34-37` 已经对 `/api/**` 未登录请求返回 `401 Unauthorized`（而非 302 HTML）。
   - 对策：Vue 统一封装 `fetch` / API Client，遇到 `401` 自动 `window.location.href = '/login?returnUrl=...'`，避免会话过期后静默报错。
3. **Gateway 路由清理顺序**：
   - `UrbanManagement.Gateway/appsettings.json` 中存在 `/_blazor/{**rest}` 路由。
   - 对策：Vue 完整替代并稳定运行后再移除 `/_blazor` 路由和 `Volo.Abp.AspNetCore.Components.Server` 包引用，避免切换窗口期回滚困难。
4. **避免「重写顺便改业务语义」**：
   - 迁移时若同时改动未批准的业务字段或接口语义，极易引发回归。
   - 对策：严格区分「**前端框架迁移 + 确定性 UI 缺陷修复**」与「**新业务需求（如派单视图、LPR 异常原因细分）**」，按独立 OpenSpec change 推进。

---

## 5. 决策判断树（何时选哪条路）

```text
未来 6-12 个月，Admin 是否会持续新增/深化运维交互
（异常派单视图、OTA 控制台、日志排查、双产品统一筛选等）？
├── 否（仅小修小补，基本冻结功能）
│     └── 选 方案 A（留在 Blazor Server，S–M 级定向修复）
└── 是（会持续演进）
      ├── 当前是否急需先解决 138/线上 P0/P1 阻塞缺陷？
      │     ├── 是 → 选 方案 C（先 S 级止血，再开 L 级 Vue 迁移）
      │     └── 否 → 选 方案 B（直接分 3 阶段迁移 Vue 3 + Element Plus）
```
