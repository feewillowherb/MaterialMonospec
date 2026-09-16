## 1. Independent probe project

- [x] 1.1 新建独立 Exe 项目（建议 `tools/HikvisionLprProbe`），加入 solution；**禁止**引用 MaterialClient.Common / UI / 其它产品项目
- [x] 1.2 自包含拷贝 HCNetSDK P/Invoke 与所需结构体（Login_V40、回调 V31、SetupAlarmChan_V50、CloseAlarmChan、StartListen_V30、ContinuousShoot、PLATE/ITS）；输出目录带上 HCNetSDK.dll 等原生依赖
- [x] 1.3 提供 `config.example.json` + gitignore `config.local.json`（含 device 凭据与 `listen.host` / `listen.port`）

## 2. Runtime behavior

- [x] 2.1 启动读 JSON → Init → Login → 按配置布防和/或 StartListen → 注册回调打日志（车牌/是否有图/可落盘）
- [x] 2.2 无 UI 长时运行：Ctrl+C 优雅撤防/停监听/Logout/Cleanup；支持启动后触发一次 ContinuousShoot，可选控制台命令再 shoot
- [x] 2.3 启动日志打印实际监听 host:port，并提示勿与正式客户端抢端口

## 3. Collect diagnostics at runtime

- [x] 3.1 按 `logDirectory` 写 `probe.log`：每步时间戳、PASS/FAIL、ErrorCode、句柄
- [x] 3.2 回调写入诊断（lCommand/车牌/图片长度；可选 `captures/` 落盘）；退出前刷新 `diagnostics.json` 会话摘要
- [x] 3.3 可选 `inboundTcpCheckSeconds`：在 StartListen 前用 TcpListener 检测相机→PC 入站 TCP；失败时输出交换机隔离/路由 ACL/防火墙提示

## 4. Verify

- [x] 4.1 独立项目 `dotnet build` / `dotnet run` 通过（无 Common 引用）
- [ ] 4.2 真机：JSON 配好账号与 host/port；确认能登录；观察主动抓拍或过车回调，并检查 `logs/` 下诊断文件是否齐全；核对 inbound_tcp 步骤