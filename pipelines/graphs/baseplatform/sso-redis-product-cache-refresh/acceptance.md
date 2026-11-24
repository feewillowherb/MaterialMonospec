# Acceptance — sso-redis-product-cache-refresh

Status: **pending**（P3 仅用户）

| 项 | 值 |
|----|----|
| run | `2026-11-24T171412` |
| P0 | pass（PING PONG） |
| P1 | pass（`HDEL` 返回 1） |
| P2 | pass（`HEXISTS AllTable JCProduct` = 0） |
| P3 | pending（仅用户） |
| 对象 | Redis `172.16.87.127` `AllTable` / `JCProduct` |
| 原因 | Apply 已删除 field；下次 GetToken 将从 FD_Base 重建 |
