## 1. 实施与联调

- [x] 1.1 只读核对 138 的 Worker 与 Recycle Web 数据库连接配置、Recycle 表、Worker 项目拉取状态及有效 5020 行数。见下方诊断记录。
- [ ] 1.2 若目标库缺少 5020 行，核对 BasePlatform 项目目录是否向该环境提供目标项目。已有授权项目时由 Worker 通过现有项目拉取写入；上游缺行或同步身份无权读取时，记录具体阻塞和负责系统。在线激活仅更新已有项目，不能补建该行。
- [ ] 1.3 取得目标 5020 行的 `SourceProId` 后，在授权范围内配置 138 的 `RecyclePersistence__BoundSourceProId`。本机 FEV 的种子项目仅用于本地实验。
- [ ] 1.4 用已授权账号验证 138 台账读取。缺失绑定的拒绝路径在隔离环境验证，避免为验证而撤掉 138 的有效配置。
- [x] 1.5 Worker 增加显式产品选择。省略配置时保持现有目录请求；选择 5020 时使用独立目录密钥。

## 2. 验收

- [ ] 2.1 在目标联调环境验证上述主路径与失败场景，保留业务记录及响应证据，目标 ICD L3。

## 138 只读诊断 · 2026-11-19

- Recycle Web 健康检查返回 HTTP 200。Worker 与 Web 的数据库连接配置一致，目标 SQL Server 存在 Recycle 台账表。
- `GovProjects` 中有效 5020 行数为 0，Web 已配置绑定值，但该值目前无法解析到有效项目。
- Worker 启动日志显示 `BackgroundServices:Polling=False` 与 `BasePlatformSync:Enabled=False`，项目拉取 Worker 未注册。容器环境也未提供非空的 `PublicApiServiceAuth__BaseUrl` 或 `PublicApiServiceAuth__ApiKey`，仍需核对实际配置来源及上游授权。
- 1.2 待确认 BasePlatform 目录中目标 5020 项目及授权接入方式。现有拉取支持 5001、5020，恢复目录同步前需确认 138 获准同步的项目范围。
- 5020 项目目录的上游变更见 [update-baseplatform-project-catalog-product-code](../update-baseplatform-project-catalog-product-code/proposal.md)。部署后，138 Worker 须使用专用密钥并显式传入 `productCode=5020`，验证目标项目在批准名单内。

## Worker 接入 · 2026-11-20

- 在 138 Worker 的部署配置设置 `BasePlatformSync__Enabled=true`、`BasePlatformSync__ProductCode=5020`、`PublicApiServiceAuth__BaseUrl` 和 `PublicApiServiceAuth__RecycleCatalogApiKey`。专用密钥从环境的密钥配置注入。
- PublicApi 需部署上述目录变更并配置目标项目白名单。138 上的项目同步、Web 绑定和授权台账读取仍待执行。
