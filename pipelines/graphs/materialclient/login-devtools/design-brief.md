# design-brief — materialclient/login-devtools

```yaml
id: login-devtools
created: "2026-08-27"
graph:
  product: materialclient
  domain: materialclient
  family: observe
  goal: login-observe-devtools
  status: active
purpose: 用 Avalonia DevTools MCP 对运行中 MaterialClient LoginWindow 做白盒登录采证
sockets:
  start: session-anonymous
  end: observe-captured
cook: new-object
nonGoals:
  - 不修改 repos/ 业务代码
  - 不提交 secrets/runs
  - 不替代 OpenSpec 与 CI
  - Agent 不宣布 L3 通过
  - 不覆盖 FlaUI 黑盒路径（见 login-flaui）
  - 不用 attach-to-file 预览冒充真登录（Design DataContext 无真鉴权）
environment: local
stopOnError: false
target:
  hostProject: repos/MaterialClient/src/MaterialClient
  viewPointer: repos/MaterialClient/src/MaterialClient.UI/Views/LoginWindow.axaml
  viewModel: MaterialClient.UI.ViewModels.LoginWindowViewModel
  windowTitle: 凡东智能物料验收系统
  bindMode: attach-to-app   # 真登录必须 attach 运行进程
secretsKeys: [username, password]
steps:
  - id: bind-app
    name: attach-to-app；定位 LoginWindow / LoginWindowViewModel
  - id: cook-login
    name: 设置 Username/Password 并触发 LoginCommand
  - id: validate-surface
    name: 采证 tree/props/screenshot；对照 L0–L2
collectors:
  - screenshot
  - tree-snapshot
  - props
  - logs
  - http
adapters:
  ui:
    mcp: avalonia_devtools
    mode: attach-to-app
humanGates:
  - missing-secrets
  - app-not-running-or-authcode
  - acceptance
```
