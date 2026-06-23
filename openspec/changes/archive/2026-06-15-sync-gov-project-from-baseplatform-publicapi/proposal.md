## Why

UrbanManagement 需要持续获得 BasePlatform 的项目主数据（`ProId`、`ProName`）以支撑后续政府同步与项目管理，但当前缺少稳定的跨系统拉取通道。随着项目规模约 1500 条，必须提供可公网访问、具备服务间授权、可周期执行且幂等的同步方案。

## What Changes

- 在 `FdSoft.BasePlatform.PublicApi` 新增受保护的项目目录查询 API，分页返回 `ProId` 与 `ProName`，支持 UrbanManagement 定时拉取。
- 为 PublicApi 增加基于 `X-Api-Key` 的服务间鉴权与 HTTPS 公网访问约束，拒绝未授权请求。
- 在 UrbanManagement 新增定时后台任务，从 PublicApi 分页拉取项目并执行“仅插入新增”的同步策略，不更新、不删除既有 `GovProject`。
- 在 UrbanManagement 引入 `BuildLicenseNo`、`FdBuildLicenseNo` 初始化提供器接口；首版使用固定常量并保留 `// TODO` 供后续实现真实映射逻辑。
- 增加同步日志与失败重试约束，确保在网络波动或接口失败时可观测且可恢复。

## Capabilities

### New Capabilities

- `baseplatform-project-catalog-api`: BasePlatform.PublicApi 对外提供带 API Key 保护的项目目录分页读取能力（`ProId`、`ProName`）。
- `gov-project-baseplatform-pull-sync`: UrbanManagement 周期拉取 BasePlatform 项目并仅插入新增 `GovProject`，包含初始化字段占位逻辑。

### Modified Capabilities

- `urban-management-crud`: 新增“外部同步导入”来源约束后，项目列表需要兼容并展示由同步任务插入的 `GovProject` 记录（不改变手工 CRUD 既有行为）。

## Impact

- **BasePlatform.PublicApi**
  - 新增项目目录查询控制器与返回 DTO。
  - 新增 API Key 鉴权中间件与配置项（`ProjectCatalogSync`）。
  - 新增公网访问安全约束（HTTPS、限流/日志建议）。
- **UrbanManagement**
  - 新增后台 Worker、拉取服务、HTTP Client 与配置模型（`BasePlatformSync`）。
  - 新增初始化接口 `IGovProjectInitFieldProvider` 与默认常量实现（含 `// TODO`）。
  - `GovProject` 导入路径新增“仅插入”规则，避免覆盖存量项目数据。
- **运维与测试**
  - 需要在两端注入一致 `ApiKey` 并配置公网地址。
  - 需新增鉴权、分页、幂等插入、1500 条数据量、异常重试等测试用例。
