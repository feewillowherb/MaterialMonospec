## Context

UrbanManagement 需要以定时任务方式从 BasePlatform.PublicApi 拉取项目主数据（`ProId`、`ProName`），用于补齐本地 `GovProject`。当前缺口在于：

- BasePlatform.PublicApi 尚无面向服务间拉取的项目目录 API。
- 两系统间缺少统一的服务间授权机制，且目标场景要求公网可访问。
- UrbanManagement 侧需要在约 1500 条数据规模下实现幂等同步，并且遵循“仅插入新增、不覆盖存量”的业务约束。
- 新导入项目的 `BuildLicenseNo`、`FdBuildLicenseNo` 当前没有可用来源，需先用固定值占位并保留可扩展接口。

该变更跨越两个代码库与部署域，涉及 API 暴露、安全、后台任务、数据导入策略与运维配置，因此需要独立设计文档统一约束。

## Goals / Non-Goals

**Goals:**

- 在 BasePlatform.PublicApi 提供可分页、可鉴权的项目目录读取能力，仅返回 `ProId` 与 `ProName`。
- 在 UrbanManagement 提供周期拉取能力，按 `ProId` 去重后仅插入新增 `GovProject`。
- 为新插入项目定义统一初始化扩展点：`IGovProjectInitFieldProvider`。
- 通过 HTTPS + API Key 完成公网服务间调用的最小可行安全闭环。
- 确保同步过程具备可观测性（成功/失败计数、异常日志、重试行为）。

**Non-Goals:**

- 不实现 `BuildLicenseNo`、`FdBuildLicenseNo` 的真实映射逻辑（首版固定常量 + `// TODO`）。
- 不处理远端项目改名、删除对本地数据的回写。
- 不改造 UrbanManagement 现有手工项目 CRUD 主流程。
- 不引入 OAuth2、mTLS 等更重认证体系。

## Decisions

### Decision 1: 服务间认证采用 API Key + HTTPS

**选择**：UrbanManagement 调用 PublicApi 时统一携带 `X-Api-Key`，PublicApi 通过专用中间件校验，并强制部署在 HTTPS。

**备选方案：**

- 复用现有授权码（Redis 一次性凭据）机制：不适合定时批量拉取。
- JWT/OAuth2：无用户上下文，复杂度偏高。
- mTLS：安全性更高但证书运维成本较高。

**理由**：首版需要低成本可落地且可运维的方案，API Key 足够覆盖服务到服务场景，并可叠加 IP 白名单与限流。

### Decision 2: PublicApi 新增独立项目目录读取接口

**选择**：新增 `ProjectCatalogController`，接口形态为 `GET /Api/ProjectCatalog/ListProjects?pageIndex=&pageSize=`，返回分页数据。

**备选方案：**

- 在现有控制器中扩展 Action：职责混杂，不利于后续治理。
- 提供全量无分页接口：不利于未来扩容与稳定性。

**理由**：独立接口边界清晰，分页可控，便于后续灰度与限流。

### Decision 3: 同步策略固定为“仅插入新增”

**选择**：以 `GovProject.Id == ProId` 作为幂等键；已存在即跳过，不做更新与删除。

**备选方案：**

- upsert（更新名称/状态）：会覆盖本地人工维护字段，风险高。
- 全量覆盖：破坏本地运营配置（如同步开关）。

**理由**：满足当前业务约束，避免污染既有项目配置；后续若需增量更新可单独提变更。

### Decision 4: 初始化字段通过接口抽象，首版常量落地

**选择**：新增 `IGovProjectInitFieldProvider`，提供 `BuildLicenseNo` / `FdBuildLicenseNo` 初始值；默认实现读配置常量并保留 `// TODO`。

**备选方案：**

- 在同步服务中硬编码常量：后续难替换，测试不便。
- 立即实现真实映射：需求信息不足，拉长交付周期。

**理由**：先交付可运行链路，同时保留低成本扩展点。

### Decision 5: UrbanManagement 使用后台 Worker + 分页拉取

**选择**：基于 ABP 周期后台任务实现（与现有 worker 模式一致），按 `pageSize` 分页拉取并汇总去重后批量插入。

**备选方案：**

- 手动触发同步接口：无法满足“定时同步”目标。
- 单页拉取 1500 条：可行但抗波动能力较差。

**理由**：周期任务符合业务诉求，分页能提升稳定性和可观测性。

## Risks / Trade-offs

- **[ApiKey 泄露风险]** → 使用 HTTPS、密钥不入库、环境变量注入，预留密钥轮换策略。
- **[公网可达导致接口暴露面扩大]** → 接口最小化（只读 + 最小字段）、限流、可选 IP 白名单、审计日志。
- **[仅插入策略可能导致名称不一致]** → 明确为非目标，后续通过独立“名称同步”变更处理。
- **[占位常量无法直接用于真实业务对接]** → 新导入项目默认 `SyncStatus=false`，要求运营完善后再启用。
- **[跨系统故障导致同步中断]** → Worker 失败重试 + 告警；不进行部分不一致更新。

## Migration Plan

1. 在 BasePlatform.PublicApi 发布项目目录只读 API 与 API Key 中间件（默认关闭或灰度启用）。
2. 在测试环境配置 PublicApi/UrbanManagement 双端一致密钥，验证 401/200 行为与分页拉取。
3. 在 UrbanManagement 上线后台同步 Worker（先低频），首次执行全量导入约 1500 条。
4. 观测二次执行结果应为零插入，确认幂等后切换到目标周期（如 60 分钟）。
5. 正式环境开启告警与审计日志，纳入运维巡检。

**Rollback:**

- 关闭 `BasePlatformSync:Enabled` 可立即停止 UrbanManagement 拉取任务。
- PublicApi 侧可关闭 `ProjectCatalogSync:Enabled` 或撤销路由映射快速止损。
- 已导入数据为新增记录，不涉及覆盖写入；回滚只需停任务，数据可后续人工处理。

## Open Questions

- PublicApi 的项目过滤条件是否需要额外状态位（除逻辑删除外）？
- `BuildLicenseNo`/`FdBuildLicenseNo` 的真实来源是 BasePlatform 扩展字段还是第三方系统？
- 是否需要管理端“手动触发一次同步”入口以配合运维排障？
