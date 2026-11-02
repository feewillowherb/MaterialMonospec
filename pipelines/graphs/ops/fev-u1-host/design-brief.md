# design-brief — fev-u1-host

```yaml
id: fev-u1-host
family: probe
goal: ops-fev-u1-host
status: active
purpose: Collect FEV U1 host OS/virt evidence via _shared/ops SSH on the target machine.
sockets:
  start: fev-u1-idle
  end: fev-u1-evidenced
cook: new-object
nonGoals:
  - 不修改业务代码
  - 不提交 secrets/runs/私钥
  - 不跑 U2–U9
  - Agent 不宣布 FEV Verdict
environment: local
stopOnError: false
target:
  fevId: U1
  fevDoc: docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md
secretsKeys:
  - host
  - user
  - port
  - identityPassphrase
  - probeCommand
steps:
  - id: bind-config
  - id: unlock-identity-optional
  - id: ssh-u1-probe
  - id: parse-evidence
  - id: gate-verdict
collectors:
  - ssh
  - prepare
  - summary
  - report
adapters:
  sharedUnlock: pipelines/_shared/ops/ssh/Unlock-SshIdentity.ps1
  sharedInvoke: pipelines/_shared/ops/ssh/Invoke-SshRemote.ps1
humanGates:
  - missing-secrets
  - missing-identity
  - passphrase-required
  - acceptance
failurePolicy:
  retries: 1
  stopOnError: false
```
