# Shared cook adapters / runbooks

放登录 runbook、跨 Graph 复用片段等。  
相对 Graph 深度：`graphs/<domain>/<slug>/` → `../../../_shared/...`

| 路径 | 用途 |
|------|------|
| `urban/Invoke-UrbanLprSeedSettings.ps1` | MaterialClient.Urban 诊断口：GET/POST Settings，**完全替换** `licensePlateRecognitionConfigs` |
| `urban/Invoke-UrbanLicenseSeed.ps1` | 授权初始化：写入 `license.urban` + `upsert-license-info`（或 POST `/api/license/seed`）；`-SeedRelPath` 切换项目种子；Local 模式 upsert 前补丁本机 `machineCode` |
| `urban/seeds/demo-license.json` | 默认演示授权（杭州凡东科技演示项目 / XNXS20260611001）；可复制为其他 `seeds/<project>-license.json` |
| `urban/tools/upsert-license-info/` | 本地 SQLite upsert（Node/TS + 内置 `node:sqlite`；由 PS 经 `pnpm exec tsx` 调用；需 Node ≥ 22.5） |
| `../package.json` | pipelines Node workspace（`node_modules/` 已 gitignore） |

当前仓库以各 Graph 自带 `scripts/`（experimental）为主；共享 ingest 工具使用 `pipelines/` 根 `package.json` + TS。
