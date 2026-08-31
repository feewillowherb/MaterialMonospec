# Shared cook adapters / runbooks

放登录 runbook、跨 Graph 复用片段等。  
相对 Graph 深度：`graphs/<domain>/<slug>/` → `../../../_shared/...`

| 路径 | 用途 |
|------|------|
| `urban/Invoke-UrbanLprSeedSettings.ps1` | MaterialClient.Urban 诊断口：GET/POST Settings，**完全替换** `licensePlateRecognitionConfigs` |
| `urban/Invoke-UrbanLicenseSeed.ps1` | 演示授权初始化：写入 `license.urban` + 替换 `LicenseInfo`（或 POST `/api/license/seed`） |
| `urban/seeds/demo-license.json` | 固定演示授权（杭州凡东科技演示项目 / XNXS20260611001） |
| `urban/tools/UpsertLicenseInfo/` | 本地 SQLite upsert 小工具（`dotnet run`） |

当前仓库以各 Graph 自带 `scripts/`（experimental）为主；需要 TS/Playwright workspace 时再引入包与根 `package.json`。
