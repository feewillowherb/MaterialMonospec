# docs/UrbanManagement — 运维文档索引

本目录存放 UrbanManagement 的**运维与发布**说明（非 OpenSpec）。约定入口为本文件；勿再以 README 作权威。

## 现行

| 文档 | 说明 |
|------|------|
| [docker-server-deploy.md](./docker-server-deploy.md) | **生产** Docker 发版与运维（正式口 `5233`，2026-11-04 切入） |
| [appsettings.secret.json.example](./appsettings.secret.json.example) | 敏感配置模板（勿提交密钥） |

## 历史

| 文档 | 说明 |
|------|------|
| [windows-server-deploy.md](./windows-server-deploy.md) | IIS + SQLite 手册（`HISTORICAL`；仅回滚参考） |

## 发版入口

| 路径 | 说明 |
|------|------|
| `pipelines/graphs/ops/deploy-urban-acceptance/` | **正式发版**（publish → SCP → docker） |
| `scripts/UrbanManagement/Publish-UrbanManagement.ps1` | IIS robocopy（**勿用于现行正式口**；观察期回滚参考） |

## 蓝图

- [`docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/`](../2026-11-02-urbanmanagement-docker-mssql-upgrade/00-调研总览.md)
- 切流回写：[`05` §3.1](../2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md)

## 相关

- 子仓：`repos/UrbanManagement/`
- 子仓约定：`repos/UrbanManagement/AGENTS.md`
