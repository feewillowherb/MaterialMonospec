# design-brief — admin-ui-layout-observe

```yaml
id: admin-ui-layout-observe
family: observe
goal: admin-ui-layout-interaction-review
status: active
purpose: 138 Admin 布局壳与 8 业务页只读采证；登录经 135 GetToken 写 Redis
sockets:
  start: admin-session-pending
  end: admin-ui-observe-captured
cook: new-object
environment: shared
target:
  baseUrl: http://192.168.3.138:5333
  ssoBaseUrl: http://192.168.3.135:8500
  userName: "13777554358"
  webProductCode: 5040
  loginMethod: redis-session
secretsKeys:
  - passWord
  - userName
  - redisConnection
  - refreshProductCache
steps:
  - bind-config
  - redis-login
  - capture-shell
  - walk-routes
  - spot-interact
  - write-report
```
