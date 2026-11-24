# pipelines/graphs/baseplatform — domain index

FdSoft.BasePlatform / `FD_Base` 相关验收 Graph。

约定权威：[`pipelines/AGENTS.md`](../../AGENTS.md)。本文件只索引本 domain。

## 现行 Graph

| slug | family | goal |
|------|--------|------|
| `fd-base-proid-5041-authority` | ingest | `fd-base-proid-5041-authority`（135 `FD_Base`；默认 dry-run；写入需 `-Apply`） |
| `fd-base-product-5040-5041` | transform | `fd-base-product-5040-5041`（生成 129 `JC_Product` 5040/5041 SQL；形状字面量；不依赖 5020；cook 不连库） |
| `fd-base-poweritem-5040-5041` | transform | `fd-base-poweritem-5040-5041`（129 菜单 SQL + 角色 PowerCode；`expect/after-insert.*`；cook 不连库） |
| `sso-findong-5040-5041-login` | probe | `sso-findong-5040-5041-login`（生产 `sso.findong.com` GetToken；5040/5041；secrets 必填） |
| `sso-redis-product-cache-probe` | probe | `sso-redis-product-cache-probe`（`.local/SSO/appsettings.json` Redis；`AllTable`/`JCProduct` 是否含 5040/5041；可选 `-Apply` HDEL） |
| `sso-redis-product-cache-refresh` | transform | `sso-redis-product-cache-refresh`（127 Redis `HDEL AllTable JCProduct`；默认 dry-run；`-Apply` 失效后下次 GetToken 重建） |

新 Graph **MUST** 落在本目录下独立 slug；**MUST NOT** 与已有 `goal` 并存第二个 `active`。
