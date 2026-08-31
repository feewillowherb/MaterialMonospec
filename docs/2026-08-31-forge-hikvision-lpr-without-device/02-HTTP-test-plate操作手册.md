# HTTP 诊断 API 操作手册

只用 **GET / POST**（无 PUT）。配置接口读写**整份 Settings**，不是单独 LPR 列表。

## 1. 开启诊断 Host

```json
"MinimalWebHost": {
  "Urls": "http://localhost:9961",
  "EnableOnStartup": true
}
```

```http
GET http://localhost:9961/
```

## 2. 查询整份 Settings

```powershell
curl "http://localhost:9961/api/settings"
```

响应含 `settings`：`ScaleSettings`、`SystemSettings`、`CameraConfigs`、`LicensePlateRecognitionConfigs`、`WeighingConfiguration`、`SoundDeviceSettings`、`UrbanSettings` 等。

## 3. 保存整份 Settings

典型流程：先 GET → 改 `licensePlateRecognitionConfigs` → 原样带回其它字段再 POST。

```powershell
$body = @{
  scaleSettings = @{ scaleType = "TestMode" }
  documentScannerConfig = @{}
  systemSettings = @{ urls = "http://localhost:9961" }
  cameraConfigs = @()
  licensePlateRecognitionConfigs = @(
    @{
      name = "gate-in"
      ip = "10.0.0.1"
      siteType = "Checkpoint"
      deviceType = "Hikvision"
      urbanInOutType = "Enter"
      urbanSiteType = "Construction"
      userName = "admin"
      password = "admin"
      port = "8000"
      channel = "1"
    },
    @{
      name = "product-out"
      ip = "10.0.0.2"
      siteType = "FinishedProduct"
      deviceType = "Hikvision"
      urbanInOutType = "Exit"
      urbanSiteType = "Disposal"
      userName = "admin"
      password = "admin"
      port = "8000"
      channel = "1"
    }
  )
  weighingConfiguration = @{}
  soundDeviceSettings = @{}
  urbanSettings = @{}
} | ConvertTo-Json -Depth 8

curl -Method POST "http://localhost:9961/api/settings" `
  -ContentType "application/json" `
  -Body $body
```

保存后发布 `SettingsSavedEventData`。未传的嵌套对象会按空默认值覆盖，建议以 GET 结果为底稿。

## 4. 测试卡口 / 成品（走 LicensePlateRecognizedEventData）

```powershell
curl -Method POST "http://localhost:9961/api/lpr/test-passage" `
  -ContentType "application/json" `
  -Body (@{
    siteType = "Checkpoint"
    plateNumber = "浙A12345"
    plateColor = "黄"
  } | ConvertTo-Json)

curl -Method POST "http://localhost:9961/api/lpr/test-passage" `
  -ContentType "application/json" `
  -Body (@{
    siteType = "FinishedProduct"
    deviceName = "product-out"
    plateNumber = "浙B88888"
  } | ConvertTo-Json)
```

`siteType` 禁止 `Scale`。无匹配配置时返回 400，提示先 `POST /api/settings`。

## 5. 通用 test-plate（仍保留）

```powershell
curl -Method POST "http://localhost:9961/api/lpr/test-plate" `
  -ContentType "application/json" `
  -Body (@{ plateNumber = "浙A12345"; deviceName = "gate-in" } | ConvertTo-Json)
```

## 6. 设备在线状态

```powershell
curl "http://localhost:9961/api/device/online-status"
```

## 7. 边界

本机诊断口 ≠ UM Receive。客户端上云卡口/成品仍见 OpenSpec §7。
