# design-brief — urban-debug-license-bypass
id: urban-debug-license-bypass
family: probe
goal: urban-debug-license-bypass
status: active
purpose: Prove MaterialClient.Urban Debug starts and exposes diagnostic HTTP without a valid local JWT.
sockets:
  start: urban-debug-idle
  end: bypass-proved
cook: new-object
nonGoals:
  - 不修改业务代码
  - 不提交 secrets/runs
  - 不替代规范与 CI
  - Agent 不宣布 L3 通过
  - 不把 Release 严格失败自动化进本图
environment: local
stopOnError: false
target:
  baseUrl: http://localhost:9961
  endpoints:
    - GET /
    - GET /api/settings
secretsKeys:
  - baseUrl
steps:
  - bind-config
  - prepare-invalid-license
  - start-urban-debug
  - cook-probe-host
  - validate-bypass
collectors:
  - prepare
  - request-response
  - summary.json
  - report.md
adapters:
  start: scripts/Start-UrbanDebugForBypassProbe.ps1
  http: scripts/Invoke-UrbanDebugLicenseBypassProbe.ps1
humanGates:
  - urban-already-running
  - debug-build-required
  - acceptance
failurePolicy:
  retries: 1
  stopOnError: false
