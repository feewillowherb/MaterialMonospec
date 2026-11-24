# sso-redis-product-cache-refresh

## 目的 / Goal

刷新生产 SSO 使用的 Redis（默认 `.local/SSO/appsettings.json` → `RedisServer:Default`，主机 **172.16.87.127**）上的产品缓存 field：

`HDEL AllTable JCProduct`

删除后，下次 `GetToken` / 切产品会按 `Status=1 AND DeleteStatus=0` 从 `FD_Base.JC_Product` **重建**（业务代码无自动失效路径）。

Goal 槽：`sso-redis-product-cache-refresh`

Status: **active**

## 非目标

- 不主动 `HSET` 重建（避免序列化与 SSO `RedisHelper` 不一致）
- 不写 SQL Server、不调 `GetToken`
- 不把 Redis 口令写入证据
- Agent 不宣布 P3

## 配置指针

- `./config.yaml`
- Redis：`redisAppsettingsRel` → `.local/SSO/appsettings.json`
- 可选覆盖：`./secrets.local.yaml` 的 `redisConnection`

## Sockets

| | |
|--|--|
| Start | `sso-redis-cache-stale` |
| End | `sso-redis-cache-invalidated` |
| Cook | in-place |

## 行为

1. 解析 Redis 连接（secrets 优先，否则 appsettings）。
2. **默认 dry-run**：报告 `AllTable`/`JCProduct` 是否存在、产品条数、是否含 5040/5041；**不删除**。
3. **`-Apply`**：`HDEL AllTable JCProduct`，再 `HEXISTS` 确认 field 已消失。

## Invoke

experimental

```powershell
# dry-run：只看当前缓存
powershell -ExecutionPolicy Bypass -File pipelines/graphs/baseplatform/sso-redis-product-cache-refresh/scripts/Invoke-SsoRedisProductCacheRefresh.ps1

# 真正删除 field（下次登录重建）
powershell -ExecutionPolicy Bypass -File pipelines/graphs/baseplatform/sso-redis-product-cache-refresh/scripts/Invoke-SsoRedisProductCacheRefresh.ps1 -Apply
```

## 判定级别

| 级 | 含义 |
|----|------|
| P0 | Redis 可达 |
| P1 | dry-run 可读状态；或 `-Apply` 已执行 HDEL |
| P2 | `-Apply` 后 `HEXISTS AllTable JCProduct` = 0 |
| P3 | 用户接受（仅用户） |

## 人闸

- `environment: shared`
- `-Apply` 删除生产产品缓存；下一次登录会重建
