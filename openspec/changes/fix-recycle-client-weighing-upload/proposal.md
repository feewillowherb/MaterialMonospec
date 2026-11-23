## Why

称重保存后发布本地事件，处理器只写日志。Web 已有 ReceiveAsync 接收路径，匿名请求返回 401，带设备身份的接收入库仍待验证。

## What Changes

- 打通落盘、受信设备上传、Web 幂等接收和台账可见链路，覆盖断网恢复和重复提交。

## Capabilities

### New Capabilities

### Modified Capabilities

- `recycle-platform-api-boundary` — 桌面称重上传到 Recycle Web。

## Impact

MaterialClient 的 Recycle 称重保存和上传，以及 UrbanManagement 的设备鉴权、接收和台账。
