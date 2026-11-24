# Acceptance — sso-redis-product-cache-probe

Status: **pending**（P3 仅用户）

| 项 | 值 |
|----|----|
| run | `2026-11-24T170515` |
| P0 | pass（`172.16.87.127:6379`，`AllTable` 存在） |
| P1 | pass（`JCProduct` 可读，15 条） |
| P2 | fail（缓存无 5040、5041；样本含 5020 等） |
| P3 | pending（仅用户） |
| 对象 | Redis `AllTable` / `JCProduct`（`.local/SSO/appsettings.json` → 129 环境 Redis） |
| 原因 | DB 已有产品但 Redis 产品缓存未刷新；可用 `-Apply` HDEL 后让 GetToken 重建 |
