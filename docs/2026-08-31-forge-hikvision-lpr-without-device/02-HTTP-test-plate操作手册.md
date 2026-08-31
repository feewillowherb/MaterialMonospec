# HTTP test-plate 操作手册

## 1. 开启诊断 Host

`MaterialClient.Urban/appsettings.json`（或本地覆盖）：

```json
"MinimalWebHost": {
  "Urls": "http://localhost:9961",
  "EnableOnStartup": true
}
```

默认仓库里 **`EnableOnStartup` 为 `false`**，不改则注入口不会监听。

启动 Urban 客户端后：

```http
GET http://localhost:9961/
```

应返回含 `/api/lpr/test-plate` 的 endpoints 列表。

## 2. 伪造卡口识别

假设设置里有设备名 `卡口-入口`，`SiteType = Checkpoint`：

```powershell
curl -Method POST "http://localhost:9961/api/lpr/test-plate" `
  -ContentType "application/json" `
  -Body (@{
    plateNumber = "浙A12345"
    deviceType  = "Hikvision"
    deviceName  = "卡口-入口"
  } | ConvertTo-Json)
```

期望：

- 日志：`Test plate injected` + `Created urban passage record ... site Checkpoint`
- 有人值守窗 **卡口** tab 出现一行（`PassageSource.Checkpoint`）

## 3. 伪造成品识别

设备名如 `成品-出口`，`SiteType = FinishedProduct`：

```powershell
curl -Method POST "http://localhost:9961/api/lpr/test-plate" `
  -ContentType "application/json" `
  -Body (@{
    plateNumber = "浙B88888"
    deviceType  = "Hikvision"
    deviceName  = "成品-出口"
  } | ConvertTo-Json)
```

期望：成品 tab 有记录；`PassageSource.FinishedProduct`。

## 4. 请求体字段（代码契约）

`SetTestPlateRequest`：

| JSON 字段 | 类型 | 说明 |
|-----------|------|------|
| `plateNumber` | string | **必填** |
| `deviceType` | `LprDeviceType?` | 默认 Hikvision |
| `deviceName` | string? | 默认 `"TestApi"`；**必须能 FindByDeviceName** |
| `colorType` | Vzvision 色枚举? | 可选；进出 handler 主要用 `PlateColor` 字符串（本 API 未设） |
| `timestamp` | DateTime? | 默认 Now |

## 5. 常见失败

| 现象 | 原因 |
|------|------|
| 连接拒绝 | `EnableOnStartup=false` 或 Url/端口不对 |
| HTTP 200 但无进出记录 | `deviceName` 与设置 `Name` 不一致，或该行是 `Scale` |
| 只有称重侧反应 | 地磅服务也订阅了同一事件；进出仍依赖 SiteType≠Scale |

## 6. 与「上云 HTTP POST」的边界

本手册的 HTTP POST 是 **客户端本机诊断口**，不是 UrbanManagement Receive。

UM 侧卡口/成品已有独立 AppService `ReceiveAsync`（ABP 惯例路由形如 `/api/app/urban-checkpoint-passage/receive` 等），但 **MaterialClient.Urban 尚未实现** 对应 Refit 调用（OpenSpec §7.1–7.2）。本地进出测通后，上云需另开联调或先用 Postman 直打 UM。
