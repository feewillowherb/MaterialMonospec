# 04 — 不重复登录时如何确认缓存 UserId 有效

## 问题

长会话改造后，内存中会持有 `lUserID`（如 `_deviceKeyToUserId`）。  
仅判断 `userId >= 0` **不能**证明设备侧会话仍有效（对端断线、本机 RST、`Cleanup`/soft-reset 后僵死句柄等）。

目标：**不调用 `NET_DVR_Login_*` 再次登录**的前提下，确认（或证伪）当前缓存 `UserId`。

参考 SDK 包：`_tmp/CH-HCNetSDKV6.1.9.48_build20230410_win64`（以包内 `HCNetSDK.h` 为准）。

## 已采纳决策（2026-09-16）

**轻量探活唯一主方案：**

```text
NET_DVR_RemoteControl(lUserID, NET_DVR_CHECK_USER_STATUS /* 20005 */, lpInBuffer, dwInBufferSize)
```

头文件核对结果（V6.1.9.48）：

| 符号 | 值 / 签名 |
|------|-----------|
| `NET_DVR_CHECK_USER_STATUS` | `20005`（注释：检测用户是否在线） |
| `NET_DVR_RemoteControl` | `BOOL NET_DVR_RemoteControl(LONG lUserID, DWORD dwCommand, LPVOID lpInBuffer, DWORD dwInBufferSize)` |

OpenSpec：`fix-hikvision-session-lifecycle` 实现 MUST 按此方案；**不得**以 Login→Logout 作探活。

`lpInBuffer` / `dwInBufferSize`：实现时对照同包 Demo；通常可为 `NULL`/`0`（若 Demo 要求非空结构再补）。

## 结论分层

| 层级 | 做法 | 能否代替 Login |
|------|------|----------------|
| 本地缓存 | `userId >= 0` 且字典未清、未经过未重建的 Cleanup | **否**（仅防空用） |
| **轻量探活（已采纳）** | `RemoteControl` + `CHECK_USER_STATUS(20005)` + `GetLastError` | **是**（主路径） |
| **异常回调** | `NET_DVR_SetExceptionCallBack_V30` 等，失效时清缓存 | **是**（被动，建议后续/同 change 可选） |

**不要**再用 `Login → Logout` 当 `IsOnline`（会制造短连接与 RST 风暴）。

### 未采纳为探活主路径

| 方案 | 原因 |
|------|------|
| `GetDVRWORKSTATE_V30` | 本包头文件未作为「检测用户是否在线」首选；仅可作极端兜底，非默认 |
| 轻量 `GetDVRConfig` | 更重、需另选命令号 |
| `StartGetDevState` | 异步/结构更重，不适合 `IsOnline` 热路径 |

## 1. 轻量探活行为

实现时用命名 `record`（禁止 tuple），例如：

```csharp
public sealed record HikvisionSessionProbeResult(bool Valid, uint ErrorCode, string Message);
```

- `RemoteControl(..., 20005, ...)` 成功 → 视为有效，刷新「上次探活时间」
- 失败 → **Invalidate 缓存 `userId`**，再允许单次 `Login`（先清缓存再 Login，避免 Logout→Login RST 风暴）

### 探活节流

```text
距上次成功探活 < T（建议默认 30s）→ 直接信缓存
否则 → RemoteControl CHECK_USER_STATUS
```

## 2. 异常回调（被动获知失效）

进程级注册一次（示例名以头文件为准）：

- `NET_DVR_SetExceptionCallBack_V30`
- 关注交换异常、重连成功/失败等与会话相关的异常类型

回调中按 `lUserID` 或设备 IP **清除**共享会话缓存。

## 3. 仅本地校验（不够）

```text
userId >= 0
  && 字典中仍存在
  && 未走过未配对重建的 Cleanup
```

发现 `NET_DVR._initialized == false`（soft-reset 已 Cleanup）时：必须 **整表清空** 所有缓存 `userId`，并重建 Listen。

## 4. 与 IsOnline / TriggerCapture 的策略

```text
用缓存前 / IsOnline：
  if 无缓存
    → Login 一次并缓存
  else if 距上次探活 < T
    → 直接视为有效
  else
    → RemoteControl(userId, CHECK_USER_STATUS=20005, …)
         失败 → 清缓存 → Login 一次

TriggerCapture：
  只用缓存 userId + ContinuousShoot
  若失败且错误像会话失效
    → 清缓存 → Login → 再 Shoot 一次（限一次）
```

## 5. 与本夹 / OpenSpec 的关系

- 问题背景：[02-登录逻辑问题清单.md](./02-登录逻辑问题清单.md) §1
- 目标态：[03-修改建议.md](./03-修改建议.md) P0
- 实现 change：`openspec/changes/fix-hikvision-session-lifecycle/`
