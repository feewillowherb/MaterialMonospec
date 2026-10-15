## Context

Postman 文档 [ls21_mgrserver · 根据sn获取设备信息](https://documenter.getpostman.com/view/12321363/TzecDQss#45d679e1-9814-4fc0-b219-3f7743c6328c) 定义：

- URL：`http://{{ls21业务服务器IP}}:{{ls21业务服务器Port}}/api/devices/getDeviceBySN`
- 默认 Port：`17808`
- Method：`POST`
- Body：`{ "type": "req", "app": "ls20", "sn": "ls20://..." }`
- 返回：`status`（0 离线 / 1 在线 / 2 任务中 / 3 断电）与 `tasks`

MaterialClient 现状：`IsOnlineAsync` 对 `{LocalIP}:8888` 发 GET；`8888` 是音柱播放口，不是业务服。播放仍正确使用 `{SoundIP}:8888`。

## Goals / Non-Goals

**Goals:**

- 状态查询与官方业务服契约一致（POST + 17808）
- 保持 `IsOnlineAsync` 对外语义（1/2 → 在线；其余/异常 → 离线）
- 播放 / TTS 路径不变

**Non-Goals:**

- 不新增独立「业务服 IP/端口」配置项（`LocalIP` 即业务服所在机，与 TTS `:10008` 同机假设不变）
- 不实现 ls21 登录 token（现网该接口无 token 可 200）
- 不改状态栏轮询 UI

## Decisions

1. **BaseURL = `http://{LocalIP}:17808`**  
   `LocalIP` 已表示本机/业务侧 IP（TTS 亦用此 host）。业务服默认端口写死 `17808`，与代码中 `8888`/`10008` 常量风格一致。

2. **Refit `[Post("/api/devices/getDeviceBySN")]` + request record**  
   Body 字段与文档一致；不向 GET query 兼容层。

3. **`{"msg":"device not found"}` → 离线**  
   HTTP 200 但无 `status` 时默认 `Status=0`，`IsOnlineAsync` 返回 false；可选记录 `msg` 便于诊断。

## Risks / Trade-offs

- [业务服未装在 LocalIP 机] → 需运维保证 mgrserver 与 TTS 同机，或后续另开 change 加配置项  
- [未来强制 token] → 现网未强制；若启用再单独补鉴权  
- [错误 SN] → 返回 offline，与「查不到设备」一致，不抛到 UI
