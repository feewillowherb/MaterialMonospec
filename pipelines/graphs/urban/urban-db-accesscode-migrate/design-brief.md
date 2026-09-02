# design-brief — urban-db-accesscode-migrate

```yaml
id: urban-db-accesscode-migrate
family: probe
goal: urban-sqlite-accesscode-migrate-verify
status: active
purpose: 验证线上 UrbanManagement.db 快照经本地副本能否 MigrateAsync 到 AccessCode 列并启动可用
sockets:
  start: sqlite-prod-snapshot
  end: migrate-use-proved
cook: new-object
nonGoals:
  - 不修改业务代码
  - 不写回线上快照原件
  - 不提交 secrets/runs
  - 不替代规范与 CI
  - Agent 不宣布 L3 通过
environment: local
stopOnError: true
target:
  sourceDb: _tmp/UrbanManagement.db
  baseUrl: http://127.0.0.1:44371
  umProject: repos/UrbanManagement/src/UrbanManagement.App/UrbanManagement.App.csproj
  expectedRenameMigrationId: 20260902100000_RenameEntityBuildLicenseNoToAccessCode
secretsKeys: []
steps:
  - bind-config
  - copy-source-db
  - start-um-migrate
  - await-migrate
  - smoke-http
  - stop-um
  - verify-schema
collectors:
  - id: prepare
    required: true
  - id: logs
    required: true
  - id: schema
    required: true
  - id: requestResponse
    required: true
  - id: summary
    required: true
  - id: report
    required: true
humanGates:
  - missing-source-db
  - confirm-local-copy-only
  - acceptance
failurePolicy:
  retries: 0
  stopOnError: true
adapters:
  invoke: scripts/Invoke-UrbanDbAccessCodeMigrate.ps1
  schema: scripts/verify-schema.mjs
```

## 选型说明

- **family=probe**：健康/启动/HTTP 采证；库写入仅限 runs 工作副本（副作用小于 ingest）。
- 未选 transform：目标含「使用」（启动 + list 冒烟），不只做文件派生。
- 同 goal 无其它 active Graph（生成时）。
