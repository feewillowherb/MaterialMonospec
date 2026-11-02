# design-brief — ssh-agent

```yaml
id: ssh-agent
family: probe
goal: ops-ssh-agent
status: active
purpose: Give AI Agents a repeatable SSH probe/runbook using repo-local docker-linux-ed25519.
sockets:
  start: ssh-idle
  end: ssh-proved
cook: new-object
nonGoals:
  - 不修改业务代码
  - 不提交 secrets/runs/私钥
  - 不替代规范与 CI
  - Agent 不宣布 L3/P3 通过
environment: local
stopOnError: false
target:
  identityRel: .local/.ssh/docker-linux-ed25519
  probeCommand: "uname -a && whoami && pwd"
secretsKeys:
  - host
  - user
  - port
  - probeCommand
  - allowDestructive
steps:
  - id: bind-config
  - id: resolve-identity
  - id: ssh-remote-probe
  - id: validate-exit
collectors:
  - ssh
  - prepare
  - summary
  - report
adapters:
  sharedResolve: pipelines/_shared/ops/ssh/Resolve-SshIdentity.ps1
  sharedInvoke: pipelines/_shared/ops/ssh/Invoke-SshRemote.ps1
humanGates:
  - missing-secrets
  - missing-identity
  - destructive-command
  - acceptance
failurePolicy:
  retries: 1
  stopOnError: false
```
