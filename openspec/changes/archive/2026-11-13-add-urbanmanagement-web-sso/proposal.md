## Why

UrbanManagement 的 Web 管理页面目前没有登录边界，匿名请求可以进入管理页面和管理操作。管理端需要使用 FdSoft.SSO 作为登录媒介，并且只保护 Web 管理页面。135 上产品 5040「萧山城管管理平台」的 `GetToken` 已经返回令牌，可以按这条已验证的自定义登录协议继续接入。

## What Changes

- Admin 增加登录页。浏览器只把账号和口令交给 Admin 服务端；普通登录固定 `switchType=0`、`productType=2`，并带上配置中的 Web 产品编码。页面不接受切换项目、切换产品或调用方自造的身份参数。
- Admin 服务端向配置的 SSO 基址 `POST /GetToken`。只有业务 `code=200` 且返回产品等于该 Web 产品编码时，才建立 Admin 自己的 Cookie 会话。解码浏览器持有的 JWT 不算登录成功。
- 会话保护 Admin 的 Blazor 页面、Blazor Hub，以及 Admin 上支撑这些页面的管理接口。未登录访问管理深链接时进入登录页，不执行页面操作。
- 退出只清除 Admin 本地会话。本变更不把 SSO 的 `logout` 当成已验证的令牌撤销。
- 客户端上传、称重接收、实时通道、遗留接口和健康检查保持现有匿名或原有认证行为，不因为管理端登录而跳转到登录页。
- 不修改 MaterialClient、FdSoft.SSO、FdSoft.BasePlatform 或 `ProductEnum` / `ProductExtEnum`。SSO 基址和 Web 产品编码来自 Admin 配置；已验证的产品编码是 5040。

## Capabilities

### New Capabilities

- `urbanmanagement-web-sso`: UrbanManagement Web 管理端通过 FdSoft.SSO `GetToken` 建立本地会话，并只保护管理页面、Blazor Hub 和管理操作

### Modified Capabilities

## Impact

- **子仓库**：仅 `repos/UrbanManagement` 的 Admin 宿主。Gateway 继续按现有路由把管理页面和 `/_blazor/**` 送到 Admin；客户端优先路由不变。
- **分支**：Mode A — `add-urbanmanagement-web-sso`
- **输入**：[`docs/2026-11-13-urbanmanagement-fdsoft-sso/`](../../../docs/2026-11-13-urbanmanagement-fdsoft-sso/00-调研总览.md)。135 产品数据 Verdict 为 FEASIBLE；刷新 135 的 `AllTable` / `JCProduct` 后，匹配口令 `GetToken` 返回 `code=200`、产品 5040 且带有令牌，登录 Verdict 为 FEASIBLE。证据在 `.local/fev-sso-db135-login5040-refresh/result.json`，不含口令或令牌。错误口令证据在 `.local/fev-sso-db135-login5040/result.json`。
- **人闸**：本提案只建立变更工件。调研结论进入产品代码前仍要 Human `APPROVED`。本文件不宣称该批准已经给出。
