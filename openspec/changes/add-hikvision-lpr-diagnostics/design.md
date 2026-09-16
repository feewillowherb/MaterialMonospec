## Context

生产「测试抓拍」只 `ContinuousShoot`；收数靠 `StartListen_V30` 或 `SetupAlarmChan_V50` + 消息回调。现场登录正常、触发有日志、无回调/无图。用户要求诊断程序为**独立应用**：无 Common、无 UI、JSON 配账号与本机 host/port、可长时运行；代码允许非固化（排障专用）。

## Goals / Non-Goals

**Goals:**

- 独立 Exe，专门测海康 LPR 收数链路
- JSON 配置设备凭据 + 本机 `host`/`port`（监听绑定）
- 无 UI；控制台日志；进程可一直跑着收报警
- 自带 HCNetSDK P/Invoke（可从官方 Demo 拷贝），**零** `MaterialClient.Common` 引用
- 覆盖：Login、`SetDVRMessageCallBack_V31`、`SetupAlarmChan_V50`、可选 `StartListen_V30`、`ContinuousShoot`、回调里解析车牌/图片有无
- **运行期收集诊断信息**并落盘，便于贴日志排障（不必依赖正式客户端 Serilog）

**Non-Goals:**

- 不依赖、不修改 Common / Urban / 设置页
- 不做图形界面
- 不要求与生产结构体布局测试共用；不强制进 publish-urban
- 不自动改摄像机网页报警主机

## Decisions

### D1: 独立项目、无 Common

**选择**：例如 `repos/MaterialClient/tools/HikvisionLprProbe/`（或 `src/HikvisionLprProbe/`）单项目 Exe；`ProjectReference` **不得**指向 Common/UI/EF。

**理由**：用户明确要求独立与非固化；避免 internal SDK / DI / ABP 拖累排障迭代。

**备选**：挂 Toolkit——否（仍偏产品工具链且易间接依赖）。

### D2: 非固化 P/Invoke 自包含

**选择**：从 `AlarmCSharpDemo` / `HCNetSDK.h` 拷贝所需 API 与结构体到本项目（Login_V40、SetDVRMessageCallBack_V31、SetupAlarmChan_V50、CloseAlarmChan_V30、StartListen_V30、ContinuousShoot、PLATE/ITS 结果结构等）。允许后续随排障随意改，不保证与 Common 同步。

**理由**：用户允许非固化；加快落地。

### D3: JSON 配置（无 UI）

**选择**：旁路 `appsettings.json` 或 `config.json`（`CopyToOutputDirectory`），示例字段：

```json
{
  "device": {
    "ip": "192.168.1.64",
    "port": 8000,
    "userName": "admin",
    "password": "****"
  },
  "listen": {
    "host": "0.0.0.0",
    "port": 9960
  },
  "arm": {
    "enabled": true,
    "byLevel": 1,
    "byAlarmInfoType": 1
  },
  "listenEnabled": true,
  "autoShootIntervalSeconds": 0,
  "logDirectory": "logs"
}
```

- `listen.host` / `listen.port`：本机 `StartListen_V30` 绑定（及文档提示设备报警主机应对齐可达地址）
- `autoShootIntervalSeconds > 0`：周期 `ContinuousShoot`；`0` 则仅布防/监听后长时等过车，控制台命令或启动时射一次由实现约定（默认启动后射一次再常驻）

**理由**：用户要求 JSON 账号 + host/port；无 UI。

### D4: 长时运行无 UI Windows 程序

**选择**：`OutputType=Exe` 控制台子系统（或 WinExe + AllocConsole——优先普通 Console）；主线程：启动 SDK 链路后 `Console.ReadLine` / `CancellationToken` + Ctrl+C 优雅撤防 Logout Cleanup。

**理由**：可挂着观察回调；符合「长时运行无 UI」。

### D5: 默认同时验证布防收数（可配）

**选择**：默认 `arm.enabled=true`；`listenEnabled` 可配。回调统一打日志：时间、lCommand、车牌、图片字节是否 >0、保存可选到 `logDirectory`。

**理由**：对准当前「触发无返回」；监听路径仍可测。

### D6: 命名 record 仍用于本程序内部多值

**选择**：即便非固化，本程序内多值组合仍用命名 `record`（与编排仓 C# 约定一致），不向 Common 传播。

### D7: 执行时收集并落盘诊断信息

**选择**：配置 `logDirectory`（默认 `logs/`）。运行期：

| 产出 | 内容 |
|------|------|
| `probe.log`（或按日滚动） | 逐步操作、ErrorCode、句柄、回调摘要 |
| `diagnostics.json`（会话结束或周期性刷新） | 步骤矩阵 + 最近回调摘要（命名 record 序列化） |
| `captures/`（可选） | 回调中解析到的图片字节落盘 |

每步 MUST 带 UTC/本地时间戳；回调 MUST 记录 lCommand、车牌、图片长度。Ctrl+C 退出前刷新一次 `diagnostics.json`。

**理由**：用户要求执行时收集诊断信息，便于「触发有、结果无」对照现场。

## Risks / Trade-offs

- **[Risk] 与 Urban 同端口监听冲突** → Mitigation：JSON 可改 port；README/启动日志警告先停客户端
- **[Risk] 非固化结构体与机型不匹配** → Mitigation：可改 byAlarmInfoType；日志打 raw command
- **[Risk] 密码明文 JSON** → Mitigation：仅本地排障文件；勿提交真实密码（gitignore 示例 `config.local.json`）
- **[Trade-off] 与生产代码重复** → 换隔离排障速度；不维护双份同步义务

## Migration Plan

1. 落地独立项目 + 示例 `config.example.json` + 拷贝 HCNetSDK.dll  
2. 现场：停正式客户端 → 改 JSON → 运行 Exe → 看回调日志  
3. 用完可删；不影响产品包

## Open Questions

- 是否支持启动后控制台键入 `shoot` 再触发一次？建议实现（长时进程友好）。  
- 项目放 `tools/` 还是 `src/`：默认 **`tools/HikvisionLprProbe`**，强调非产品模块。
