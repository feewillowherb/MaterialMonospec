## Why

音柱在线状态查询调用了错误的 HTTP 契约：对设备口 `8888` 发 `GET /api/devices/getDeviceBySN`，实际 ls21 业务服（`ls21_mgrserver`，默认 `17808`）要求 `POST` + JSON body。现网探测确认 GET 404，按文档 POST 可达。

## What Changes

- 将 `ISoundDeviceApi.GetDeviceStatusAsync` 从 Query `GET` 改为 Body `POST`
- `SoundDeviceService.IsOnlineAsync` 的 BaseURL 从 `{LocalIP}:8888` 改为 `{LocalIP}:17808`（ls21 业务服；播放仍走 `{SoundIP}:8888`）
- 新增状态查询请求 DTO；响应 DTO 兼容 `msg`（如 device not found）
- 更新 `sound-device-status` 规范中的 API 集成场景

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `sound-device-status`: 设备状态 API 集成改为业务服 POST `getDeviceBySN`

## Impact

- **仓库**：MaterialClient（`MaterialClient.Common`）
- **运行时**：依赖本机/局域网 ls21 业务服 `http://{LocalIP}:17808`；播放路径不变
- **配置**：继续复用已有 `LocalIP` / `SoundSN`；不新增设置项
