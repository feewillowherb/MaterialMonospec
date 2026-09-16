# 04 — 不重复登录时如何确认缓存 UserId 有效

## 问题

长会话改造后，内存中会持有 `lUserID`（如 `_deviceKeyToUserId`）。  
仅判断 `userId >= 0` **不能**证明设备侧会话仍有效（对端断线、本机 RST、`Cleanup`/soft-reset 后僵死句柄等）。

目标：**不调用 `NET_DVR_Login_*` 再次登录**的前提下，确认（或证伪）当前缓存 `UserId`。

参考 SDK 包：`_tmp/CH-HCNetSDKV6.1.9.48_build20230410_win64`（以包内 `HCNetSDK.h` 宏名为准）。

## 结论（推荐做法）

| 层级 | 做法 | 能否代替 Login |
|------|------|----------------|
| 本地缓存 | `userId >= 0` 且字典未清、未经过未重建的 Cleanup | **否**（仅防空用） |
| **轻量探活** | 对已有 `lUserID` 调只读/控制 API，看返回值 + `NET_DVR_GetLastError` | **是**（主路径） |
| **异常回调** | `NET_DVR_SetExceptionCallBack_V30` 等，失效时按 Id/IP 清缓存 | **是**（被动） |

**不要**再用 `Login → Logout` 当 `IsOnline`（会制造短连接与 RST 风暴）。

## 1. 轻量探活（主动，不重新 Login）

对缓存的 `lUserID` 调用一次轻量接口：

| API（名称以头文件为准） | 说明 |
|-------------------------|------|
| `NET_DVR_RemoteControl(lUserID, NET_DVR_CHECK_USER_STATUS, …)` | 多版本文档用于「检测用户/设备是否仍在线」；落地前在 `HCNetSDK.h` 搜索 `CHECK_USER` / `CHECK_USER_STATUS` 确认宏与参数 |
| `NET_DVR_GetDVRWORKSTATE_V30(lUserID, …)` | 取工作状态；失败且错误码为网络/未登录类 → 会话失效 |
| 轻量 `NET_DVR_GetDVRConfig(lUserID, …)` | 读小配置（如时间/基本参数）；比重登轻，仍有 I/O |

### 判定启发式

实现时用命名 `record` 表达结果（禁止 tuple），例如概念上：

```text
SessionProbeResult(Valid, ErrorCode, Message)
```

- 调用成功 → 视为有效，刷新「上次探活时间」
- 调用失败 + 网络超时 / 连接失败 / 用户未登录 / 句柄无效等 → **Invalidate 缓存 `userId`**，再允许单次 `Login`
- 探活失败时：**先清缓存再 Login**，避免「先 Logout 再 Login」打成 RST 风暴

### 探活节流

与 soft-reset 冷却类似，避免探活本身变成 RST 源：

```text
距上次成功探活 < T（建议 30–60s）→ 直接信缓存
否则 → 执行轻量探活
```

## 2. 异常回调（被动获知失效）

进程级注册一次（示例名以头文件为准）：

- `NET_DVR_SetExceptionCallBack_V30`
- 关注交换异常、重连成功/失败等与会话相关的异常类型

回调中按 `lUserID` 或设备 IP **清除** `_deviceKeyToUserId` / 监控侧会话字典。  
这样不必高频轮询也能知道「内存 UserId 已废」。

## 3. 仅本地校验（不够）

```text
userId >= 0
  && 字典中仍存在
  && 未走过未配对重建的 Cleanup
```

用途：防止空句柄调用。  
**不能**单独作为 `IsOnline` 或抓拍前唯一依据。

发现 `NET_DVR._initialized == false`（soft-reset 已 Cleanup）时：必须 **整表清空** 所有缓存 `userId`，并重建 Listen，不得继续使用旧 Id。

## 4. 与 IsOnline / TriggerCapture 的建议策略

```text
用缓存前 / IsOnline：
  if 无缓存
    → Login 一次并缓存
  else if 距上次探活 < T
    → 直接视为有效
  else
    → RemoteControl / GetDVRWORKSTATE 探活
         失败 → 清缓存 → Login 一次

TriggerCapture：
  只用缓存 userId + ContinuousShoot
  若失败且错误像会话失效
    → 清缓存 → Login → 再 Shoot 一次（限一次）
```

## 5. 落地前在 V6.1.9.48 头文件核对

在 `_tmp/CH-HCNetSDKV6.1.9.48_build20230410_win64`（或开发包「头文件」目录）的 `HCNetSDK.h` 中搜索并记录实际宏名/数值：

- `CHECK_USER` / `CHECK_USER_STATUS`
- `RemoteControl`
- `GetDVRWORKSTATE`
- `EXCEPTION_` / `RECONNECT`

P/Invoke 签名与常量 **以该头文件为准**；不同 build 宏值可能不同。  
本笔记撰写时工作区未成功打开该包头文件，实现 change 时必须核对后写入代码。

## 6. 与本夹其它文档的关系

- 问题背景：[02-登录逻辑问题清单.md](./02-登录逻辑问题清单.md) §1 `IsOnline` Login/Logout
- 目标态：[03-修改建议.md](./03-修改建议.md) P0「在线检测不要每次真 Login/Logout」
- 建议纳入 OpenSpec：`fix-hikvision-session-lifecycle` 的「会话探活」任务
