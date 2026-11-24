# sso-redis-product-cache-probe

## 目的 / Goal

读取生产 SSO 使用的 Redis（默认从 `.local/SSO/appsettings.json` 的 `RedisServer:Default`）中 `AllTable` / `JCProduct` 产品缓存，确认是否包含 **5040**、**5041**，并报告 `ProductType` 等公开字段。

可选 `-Apply`：`HDEL AllTable JCProduct`，迫使下次 `GetToken` 从 `FD_Base.JC_Product` 重建缓存。

Goal 槽：`sso-redis-product-cache-probe`

Status: **active**

## 非目标

- 不写 SQL Server
- 不调用 `GetToken`
- 不把 Redis 口令写入证据
- Agent 不宣布 P3

## 配置指针

- `./config.yaml`
- Redis 连接：`redisAppsettingsRel` → `.local/SSO/appsettings.json`（gitignore 本机副本；库指向 129，Redis 主机见该文件）
- 可选覆盖：`./secrets.local.yaml` 的 `redisConnection`

## Sockets

| | |
|--|--|
| Start | `sso-redis-cache-idle` |
| End | `sso-redis-cache-probed` |
| Cook | in-place |

## 行为

1. 解析 Redis 连接串（优先 secrets，否则 appsettings）。
2. `HEXISTS` / `HGET AllTable JCProduct`；解析产品列表。
3. 报告总数、是否含 5040/5041、这两条的 ProductType/OrganizeType/Status。
4. `-Apply` 时 `HDEL` 该 field 并记录删除结果。

## Invoke

experimental

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/baseplatform/sso-redis-product-cache-probe/scripts/Invoke-SsoRedisProductCacheProbe.ps1
```

清缓存：

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/baseplatform/sso-redis-product-cache-probe/scripts/Invoke-SsoRedisProductCacheProbe.ps1 -Apply
```

## 判定级别

| 级 | 含义 |
|----|------|
| P0 | Redis 可达且 `AllTable` 存在 |
| P1 | `JCProduct` field 可读并可解析 |
| P2 | 缓存中同时存在 5040 与 5041（且 DeleteStatus=0） |
| P3 | 用户接受（仅用户） |

## 人闸

- `environment: shared`
- `-Apply` 会删生产产品缓存 field
