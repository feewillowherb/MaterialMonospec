## Context

UrbanManagement Admin 是 Blazor Server 管理端。Gateway 把 `/_blazor/**`、管理页面 fallback 和普通管理 API 送到 Admin，客户端认证、上传、称重接收和实时服务走各自的优先路由。共享 Hosting 管道当前没有为全部服务启用认证。

FdSoft.SSO 的 Web 登录是 `POST /GetToken`，不是 OIDC。135 上产品 5040「萧山城管管理平台」在产品缓存重建后，匹配口令已经返回 `code=200` 和令牌。错误口令返回业务失败且没有令牌。SSO 的产品列表缓存在 Redis `AllTable` / `JCProduct`；直接插入数据库后，缓存未失效时登录读不到新产品。

本变更只在 Admin 宿主建立登录边界。SSO 基址、Web 产品编码和连接凭据放在 Admin 配置，不写入仓库。

## Goals / Non-Goals

**Goals:**

- 管理端用户用 SSO 账号登录，并且只接受配置的那一个 Web 产品。
- 登录成功后使用 Admin 自己的 Cookie 会话访问页面、Blazor Hub 和管理接口。
- 未登录不能使用管理页面和管理操作。
- 客户端、遗留接口和健康检查保持现有入口。

**Non-Goals:**

- 不把 SSO 做成 OIDC 提供方，不共享 SSO Cookie，不把浏览器传来的 JWT 当作登录证明。
- 不修改 MaterialClient、FdSoft.SSO、FdSoft.BasePlatform、`ProductEnum` 或 `ProductExtEnum`。
- 不把 SSO 的 `ProIds`、企业或角色自动映射成 UrbanManagement 的数据范围。本变更只建立管理端入口会话。
- 不实现切换项目、切换产品，也不把 SSO `logout` 当作令牌撤销。
- 不把管理端登录跳转加到 Ingest、Attachment、Realtime、Worker 或 Gateway。

## Decisions

### Admin 服务端调用 GetToken

登录页把账号和口令提交给 Admin。Admin 向配置的 SSO 基址发送 `POST /GetToken`，请求体固定为 `switchType=0`、`productType=2`、`toProductIds` 只含配置的 Web 产品编码。已验证编码是 5040，运行值以配置为准。

只有 HTTP 成功、业务 `code=200`，且响应中的产品编码等于配置值时，才创建本地会话。口令错误、SSO 不可用、产品不匹配或响应没有产品标识时，不创建会话，登录页显示失败。

备选是浏览器直接持有 SSO 令牌并访问 Admin。管理接口和 Blazor Hub 无法只靠浏览器保存的令牌划清客户端路由，因此不采用。

### 本地 Cookie 会话

会话保存在 Admin Cookie 中，内容至少包含 SSO 用户标识、用户名和已接受的产品编码。Cookie 只发给 Admin 所在站点。有效期使用 Admin 自己的配置，不读取 SSO Redis 来延长或撤销这次会话。

服务端调用 SSO 的结果用命名记录在 Admin 边界传递，例如 `record SsoWebLoginResult(bool Accepted, int? ProductCode, string? UserName, string? FailureMessage)`。不把 SSO 令牌写入日志、调研文档或 Urban 数据库。

调用 SSO 的类型需要外部 HTTP，因此可以作为 Admin 的应用服务注册。页面和组件只调用该服务，不访问数据库。

### 只保护 Admin

认证中间件和登录页放在 Admin 宿主。Blazor 页面、`/_blazor` Hub，以及 Admin 暴露的管理 API 要求有效本地会话。`/health/live` 和 `/health/ready` 继续匿名。

Gateway 路由表不改。客户端优先路由仍然先于 Admin fallback，因此上传、称重接收和实时通道不会落到登录页。

### 退出

退出删除 Admin Cookie 并回到登录页。不调用 SSO `logout`。已有 Blazor 电路在会话失效后不能继续提交管理操作。

## Risks / Trade-offs

- [SSO 产品缓存仍是旧列表] → 部署说明要求目标环境的 SSO 在开放登录前确认产品缓存包含配置的 Web 产品。本变更不负责刷新 SSO Redis。
- [SSO 令牌已签发但 Admin Cookie 仍在] → 本地会话到期前不会再次向 SSO 求证。这是有意取舍，避免把共享 Redis 当成 Urban 的会话库。
- [管理 API 与客户端 API 共用路径前缀] → 实施时按 Gateway 的优先路由核对；只能给 Admin 进程内的管理端点加会话检查。
- [SSO 身份和 Urban 项目数据尚未对应] → 登录成功只表示可以进入管理端，不表示该用户自动拥有全部项目的数据权限。

## Migration Plan

1. 为 Admin 配置 SSO 基址和 Web 产品编码。已联调环境的产品编码为 5040。配置缺失时 Admin 启动失败，避免管理端在无登录配置时继续匿名开放。
2. 确认该 SSO 进程的产品缓存包含该产品编码。
3. 发布 Admin。Gateway 与其他服务保持现有部署。
4. 回退时发布上一版 Admin，并移除本次新增的 SSO 配置依赖。不需要迁移数据库。

## Open Questions

- Admin Cookie 的空闲超时和绝对超时采用哪组时长。
- 登录页除账号、口令外是否需要验证码。当前 SSO `GetToken` 本身不要求验证码。
- 后续哪一个变更把 SSO 返回的项目列表映射到 UrbanManagement 的查询范围。
