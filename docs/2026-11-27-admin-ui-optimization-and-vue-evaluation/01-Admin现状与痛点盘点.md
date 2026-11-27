# 01 - Admin 现状与痛点盘点

知识状态：源码体量、依赖关系、JS Interop、API 暴露与运行架构为 `CONFIRMED`（基于 `repos/UrbanManagement/src/UrbanManagement.Admin`、`UrbanManagement.Recycle`、`UrbanManagement.Gateway` 当前源码核对）；用户体验归纳为 `INFERRED`。生命周期：`ACTIVE`。

---

## 1. 当前技术栈与架构形态（`CONFIRMED`）

| 维度 | `UrbanManagement.Admin`（现状） | `UrbanManagement.Recycle`（同仓对照） |
|------|--------------------------------|--------------------------------------|
| **前端框架** | Blazor Server（`Volo.Abp.AspNetCore.Components.Server`） | Vue 3.5.22 + `vue-router` 4.6.3 |
| **UI 组件库** | **无组件库**（纯手写类 Layui HTML + CSS） | Element Plus 2.11.7 |
| **构建工具** | 无前端构建链（直接托管 `wwwroot/` + Razor 编译） | Vite 7.1.12（`outDir: '../wwwroot'`） |
| **样式体量** | `tokens.css`(165) + `components.css`(1362) + `admin.css`(436) + `site.css`(34) ≈ **1,997 行自维护 CSS** | `styles.css`(376 行) + Element Plus 主题 |
| **登录鉴权** | `Login.cshtml`（Razor Page）+ HttpOnly Cookie `UrbanAdmin.Session` | `Login.cshtml`（Razor Page）+ HttpOnly Cookie `UrbanRecycle.Session` |
| **实时连接** | 强依赖 `/_blazor` SignalR Circuit（UI 渲染链路）；**无业务 SignalR 推送** | 无长连接，纯 HTTP REST |
| **Gateway 路由** | `/_blazor/{**rest}`、`/api/{**rest}`、fallback `/{**rest}` → `um-admin` | 独立端口/宿主（5334） |

---

## 2. 页面与组件资产清单（`CONFIRMED`）

`repos/UrbanManagement/src/UrbanManagement.Admin` 当前页面与组件实测行数如下：

### 2.1 布局壳与登录

| 文件 | 行数 | 职责与现状 |
|------|------|------------|
| `Pages/_Host.cshtml` | 25 | Blazor Server 宿主壳；缺 `<HeadOutlet>`；**残留外链 CDN `https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js`**（源码中已无页面调用 ECharts） |
| `Pages/AdminLayout.razor` | 184 | 固定侧栏（9 项）+ 顶栏（刷新/退出）+ 顶部多标签页 |
| `Pages/Login.cshtml` + `.cs` | 179 | SSO 登录页 + 进程内存验证码，与 `Recycle` 高度同构 |

### 2.2 业务页面（共 8 个文件，实际有效 7 个）

| 路由 | 文件 | 行数 | 调用后端服务 | 关键特征 / 现状问题 |
|------|------|------|--------------|---------------------|
| `/`、`/projects`、`/recycle-projects` | `ProjectManagement.razor` | 774 | `IGovProjectAppService`、`IDeviceStatusAppService`、`IGovProjectLicenseAppService` | 含项目表、状态筛选、同步开关、设备弹窗、授权生成；**使用 `JsRuntime.InvokeVoidAsync("eval", ...)` 下载授权文件**；分页 `aria-current="false"`；`OpenDeviceModal` 误传 `project.Id` |
| `/weighing` | `WeighingRecord.razor` | 627 | `IUrbanWeighingRecordAppService`、`IGovProjectAppService`、`IPageFilterStateStore` | 筛选条 + 表格 + 照片弹窗 + 重置同步；依赖进程内 `IPageFilterStateStore` 暂存筛选态；分页 `aria-current="false"` |
| `/weighing-approval` | `WeighingApproval.razor` | 878 | `IUrbanWeighingRecordAppService`、`IGovProjectAppService`、`IPageFilterStateStore` | **最重单页（878 行）**：异常筛选 + 审批弹窗 + 附件查看 + LPR/称重照片预览与替换；受 U1 路由前缀 Bug 影响 |
| `/checkpoint-passage` | `CheckpointPassage.razor` | 180 | `IUrbanCheckpointPassageAppService` | 仅固定拉取 50 条，无筛选条与分页；硬编码 `min-width: 1400px` 触发横向滚动 |
| `/finished-product-passage` | `FinishedProductPassage.razor` | 180 | `IUrbanFinishedProductPassageAppService` | 与卡口进出几乎完全重复，同样无筛选/分页且有 `1400px` 横滚 |
| `/client-logs` | `ClientLogs.razor` | 799 | `IClientLogAppService`（经 `RemoteClientLogAppService` 转发 Realtime） | 在线客户端列表、远程目录浏览、按日期/勾选拉取、缓存下载（`downloadBatchZip` JS Interop）；漏 `<PageTitle>`；拉取提示被瞬间清空 |
| `/client-updates` | `ClientUpdates.razor` | 370 | `IClientOtaAppService`（转发 Realtime）、`IOtaPackageCatalogService` | 展示本地 OTA 包目录与在线客户端，触发推送更新 |
| `/recycle/device-status` | `RecycleDeviceStatus.razor` | 46 | `IRecycleDeviceStatusAppService` | **已定论移除的冗余空壳**（客户端未接入独立心跳） |

### 2.3 公共组件与 JS 桥接

| 文件 | 行数 | 职责 |
|------|------|------|
| `Pages/Components/WeighingPhotoPreview.razor` | 288 | 称重/LPR 照片预览与本地选图替换；重度依赖 `wwwroot/js/file-picker.js`（71 行）做 `DotNetObjectReference` 回调 |
| `Pages/Components/WeighingPhotoDialog.razor` | 124 | 称重照片弹窗 |
| `Pages/Components/PassagePhotoDialog.razor` | 48 | 通行照片弹窗 |
| `Pages/Components/MultiImageGallery.razor` | 70 | 多图画廊 |
| `Pages/Components/ImageLightbox.razor` | 42 | 大图灯箱 |
| `Shared/EditHistoryTimeline.razor` | 79 | 修改历史时间线 |
| `wwwroot/js/site.js` / `echarts-init.js` | 192 | 批量 ZIP 下载等工具函数 + 已废弃的 ECharts 初始化脚本 |

**合计**：Razor 页面与组件约 **4,300 行**（不含 CSS 与 SSO），体量属于**中小规模后台管理系统**。

---

## 3. 核心痛点归类

### 3.1 Blazor Server 运行时与工程痛点（框架层）

1. **无组件库导致的手写 UI 债（最痛）**：
   - `components.css` 已膨胀至 1,362 行，所有表格、弹窗、分页、按钮、徽章、时间线、图片灯箱、文件选择都要手写 HTML/CSS/状态逻辑。
   - 浏览器原生文件选择/下载能力在 Blazor Server 下受 SignalR 消息体积与 DOM 隔阂限制，被迫写 `file-picker.js` 桥接，甚至在 `ProjectManagement.razor:752` 出现 `InvokeVoidAsync("eval", ...)` 这样的反模式。
2. **SignalR Circuit 带来的运维与体验脆弱性**：
   - 每次点击、输入、弹窗开关都依赖 `/_blazor` WebSocket 往返；网络抖动、笔记本休眠、标签页切后台时间稍长即触发断连重连，Circuit 丢失后页面状态（含未提交审批弹窗、`IPageFilterStateStore` 筛选条件、已打开的多标签页）全部重置。
   - 服务端为每个在线标签页维持内存 Circuit；未来若 `um-admin` 需要多副本部署，还必须配置 Sticky Session 或 SignalR Backplane。
3. **单文件巨型 Razor 难以维护**：
   - `WeighingApproval.razor`（878 行）、`ClientLogs.razor`（799 行）、`ProjectManagement.razor`（774 行）、`WeighingRecord.razor`（627 行）均把模板、弹窗、筛选状态、分页逻辑、业务调用混写在同一文件中，局部改动容易互相牵连。
4. **同仓双技术栈分裂**：
   - `UrbanManagement` 仓库内同时维护 **Blazor Server（Admin）** 与 **Vue 3 + Element Plus（Recycle）**，样式体系、开发调试方式、构建流程、AI Agent 修改效率均被割裂。

### 3.2 产品与交互体验痛点（与框架无关，无论迁不迁都要改）

1. **确定性前端 Bug 尚未清零**（详见 `2026-11-25-urban-admin-client-management-consistency/04-Admin布局与UI交互观察.md`）：
   - `U1/P1-13`：`AdminLayout.razor:135-137` 无边界 `StartsWith` 导致 `/weighing-approval` 误命中「称重记录」标签。
   - `U3/P1-14`：`_Host.cshtml` 缺 `HeadOutlet`、`ClientLogs.razor` 漏 `<PageTitle>`，`document.title` 恒定不变。
   - `U2/P2-5`：3 个主页面分页按钮错误输出 `aria-current="false"`。
   - `U4/P2-6`：通行表硬编码 `min-width: 1400px` 导致常规分辨率横向滚动。
   - 外链隐患：`_Host.cshtml:19` 加载外网 `cdn.jsdelivr.net` 的 ECharts（但页面已不再使用），在内网或弱网环境下会拖慢首屏加载甚至超时。
2. **导航与信息架构待收敛**：
   - 侧栏仍有已定论下线的 `/recycle/device-status`。
   - 城管项目（`/`）与资源化项目（`/recycle-projects`）本质复用同一个 `ProjectManagement.razor`，仅按产品码过滤；顶部 Logo 仍写死「萧山城管对接平台」，与双产品统一运维定位略有偏差。
   - 卡口进出与成品进出缺少筛选条、时间范围、分页与搜索，固定只拉 50 条。
3. **运维核心场景体验不足**：
   - 缺少「**仅看异常客户端**（掉线超时 / 在线但外设异常 / 频繁重启）」的运维派单视角。
   - 称重与审批页默认今日为空时仅显示「暂无数据」，缺乏日期快捷切换（今日/近 3 天/近 7 天）与空态引导。
   - 列表页刷新或跨页跳转时筛选状态未同步到 URL Query（部分依赖内存 `IPageFilterStateStore`），无法复制链接分享给同事排查同一批数据。
