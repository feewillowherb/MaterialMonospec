# materialclient-working-db-load（materialclient）

## 目的 / Goal

用 `scripts/MaterialClient/Start-MaterialClient.ps1` 的构建目录启动 MaterialClient，加载 `working/MaterialClient.db`，检查这次启动日志有没有错误。Web Host 启动错误不计入。

Goal 槽：`materialclient-working-db-load`

Status: **active**

该环境里的 `MaterialClient.db` 允许被这份工作副本覆盖。正式样本 `_tmp/1110/MaterialClient.db` 不写。

## 非目标

- 不修改 `repos/` 业务代码
- 不启动 Urban 或 Recycle 进程
- 不把 cook 结果写成产品通过。P3 只由用户判定

## Cook

编排是 PowerShell，调用现有的 Build / Start 脚本。日志判断是 Node.js：`scripts/scan-load-log.ts`。

## 配置指针

- `./config.yaml`
- `./secrets.example.yaml`
