# UrbanManagement.Recycle 实现描述

知识状态：INFERRED（职责与两跳上传已 CONFIRMED；工程切分与表结构仍 PENDING_VALIDATION）。

## 目标名称

英文统一为 **Recycle** 后，我方平台上的资源化能力统称 **UrbanManagement.Recycle**（与桌面 `MaterialClient.Recycle` 成对）。

| 层 | 现状 | 目标（CONFIRMED 方向） |
|----|------|------------------------|
| Web 站点工程 | `UrbanManagement.XiaoShanResource` | 收敛到 Recycle 系名称（示例 `UrbanManagement.XiaoShanRecycle` / 解决方案内 Recycle Web 项目，最终名以 OpenSpec 为准） |
| 产品中文名 | 萧山资源化利用网页端 | 不变 |
| Web ProductCode | 5041 | 不变 |
| 桌面 ProductCode | 5020 | 不变 |
| Cookie / compose | `XiaoShanResource.Session`、`um-xiaoshanresource` | 随 rename change 改为 Recycle 系 |

下文用 **UrbanManagement.Recycle** 指「资源化在 UrbanManagement 仓库内的我方平台能力」；未 rename 前，已落地的 Web 代码仍在 `XiaoShanResource` 路径。

## 在整条链路上的位置

```text
MaterialClient.Recycle          UrbanManagement.Recycle              杭州市资源化利用厂
（采集：重量/车牌/照片）  ──①──►  （接收、落库、Web 表单、组装）  ──②──►  接口 V1.0
```

1. 工控只打我方平台。
2. 市平台只由我方平台调用（Worker / 同步服务），文档见 [`docs/SyncDoc/杭州市资源化利用厂数据接入接口V1.0.md`](../SyncDoc/杭州市资源化利用厂数据接入接口V1.0.md)。

对照城管：`MaterialClient.Urban` → UrbanManagement（Ingest/Attachment/Admin 等）→ 后续政务通道；Recycle 同构，但业务与产品码独立，且第二跳目标是市资源化接口。

## 能力拆分（目标形态）

### A. Web 页面职责（承接原客户端表单）

| 页面 | 职责 |
|------|------|
| 车辆管理 | **车辆信息池**（非业务主数据）：预录车牌/皮重等，供算净重 |
| 合同管理 | 合同目录与附件；可批量上报 §2.4 |
| **生产管理** | **日产量**（§2.5）；非工控过磅落点；见 [`05-生产管理与运输清单页面.md`](05-生产管理与运输清单页面.md) |
| **运输清单** | **工控上传落点**；补全合同号/产品/收货凭据；产品净重由平台计算（§2.2） |

- 当前 mock 站点范围见 [`docs/2026-11-13-xiaoshan-resource-utilization/`](../2026-11-13-xiaoshan-resource-utilization/00-调研总览.md)。
- 技术选型保持 Vue 3 + Element Plus；登录 SSO ProductCode 5041。
- 四页 × 市接口 V1.0 字段级闭环见 [`04-业务闭环.md`](04-业务闭环.md)。

### B. 工控上传接收（对齐 Urban `receive`）

- 提供 Recycle 专用接收 API（路径/DTO 另定），供 `MaterialClient.Recycle` 上传**毛重**、车牌与现场附件元数据。
- 接收后：车牌命中车辆池 → 算净重 → **写入运输清单记录**（业务明细待 Web 补）。
- **不**要求工控带齐合同号/材料/供应商/收货凭据。
- 网关路由：可为 Recycle 增加独立前缀；是否共用 `um-ingest` **PENDING_VALIDATION**。

### C. 第二跳：市平台同步

- Worker 读取运输清单中已落库、且明细已补齐（或达到可报门槛）的记录，组装 §2.2；生产管理日产量另报 §2.5（章节集合 PENDING_VALIDATION）。
- HMAC / 厂标识等密钥只留在我方平台配置，不进工控安装包主路径。
- 失败重试、冷却、对账状态落在我方库；Web 运输清单 / 生产管理可查看。

### D. 与城管栈的边界

| 项 | 要求 |
|----|------|
| `UrbanManagement.Admin`（5040） | 不改菜单/Cookie；Recycle Web 独立站点 |
| 城管称重 / 卡口 API | Recycle 不复用为资源化业务入口 |
| `UrbanManagement.Core` | 若共享内核实体须明确边界；资源化主数据默认不塞进城管 Admin 页面 |
| 产品码 | 桌面 5020、Web 5041、城管桌面 5001 / 管理端 5040 并存 |

## 建议的仓库落点（INFERRED）

与现有 UrbanManagement「一服务一项目」一致，Recycle 侧可演进为：

| 职责 | 候选落点 | 说明 |
|------|----------|------|
| Web UI + SSO Cookie | 现 `XiaoShanResource` → rename 为 Recycle Web | 已有 Vue 壳与 5041 登录 |
| 工控接收 API | 独立 Recycle Ingest 服务，或在现有 Ingest 内用 Recycle 谓词暴露 | 勿与城管 receive 混路由 |
| 附件 | 复用 Attachment 或 Recycle 专用上传 | 对齐 Urban tus/multipart 经验 |
| 市平台同步 | Worker 内 Recycle 同步，或 Recycle Worker | 只持有市平台密钥 |
| 持久化 | **独立建表**（可与城管同库） | 见下方「是否独立建表」 |

具体是否新建 `UrbanManagement.Recycle*` 多个 csproj，还是先扩 `XiaoShanResource` + Worker，须在 OpenSpec `design.md` 拍板。

## 是否独立建表（ADOPTED）

2026-11-16 Human **采纳独立建表**。资源化业务表不复用城管的 `GovProjects` / 称重接收 / 卡口等表作为主存。业务对象与市接口映射见 [`04-业务闭环.md`](04-业务闭环.md)。

| 做法 | 结论 |
|------|------|
| 车辆信息池（皮重）、合同目录、日产量（生产管理）、**运输清单**（毛/皮/净 + Web 补全）、市平台同步状态 | 使用 Recycle 自己的表（逻辑 `{Related}Id`，无数据库外键） |
| 与城管是否同一 SQL Server / 同一 Database | 可以同库；「独立」指**表与模型归属**，不是必须再开一台库 |
| 附件文件目录 | 可复用现有 Uploads 类基础设施，用路径/业务 Id 区分；元数据仍归 Recycle 表 |
| 继续只用 XiaoShanResource 进程内存 mock | 不够：两跳上传与 Web 管理需要可持久化、可重试的数据 |

依据：产品码与城管分离（5020/5041 vs 5001/5040）；第二跳字段与城管通道不同；客户端 Topic 要求主数据与采集记录落在我方 Recycle 平台。具体表名、是否独立 DbContext / migration 程序集，仍 PENDING_VALIDATION。讨论记录在 [`docs/2026-11-18-recycle-web-table-design/`](../2026-11-18-recycle-web-table-design/00-调研总览.md)，定稿进入 OpenSpec `design.md`。

## 与客户端重构的接口契约（待开 change 细化）

工控上传包应至少能表达：

- 现场：车牌、**毛重**、称重时间、现场照片/附件引用（见 [`04-业务闭环.md`](04-业务闭环.md)）。
- 身份：项目/授权侧所需的 Recycle 接入标识（对齐 Urban AccessCode 一类字段，具体名 PENDING）。
- **不应**强制：合同号、材料、供应商、收货凭据、皮重、净重。

平台接收后：

1. 车牌命中 **车辆信息池** → 取 **皮重**。
2. **净重 = 毛重 − 皮重** → 创建/更新 **运输清单** 记录（重量齐，明细待补）。
3. Web 在运输清单补全合同号、产品、收货凭据等后，Worker 组装 §2.2（必填 `netWeight` + 可选毛/皮 + 补全字段）。

## 实施切片（非 tasks 勾选）

1. Rename / 正名：`Resource` → `Recycle`（Web 工程、Cookie、compose）。
2. 主数据从 mock 到可管理持久化（车辆、合同等）。
3. 工控接收 API + 网关路由 + 客户端改打第一跳。
4. Worker 对接杭州市接口 V1.0 第二跳。
5. Web 可查看上传与市同步状态（可后置）。

进入代码前须 OpenSpec change + Human `APPROVED`。
