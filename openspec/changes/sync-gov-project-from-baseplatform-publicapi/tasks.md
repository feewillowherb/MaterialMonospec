## 1. BasePlatform.PublicApi 项目目录接口

- [ ] 1.1 新增 `ProjectCatalog` 读取 DTO（分页对象与项目条目对象），字段仅包含 `ProId`、`ProName`
- [ ] 1.2 新增 `ProjectCatalogController.ListProjects`，支持 `pageIndex/pageSize`、默认值与最大页大小限制
- [ ] 1.3 在查询层增加基础过滤（剔除无效 `ProId`、剔除逻辑删除项目）并保证稳定排序分页
- [ ] 1.4 统一接口输出为现有 `ApiResult` 风格，并补充异常处理与错误返回

## 2. PublicApi 服务间鉴权与公网安全

- [ ] 2.1 新增 `ApiKeyAuthMiddleware`（仅保护 `/Api/ProjectCatalog/*` 路径）
- [ ] 2.2 在 `Program.cs` 注册中间件与配置绑定，保证不影响现有控制器行为
- [ ] 2.3 在 `appsettings` 增加 `ProjectCatalogSync` 配置占位并通过环境变量覆盖真实密钥
- [ ] 2.4 增加访问审计日志（调用 IP、结果状态）并确保不记录完整 `ApiKey`

## 3. UrbanManagement 拉取与仅插入同步

- [ ] 3.1 新增 `BasePlatformSyncOptions` 与 `GovProjectInitOptions` 配置模型
- [ ] 3.2 新增 `IBasePlatformProjectHttpClient`（Refit）并配置 `BaseUrl`、超时、重试策略
- [ ] 3.3 新增 `IGovProjectInitFieldProvider` 与默认实现，使用固定常量并保留 `// TODO`
- [ ] 3.4 新增 `GovProjectPullAppService`，实现分页拉取、去重、批量插入与统计结果输出
- [ ] 3.5 实现“仅插入新增”规则：`GovProject.Id == ProId` 时跳过且不执行更新/删除

## 4. UrbanManagement 后台任务接入

- [ ] 4.1 新增 `GovProjectPullBackgroundWorker`，按 `PullIntervalMinutes` 周期触发拉取
- [ ] 4.2 在模块中注册 Worker 和相关依赖，支持 `BasePlatformSync:Enabled` 开关
- [ ] 4.3 增加失败日志与下周期重试行为，避免异常导致任务中断
- [ ] 4.4 校验项目列表接口可读取并展示同步导入的 `GovProject` 数据

## 5. 验证与上线准备

- [ ] 5.1 补充鉴权测试：无 Key / 错 Key 返回 401，正确 Key 返回分页数据
- [ ] 5.2 补充幂等测试：首次导入 1500 条后，重复执行导入数应为 0
- [ ] 5.3 补充边界测试：分页拉取、多页聚合、远端 5xx/401、网络超时场景
- [ ] 5.4 补充初始化字段测试：新导入项目的 `BuildLicenseNo`、`FdBuildLicenseNo` 使用配置常量
- [ ] 5.5 完成部署配置核对（HTTPS、公网地址、双端一致 `ApiKey`、告警阈值）
