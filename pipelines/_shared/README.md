# Shared cook adapters / runbooks

放登录 runbook、跨 Graph 复用片段等。  
相对 Graph 深度：`graphs/<domain>/<slug>/` → `../../../_shared/...`

当前仓库以各 Graph 自带 `scripts/`（experimental）为主；需要 TS/Playwright workspace 时再引入包与根 `package.json`。
