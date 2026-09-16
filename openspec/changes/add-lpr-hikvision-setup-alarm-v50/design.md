## Context

海康 LPR 现网主路径是 `HikvisionLprService.StartAsync` → `NET_DVR_StartListen_V30`（本机监听端口收设备推送）。设置页操作栏已有「测试抓拍」，但没有客户端布防入口。

SDK 包 `CH-HCNetSDKV6.1.9.48` 头文件声明：

```c
LONG NET_DVR_SetupAlarmChan_V50(
    LONG iUserID,
    LPNET_DVR_SETUPALARM_PARAM_V50 lpSetupParam,
    char *pSub,
    DWORD dwSubSize);
```

官方 C# Alarm Demo 仍演示 `SetupAlarmChan_V41`；本变更按产品要求直接对接 **V50**。现有 `HikvisionSdk` 尚无 `SetupAlarmChan_*` / `SETUPALARM_PARAM*` / `SetDVRMessageCallBack_V31` / `CloseAlarmChan_V30` 声明。

## Goals / Non-Goals

**Goals:**

- 设置页「车牌识别设置」每行操作栏可对海康设备一键布防
- 通过 `NET_DVR_SetupAlarmChan_V50` 建立布防句柄，失败时暴露 `NET_DVR_GetLastError`
- 布防前确保消息回调已注册，车牌报警仍走既有 `MessageCallback` 解析路径（`COMM_UPLOAD_PLATE_RESULT` / ITS）
- 进程退出 / 服务释放时关闭未撤防句柄，避免句柄泄漏

**Non-Goals:**

- 用客户端布防替换或停用 `StartListen_V30` 全局监听
- 为 Vzvision / Huaxiazhixin 做等价「布防」
- 在设置页做高级布防参数 UI（等级、订阅子报文等本期固定默认值）
- UrbanManagement / BasePlatform 变更

## Decisions

### D1: UI 入口放在 LPR 操作栏「布防」按钮

**选择**：与「测试抓拍」并列；仅 `DeviceType = Hikvision` 可见。

**理由**：运维按设备行操作；非海康无 HCNetSDK 布防 API。

**备选**：全局「全部布防」——本期不做，避免误操作多设备。

### D2: 服务层 API 挂在 `IHikvisionLprService`，不扩 `ILprDevice`

**选择**：新增命名 `record` 结果类型（如 `HikvisionAlarmArmResult`），方法形如 `SetupAlarmChanAsync(LicensePlateRecognitionConfig config)`；设置 VM 仅在海康行调用。

**理由**：布防是海康专有；`ILprDevice` 保持抓拍能力面，避免强行给所有厂商加空实现。符合 minimal-di / 现有 resolver 用法。

**备选**：在 `ILprDevice` 加 `SupportsClientAlarm` —— 过度抽象，本期拒绝。

### D3: 必须用 V50，参数结构按头文件布局

**选择**：P/Invoke `NET_DVR_SetupAlarmChan_V50` + `NET_DVR_SETUPALARM_PARAM_V50`（含 `byRes4[128]`）。`pSub` / `dwSubSize` 本期传 `IntPtr.Zero` / `0`（无订阅子报文）。

**默认字段**（对齐 Alarm Demo 的 V41 语义，落到 V50 同名字段）：

| 字段 | 值 | 说明 |
|------|----|------|
| `dwSize` | `sizeof` | 必填 |
| `byLevel` | `1` | 二级布防（Demo 常用） |
| `byAlarmInfoType` | `1` | 新报警 `NET_ITS_PLATE_RESULT`（与现有 ITS 回调分支一致） |
| `byDeployType` | `0` | 客户端布防 |
| 其余 | `0` | 保持默认 |

**理由**：用户明确要求 V50；C# Demo 无 V50 绑定，以 `HCNetSDK.h` 为准手工绑定，并加 struct size 测试防布局漂移。

**备选**：先 V41 再升 V50 —— 与需求不符。

### D4: 消息回调与 StartListen 共存

**选择**：布防前若尚未注册客户端消息回调，则调用 `NET_DVR_SetDVRMessageCallBack_V31`，委托指向与监听相同的 `MessageCallback`（或等价入口），并用 `GCHandle` 钉住。若 `StartListen_V30` 已启动，仍可额外注册 V31 回调供布防通道投递（SDK 文档路径与 Demo 一致）。

**理由**：仅 `SetupAlarmChan` 而无回调则收不到事件；复用解析逻辑避免双份车牌解码。

**备选**：布防走独立回调 —— 增加重复解析与测试成本，拒绝。

### D5: 句柄缓存与重复布防

**选择**：按设备键（与现有 `_deviceKeyToUserId` 一致，通常 IP/Name）缓存 `alarmHandle`。再次布防前若已有有效句柄，先 `NET_DVR_CloseAlarmChan_V30` 再 Setup。`IAsyncDisposable` / `StopAsync` 路径关闭全部句柄。

**理由**：避免重复布防失败与泄漏；与 Demo「先撤再布」一致。

**备选**：本期只布不撤 —— 泄漏风险高，拒绝。

### D6: 反馈方式

**选择**：成功/失败写 Logger；可选在行上复用或新增短文案字段（如 `LastAlarmArmStatus`）显示「布防成功」或错误码。不强制弹窗（与「测试抓拍」当前日志风格对齐）；若现有设置页已有通知模式可复用则优先复用。

**理由**：现场排障以日志+行状态足够；避免新对话框类型。

## Risks / Trade-offs

- **[Risk] V50 结构体布局错误 → Setup 恒失败** → Mitigation：对照 `HCNetSDK.h`；增加 `Marshal.SizeOf` 与黄金尺寸断言（参考既有 `HikvisionSdkStructLayoutTests`）
- **[Risk] 回调未钉住被 GC** → Mitigation：与 StartListen 相同使用 `GCHandle.Alloc`
- **[Risk] StartListen + SetupAlarm 双通道重复事件** → Mitigation：文档注明可能重复；本期不改去重；若现场重复再开 change 做幂等
- **[Risk] 登录会话与抓拍缓存冲突** → Mitigation：复用 `TryLogin` / `_deviceKeyToUserId`，不另开孤立会话除非必要
- **[Trade-off] 固定默认布防参数** → 换灵活性换实现速度；高级参数后续再开

## Migration Plan

1. 发布含 P/Invoke + 服务方法 + 设置页按钮的 MaterialClient 构建
2. 现场对一台海康 LPR 点「布防」，确认日志成功且能收到车牌回调（或至少 SDK 返回成功）
3. 回滚：隐藏/不点按钮即可；旧包无此按钮，行为不变

## Open Questions

- 布防成功后是否需要在 UI 上提供显式「撤防」切换？本期默认：再次点击「布防」会先关闭再 Setup；若产品要独立「撤防」文案，实现前可补一句确认。
- `byAlarmInfoType=1`（ITS）是否覆盖全部现场机型？若仅老结构 `NET_DVR_PLATE_RESULT`，可将默认改为 `0` 或做成配置（后续 change）。
