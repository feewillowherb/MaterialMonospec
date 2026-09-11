## Context

MaterialClient 称重稳定后经 `WeighingCaptureService` → `IHikvisionService.CaptureJpegFromStreamBatchAsync` 批量抓拍。主码流路径 `CaptureJpegFromStream` 每次 `new PlayM4Decoder()`，收到 `NET_DVR_SYSHEAD` 后才 `GetPort`/`OpenStream`/`Play`，`finally` 中 `StopRealPlay` + `Dispose`（含 `FreePort`）。`NET_DVR_Init` 进程内只执行一次。

现场日志（2026-09-11）：连续多车 `decoder init timeout` + PlayM4 32，直至用户退出应用（Cleanup）并重启后恢复。说明问题在进程级 SDK/码流状态，而非单次未重建 PlayM4 对象。源码已有主码流→设备 JPEG 降级（`mainstream-capture-fallback`），但超时诊断把未分配 port 的 last error 记成 32，且缺少失败后的 SDK 软复位。

## Goals / Non-Goals

**Goals:**

- 连续批量抓拍失败后自动软复位 HCNetSDK，并在同一轮重试一次
- 超时日志可区分未收 SYSHEAD vs OpenStream 失败
- decoder init timeout 必须触发既有 JPEG 降级
- `WaitForPlaying` 超时可配置（默认 5000ms）

**Non-Goals:**

- 强制切换现场 `CaptureStreamType` 默认值
- 无图补拍 UI / 语音产品文案
- UrbanManagement 或服务端变更
- 每次抓拍都 Cleanup/Init
- 清扫无关技术债务

## Decisions

### D1: 软复位放在 `HikvisionService`，由批量抓拍编排触发

**选择**：在 `HikvisionService` 提供线程安全的 `TrySoftResetSdkAsync`（或同步等价），由 `CaptureJpegFromStreamBatchAsync` / `WeighingCaptureService` 在「本批成功数为 0 且失败含 decoder-init / 全失败」时调用，然后**同一调用内再跑一轮**批量抓拍。

**理由**：复位必须清登录缓存并翻转 `_initialized`；称重编排层不应直接碰 P/Invoke。单次 `CaptureJpegFromStream` 内不做复位，避免四路串行各触发一次。

**替代**：仅在 `WeighingCaptureService` 计数跨车失败再复位——跨车恢复更慢，且测试/设置页 TestCapture 无法受益。选「本批全失败即复位+同轮重试」。

### D2: 触发阈值与冷却

**选择**：

- 触发：单次批量结果 `successCount == 0 && failCount > 0`（或全部请求失败）时尝试软复位 + 重试一轮
- 冷却：上次成功复位起 **30s** 内不再 Cleanup（仍可走降级）；冷却期内第二次全失败只打日志
- 互斥：`SemaphoreSlim(1,1)` 或专用锁，复位期间其他抓拍等待或快速失败并记日志

**理由**：对齐现场「重启即好」；避免高峰反复 Cleanup 造成秒级卡顿。

### D3: 软复位步骤顺序

**选择**：

1. 登出并清空 `deviceKeyToUserId` 全部条目  
2. `NET_DVR_Cleanup()`；将静态 `_initialized = false`  
3. 短暂等待（建议 200–500ms）  
4. `NET_DVR_Init()`；`_initialized = true`  
5. 不主动 `PlayM4_FreePort` 池外泄漏端口——依赖既有 Dispose；可选重置 `PlayM4PortPool` 信号量仅当确认与 SDK 一致（默认不强制重建池，避免与未 Dispose 竞态）

**理由**：与应用退出清理路径一致；PlayM4 端口已按次 Free，重点复位 HCNetSDK。

### D4: 超时诊断与降级

**选择**：

- `WaitForPlaying` 失败时：若 `decoder.Port < 0` 或未 `IsInitialized`，日志记 `reason=no_syshead`，`PlayM4Error` 可记为 0 或显式字段，**禁止**把 `GetLastError(-1)` 的 32 当作根因  
- 若已 Initialize 但 OpenStream 失败，保留真实 PlayM4 错误码  
- Mainstream 批次路径：凡 `CaptureJpegFromStream` 失败（含 timeout）**必须**调用现有 `CaptureJpeg` 降级

**理由**：现场日志被 32 误导；降级规格已存在，本 change 保证 timeout 不绕过。

### D5: `WaitForPlaying` 可配置

**选择**：在 `SystemSettings`（或现有 Hikvision/抓拍相关配置）增加 `StreamCaptureDecoderTimeoutMs`，默认 `5000`，由 `CaptureJpegFromStream` 读取。不强制改 UI，可用设置 JSON / 现有设置页扩展（若设置页已有系统项则一并暴露，否则仅实体默认值 + 可序列化字段）。

**理由**：弱网可调；默认行为不变。

### D6: 记录类型用 named record，不用 tuple

失败计数、复位结果等使用命名 `record`（如 `SdkSoftResetResult`），符合跨仓 C# 约定。

## Risks / Trade-offs

- [软复位阻塞称重线程数秒] → 冷却 30s；复位步骤尽量短；日志打耗时  
- [复位与 LPR/其他海康登录并发] → 互斥锁；文档注明抓拍与 LPR 可能短暂互相等待  
- [Cleanup 后 LPR Hikvision 需重登] → EnsureLogin 本就会登录；确认 LPR 服务在下次调用可恢复  
- [仅同轮重试不够（设备持续断网）] → 降级 JPEG + 仍返回空列表；不假装成功  
- [PlayM4PortPool 与 Cleanup 竞态] → 复位前尽量等待进行中的抓拍结束（锁）；不在持有 decoder 时 Cleanup  

## Migration Plan

1. 发布 MaterialClient 含本 change 的构建  
2. 现场可保持 `CaptureStreamType=Mainstream`；建议弱网改 Substream（运维建议，非代码强制）  
3. 回滚：回退构建即可；无 DB 迁移  

## Open Questions

- 设置页是否必须暴露 `StreamCaptureDecoderTimeoutMs`（可 apply 时若成本低则暴露，否则仅配置字段）  
- Hikvision LPR 与抓拍是否共用同一 `NET_DVR_Init` 静态标志——若共用，软复位必须覆盖两边（实现时核对 `HikvisionLprService.EnsureInitialized`）
