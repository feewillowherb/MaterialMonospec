## Context

现场调研见 `docs/2026-09-16-mc-hikvision-login-session-issues/`：探针在仅 Listen + ContinuousShoot 下可收图；Urban 同路径常无回调，且 Wireshark 可见大量 PC→相机 `:8000` RST。根因侧重点是 **登录/会话持有**，不是布防。

当前代码要点：

- `HikvisionLprService.IsOnline`：Login 后立刻 Logout
- LPR 与 `HikvisionService` 分持 `_deviceKeyToUserId` / `deviceKeyToUserId`
- soft-reset：`Cleanup` 后只清监控缓存；LPR Listen 句柄可能僵死
- `TriggerCaptureAsync`：Shoot 成功即记成功，无回调超时告警

约束：跨子仓库 C# 禁止 tuple，多值用命名 `record`；minimal-di / type-owned-methods 适用。

## Goals / Non-Goals

**Goals:**

- 长会话：每台海康设备（同一逻辑键）进程内单一有效 `userId`
- 探活不重登：对已有 `lUserID` 轻量探测，失败再 Invalidate + Login
- soft-reset 后 LPR 会话与 Listen 一并重建
- Shoot 后无回调可观测（Warning）
- LPR 与监控共享会话语义（同键同 Id）

**Non-Goals:**

- `SetupAlarmChan` / `CloseAlarmChan` / `SetDVRMessageCallBack_V31` / 自动布防（P3）
- 合并 `HikvisionSdk` 与嵌套 `NET_DVR` 为单一 P/Invoke 源文件（可后续）
- 修改车牌校验文案、设置页无牌展示、报警主机网络配置

## Decisions

### 1. 会话键与共享入口

- **决策**：引入进程内会话管家（命名如 `HikvisionSdkSession` / `IHikvisionLoginSessionStore`），键为 `Ip:Port:Username`（或与现有 `BuildDeviceKey` 对齐并统一大小写规则）。
- **LPR 与监控**均通过该管家 `Acquire` / `Release` / `Invalidate`，禁止各自再裸 Login 成第二份会话。
- **备选**：仅改 LPR、监控仍独立 → 否决（无法消解双登录与 soft-reset 半清）。

### 2. IsOnline / 探活

- **决策（已锁定）**：有缓存 `userId` 时调用  
  `NET_DVR_RemoteControl(lUserID, NET_DVR_CHECK_USER_STATUS /* 20005 */, …)`  
  （已在 `_tmp/CH-HCNetSDKV6.1.9.48_*/HCNetSDK.h` 核对：宏 `20005`，注释为检测用户是否在线；导出 `NET_DVR_RemoteControl`）。
- 成功刷新探活时间；失败 Invalidate 后可选单次 Login。
- **节流**：默认常量 **30s** 内不重复探活。
- **备选已否决作主路径**：Login/Logout 测活；`GetDVRWORKSTATE` / `GetDVRConfig` 仅极端兜底，默认不实现。
- **备选**：继续 Login/Logout → 否决（RST 源）。

探活结果类型示例（实现必须用 `record`）：

```csharp
public sealed record HikvisionSessionProbeResult(bool Valid, uint ErrorCode, string Message);
```

常量示例：

```csharp
public const uint NetDvrCheckUserStatus = 20005;
```

### 3. 启动与停止顺序

- **决策**（LPR）：`Init` → `StartListen` → 对已配置海康 LPR 设备 `Acquire`（Login）并缓存。
- **停止**：`StopListen` → 对 LPR 持有的会话 `Release`/Logout（若监控仍引用则仅解引用，真正 Logout 在引用计数归零时）。
- **不**在本 change 增加布防步骤。

### 4. soft-reset 联动

- **决策**：`TrySoftResetSdkAsync` 在 `Cleanup` 前/后通过会话管家 **InvalidateAll**；重置后由 LPR 服务检测「Listen 需重建」并再次 `StartListen` + 按需 `Acquire`。
- 监听句柄：soft-reset 后强制 `_listenHandle = -1` 再启动，禁止沿用旧 handle。

### 5. 抓拍无回调告警

- **决策**：`TriggerCaptureAsync` 在 Shoot 成功后启动短窗口计时（建议 3–5s，可常量）；窗口内未观察到该设备相关车牌回调则 `LogWarning`。不改变 Shoot 返回语义（仍表示命令已接受）。
- **备选**：改 API 为等待回调 → 否决（超时与 UI 阻塞风险大，本 change 只做可观测性）。

### 6. 布防相关代码

- **决策**：本 change **不新增、不调用、不依赖**布防 API。若仓库其它分支已有布防代码，本 change 合入时不得把自动布防塞进 `DeviceManager` 启动路径。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 探活 `RemoteControl(20005)` 对部分固件返回异常 | 记录 ErrorCode；Invalidate 后单次 Login；勿回退 Login/Logout 测活 |
| 共享会话引用计数错误导致过早 Logout | 单测覆盖 Acquire/Release；soft-reset 路径 InvalidateAll |
| 重建 Listen 与端口占用 | 重建前 StopListen；日志标明失败 ErrorCode |
| 无回调告警误报（设备慢） | 窗口可调；仅 Warning 不失败化 Shoot |

## Migration Plan

- 纯客户端行为变更，无 DB migration。
- 发布 Urban 后观察：RST 减少、`IsOnline` 不再刷 Login、soft-reset 后仍有 Listen 日志、Shoot 无回调有 Warning。
- 回滚：回退本 change 合入提交即可。

## Open Questions

- 无回调窗口默认 3s 还是 5s（实现可先常量 5s）。
- `RemoteControl` 的 `lpInBuffer` 是否必须非空：对照同包 Demo 后写入 P/Invoke 调用。
