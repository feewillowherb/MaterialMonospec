# design-brief — govsync/postweight

```yaml
id: postweight
created: "2026-08-20"
graph:
  product: urban
  domain: govsync
  family: probe
  goal: gov-inout-record-save
  status: active
purpose: 用固定夹具向政府平台 inoutRecord/save 发起可重复 POST，采证请求/响应并停在人闸验收
sockets:
  start: endpoint-idle
  end: probe-recorded
cook: new-object
nonGoals:
  - 不修改 repos/ 业务代码
  - 不提交 secrets/runs
  - 不替代 OpenSpec 与 CI
  - Agent 不宣布 L3 通过
  - 不验证 UrbanManagement 入库链路（仅直连政府出站契约）
environment: shared   # 非 local；目标为内网政府地址，生成时已按用户指针写入
stopOnError: true
target:
  method: POST
  url: http://191.12.15.58:8899/sapi/v1/inoutRecord/save
  contentType: application/json
  payloadContract: GovSyncWeightPayload / 联调成功样例
  fixtureImage: fixtures/test_pic.jpg
  scenario:
    buildLicenseNo: XNXS20250819001   # 用户提供的对接码，对齐联调样例字段名
    carNo: 浙A12345
    weightTon: 20
    weightKg: 20000                   # 20t → kg
    snapTimeMode: run-now             # 每次 run 取本机当前时间
secretsKeys: []                       # 联调未要求 token；若后续需要再补
steps:
  - id: bind-endpoint
    name: Bind 政府 save 端点与夹具
  - id: cook-post
    name: 组装 payload 并 POST
  - id: validate-response
    name: 校验 HTTP 与业务 code
collectors:
  - id: request-response
    required: true
    when: always
  - id: summary
    required: true
    when: always
humanGates:
  - missing-secrets
  - environment-shared-confirm
  - destructive-write-confirm
  - acceptance
failurePolicy:
  retries: 2
  stopOnError: true
adapters:
  http:
    mode: script-invoke
    sources:
      - scripts/Invoke-GovSyncPostWeight.ps1
      - ask
```

## Context 来源（未编造）

| 项 | 来源 |
|----|------|
| URL | 用户提供；与 `docs/gov-sync-postweight-analysis.md` 联调成功地址一致 |
| payload 字段 | `repos/UrbanManagement/.../GovSyncWeightPayload.cs` + 联调样例 |
| 对接码 / 车牌 / 重量 / 图片 | 用户本次提供 |
| `areaCode` 默认 | `GovSyncConstants.XiaoShanAreaCode` = `330109` |
| 成功判定 | 业务 `code == 200`（`GovApiConstants.SuccessCode`） |
