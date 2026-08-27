# design-brief — materialclient/login-flaui

```yaml
id: login-flaui
created: "2026-08-27"
graph:
  product: materialclient
  domain: materialclient
  family: observe
  goal: login-observe-flaui
  status: active
purpose: 用 FlaUI-MCP（windows_*）对 MaterialClient 主程序 LoginWindow 做黑盒登录采证
sockets:
  start: session-anonymous
  end: observe-captured
cook: new-object
nonGoals:
  - 不修改 repos/ 业务代码
  - 不提交 secrets/runs
  - 不替代 OpenSpec 与 CI
  - Agent 不宣布 L3 通过
  - 不覆盖 Avalonia DevTools 白盒路径（见 login-devtools）
  - 不验证 Urban 变体启动链（本 Graph 指向主程序 LoginWindow）
environment: local
stopOnError: false
target:
  hostProject: repos/MaterialClient/src/MaterialClient
  viewPointer: repos/MaterialClient/src/MaterialClient.UI/Views/LoginWindow.axaml
  viewModel: MaterialClient.UI.ViewModels.LoginWindowViewModel
  windowTitle: 凡东智能物料验收系统
  controls:
    username: UsernameTextBox   # x:Name
    password: PasswordTextBox
    submitLabel: 立即登录
  successHints:
    - LoginWindow 隐藏或 IsLoginSuccessful
    - AttendedWeighingWindow 可见（有人值守过磅）
secretsKeys: [username, password, exePath]
steps:
  - id: bind-session
    name: 解析 secrets、确认 LoginWindow 可见（非 AuthCode）
  - id: cook-login
    name: FlaUI 填账号密码并点击立即登录
  - id: validate-surface
    name: 采证截图与表面态，对照 L0–L2
collectors:
  - screenshot
  - uia-snapshot
  - logs
  - http
adapters:
  ui:
    mcp: windows   # FlaUI-MCP
    mode: uia-ref
humanGates:
  - missing-secrets
  - license-or-authcode-blocking
  - acceptance
```
