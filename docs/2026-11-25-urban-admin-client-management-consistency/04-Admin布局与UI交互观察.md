# 04 - Admin 布局与 UI 交互观察

知识状态：138 实验室表面事实相对 Run `2026-11-25T101234` 为 `CONFIRMED`（观察）；U1/U2/U3/U4 根因经源码核对为 `CONFIRMED`；U5 体验改进方向与导航调整为 `PENDING_VALIDATION`。生命周期：`ACTIVE`。

> [!NOTE]
> 本文档原独立存放于 `docs/2026-11-25-admin-ui-layout-interaction/`，已合并归口至本 Topic，以便与客户端运维一致性缺陷统一编号、统一拆包，避免重复处理。

---

## 1. 证据来源（Run identity）

| 字段 | 值 |
|------|----|
| `graphId` | `admin-ui-layout-observe` |
| `graphPath` | `pipelines/graphs/urban/admin-ui-layout-observe` |
| `runId` | `2026-11-25T101234` |
| `result` | `pass`（P0–P2 采证；P3 仅用户判定，不代表产品通过） |
| 观察环境 | Admin `http://192.168.3.138:5333`；SSO `http://192.168.3.135:8500`；产品码 **5040**；账号 `13612345678`（口令不写入文档） |
| 布局源码 | `repos/UrbanManagement/src/UrbanManagement.Admin/Pages/AdminLayout.razor` |

> [!WARNING]
> **证据留存与源码版本差说明**：
> - `pipelines/graphs/urban/admin-ui-layout-observe/runs/` 为 gitignored 本机产物，跨机器查阅时以本文档记录的摘要为准。
> - 138 实验室观察时运行的是含未归档变更 `add-admin-recycle-project-page` 的构建（侧栏 8 项，含 `/` 城管项目 + `/recycle-projects` 资源化项目）；而 `repos/UrbanManagement` 当前 `main`（`0efac93`）的 `AdminLayout.razor` 仍为 7 项（`/` 为「项目管理」，无 `/recycle-projects`）。
> - 先前账号 `13777554358` 对 5040 返回业务码 110（无项目/企业授权），未进入壳；详见 [`05-Admin登录与会话边界.md`](05-Admin登录与会话边界.md)。

---

## 2. 布局壳与业务路由表面（138 观察）

### 2.1 布局壳（`AdminLayout.razor`）

| 元素 | 观察（`CONFIRMED`） |
|------|---------------------|
| 结构 | `.layui-layout-admin`：侧栏 + 顶栏 + `main` 多标签 |
| 侧栏 8 项（138 现网序） | 城管项目、资源化项目、称重记录、卡口进出、成品进出、异常审批、客户端日志、Recycle 设备在线 |
| 顶栏 | 「刷新」「退出」 |
| 多标签 | 打开路由会增标签；非 `/` 标签可关 |
| 品牌 | 「萧山城管对接平台」；底栏「凡东科技」 |

### 2.2 业务路由表面

| path | 标题 | 观察（`CONFIRMED`） |
|------|------|---------------------|
| `/` | 城管项目 | 状态筛选（全部/在线/离线/未注册）+ 搜索 + 表；约 **128** 条；行「设备」「称重」；同步开关 |
| `/recycle-projects` | 资源化项目 | 同壳；约 **2** 条；产品列「资源化」 |
| `/weighing` | 称重记录 | 车牌 / 项目 / 时间范围；当日 **暂无数据** |
| `/checkpoint-passage` | 卡口进出 | 表头齐全；暂无数据（无筛选条与分页） |
| `/finished-product-passage` | 成品进出 | 表头齐全；暂无数据；表区横向滚动（硬编码 `min-width: 1400px`） |
| `/weighing-approval` | 异常审批 | 异常过滤下拉；暂无数据；存在侧栏与顶栏标签不同步（U1） |
| `/client-logs` | 客户端日志 | 路由可进（本 Run 仅确认加载，未点检内部拉取流程） |
| `/recycle/device-status` | Recycle 设备在线 | 始终为空列表（`MaterialClient` 未调用独立心跳接口） |

### 2.3 本次观察盲区（显式记录）

- `/client-logs` 仅确认路由可进入，未覆盖筛选与拉取交互（相关缺陷已在 [`02-缺陷清单与根因诊断.md`](02-缺陷清单与根因诊断.md) §2 通过源码核对补全）。
- 分页翻页与只读详情/照片对话框（`WeighingPhotoDialog`、`PassagePhotoDialog`）因当日业务数据为空未执行点检。
- U4（表区横向滚动）未记录观察时的具体浏览器视口宽高（源码已确认为 `min-width: 1400px` 硬编码导致常规屏必现）。

---

## 3. UI 评审项与统一缺陷编号映射

所有 UI 缺陷已统一并入 [`02-缺陷清单与根因诊断.md`](02-缺陷清单与根因诊断.md) §6，避免多处维护：

| 原编号 | 统一编号 | 性质 | 现象与根因摘要 | 建议方向（非 SHALL） |
|--------|----------|------|----------------|----------------------|
| **U1** | `P1-13` | 确定性 Bug（`CONFIRMED`） | 侧栏高亮「异常审批」，顶栏标签却命中「称重记录」；根因为 `AdminLayout.razor:133-135` 无路径边界 `StartsWith("/weighing")` | 先精确匹配，再按 `n.Route + "/"` 段前缀匹配 |
| **U3** | `P1-14` | 确定性 Bug（`CONFIRMED`） | `document.title` 永远是 `UrbanManagement - 设备监控`；根因为 `_Host.cshtml` 缺 `HeadOutlet` 且 `ClientLogs.razor` 漏 `<PageTitle>` | `_Host.cshtml` 补 `HeadOutlet`，`ClientLogs.razor` 补 `<PageTitle>` |
| — | `P1-15` | 架构冗余（`CONFIRMED`） | `/recycle/device-status` 独立空壳与「非称重客户端维护统一」原则冲突 | 移除独立页面与并行表/服务，统一走 `DeviceStatusHub` + `IDeviceStatusAppService` |
| **U2** | `P2-5` | 无障碍语义缺陷（`CONFIRMED`） | 3 个业务页分页非当前页渲染 `aria-current="false"` | 非当前页改为 `null`（不渲染该属性） |
| **U4** | `P2-6` | 体验项（`CONFIRMED`） | 通行类表硬编码 `style="min-width: 1400px;"` 导致常规屏横滚 | 移除 `1400px` 硬编码，优化列宽/粘性操作列 |
| **U5** | `P2-7` | 体验项（`INFERRED`） | 称重/审批默认今日空表仅显示「暂无数据」 | 空态文案提示「当日暂无数据，可调整时间范围」或调整默认区间 |
| **U6** | — | 正面结论 | 壳整体清晰、卡片列表模式统一 | 保持现状，增量页不另起视觉体系 |

---

## 4. 导航与产品边界结论（Admin 统一运维原则）

针对「是否需要拆出 Urban / Recycle 两个平行 Root Nav」及双产品在 Admin 中的边界评审结论（2026-11-25 确认）：

- **核心原则**：**在 Admin（运维视角）中，Urban（5001）与 Recycle（5020）的功能几乎完全一致——除了各自出站上传的第三方平台不同**。非称重业务上的客户端管理维护必须统一，不维护两套并行的在线/设备/日志/更新系统。
- **能力一致性对照**：
  - **完全统一（一套页面 + 一套服务，按产品 5001/5020 筛选区分）**：项目管理、客户端在线状态、设备详情弹窗、称重记录提交与照片（含海康 LPR 双图）、称重异常查看、客户端日志（`/client-logs`）、2.0 推送更新（Velopack 私有源）。
  - **唯一核心差异**：出站同步/上报的**第三方平台**不同（城管对接城管平台 vs 资源化对接资源化平台）。
  - **消费面隔离**：Recycle 保留与 Urban 一致的称重异常设计，但该设计对 **Recycle Web（5334）** 无业务意义（不展示、不耦合进资源化业务流程），仅面向 Admin 运维人员查看称重提交情况；资源化纯业务操作留在 Recycle Web（5334）。
- **导航收敛**：
  - **不拆两个平行的 Urban / Recycle Root Nav**，避免把同一套运维能力按产品复制成两份；
  - **移除**独立的 `/recycle/device-status` 页面及 `RecycleDeviceStatus` 并行空壳。

---

## 5. 与 Pipeline / OpenSpec 的关系

- Pipeline P0–P2 仅为采证级别；P3 仅由用户判定。
- 复测走同一 Graph：`/run-pipeline urban/admin-ui-layout-observe`。
- 正式口 `191.12.234.212:5233` 观感与 Recycle Web `5334` 不在本观察范围内。
- 所有产品改动须经 Human `APPROVED` 并走主仓库 OpenSpec 流程。
