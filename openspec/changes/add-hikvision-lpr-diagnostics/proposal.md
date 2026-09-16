## Why

现场海康 LPR「测试抓拍」触发成功、登录正常，但收不到车牌回调与照片。生产客户端链路（监听 / 布防 / 设置窗）耦合重，不便隔离排障。需要一个**完全独立、无 UI、长时运行**的海康 LPR 专用测试程序，用 JSON 配置账号与本机 host/port，单独验证收数是否通。

## What Changes

- 新增**独立** Windows 无 UI 程序（可长时运行），专门测试海康 LPR 登录、布防/监听、主动抓拍与报警回调收图
- **禁止**依赖 `MaterialClient.Common` / UI / ABP；允许自带非固化 P/Invoke 与结构体（可从 HCNetSDK Demo / 头文件拷贝）
- 设备账号与连接参数用 **JSON 配置**（至少含设备 IP/端口/用户名/密码；本机监听 **host** 与 **port** 可配）
- 启动后按配置 Init → Login → 注册回调 → 布防和/或 `StartListen` → 可选周期/手动触发 `ContinuousShoot` → 持续打印收到的车牌与是否含图
- **执行过程中持续收集诊断信息**：每步时间戳、PASS/FAIL、SDK ErrorCode、监听 host:port、布防句柄、回调 lCommand/车牌/是否有图；写入控制台并落盘到配置的诊断目录（日志 + 可选 JSON 摘要 + 可选回调图片）
- **无 Avalonia/WinForms UI**
- **不做**：改生产 `HikvisionLprService` / 设置页；不改 UrbanManagement / BasePlatform；不要求固化到产品发布管线

## Capabilities

### New Capabilities

- `hikvision-lpr-diagnostics`: 独立海康 LPR 无 UI 长时测试程序（JSON 配置、自带 SDK 绑定、无 Common 依赖）

### Modified Capabilities

- （无）

## Impact

- **仓库**：MaterialClient 下独立项目目录（如 `tools/HikvisionLprProbe` 或 `src/HikvisionLprProbe`），**不**引用 Common
- **依赖**：仅 HCNetSDK 原生 DLL + 本程序自带 P/Invoke；可参考 `_tmp/CH-HCNetSDKV6.1.9.48_*` 与 Alarm Demo
- **风险**：与正式客户端争用监听端口；非固化代码不保证与生产布局永久同步——仅作排障工具
- **运维**：改 JSON 即可换设备/本机 host·port；进程可挂着等过车或触发抓拍看回调
