# design-brief — recycle-hmac-auth

可提交；不含密钥。生成日 2026-09-08。

```yaml
id: recycle-hmac-auth
family: probe
goal: gov-recycle-hmac-auth
status: active
purpose: 探测 RecycleSync HMAC 对杭州市资源化利用厂 exapi 是否被接受
sockets:
  start: endpoint-idle
  end: probe-recorded
cook: new-object
nonGoals:
  - 不修改业务代码
  - 不提交 secrets/runs
  - 不替代规范与 CI
  - Agent 不宣布 L3 通过
  - 不证明 PointNumber 绑定
environment: shared
stopOnError: true
target:
  method: POST
  baseUrl: https://gzt.cgw.hangzhou.gov.cn/muckmanage/addmtd0p1q/api/zhztc-module-exapi
  path: /dataCenter/resourcePlace/productTransportRecord/v1/addBatch
  bodyMode: empty-array
secretsKeys:
  - accessKey
  - secretKey
steps:
  - bind-endpoint
  - cook-post
  - validate-response
collectors:
  - id: requestResponse
    required: true
    when: always
  - id: summary
    required: true
    when: always
humanGates:
  - missing-secrets
  - environment-shared-confirm
  - acceptance
failurePolicy:
  retries: 2
  stopOnError: true
adapters:
  http:
    mode: script-invoke
    experimental: true
```
