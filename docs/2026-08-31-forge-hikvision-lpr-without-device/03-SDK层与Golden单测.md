# SDK 层与 Golden 单测

## SDK 包定位

路径：`C:\Users\77162\Desktop\CH-HCNetSDKV6.1.9.48_build20230410_win64`

与车牌报警最相关：

| 相对路径 | 用途 |
|----------|------|
| `Demo示例\3- C# 开发示例\4-报警布防监听\` | 布防 + `MSGCallBack` 收 `COMM_UPLOAD_PLATE_RESULT` / `COMM_ITS_PLATE_RESULT` 等 |
| `Demo示例\3- C# 开发示例\12-交通产品\TrafficDemo\` | 交通产品示例（含车牌相关结构） |
| `库文件\` | `HCNetSDK.dll`、`HCCore.dll`、`HCNetSDKCom\` 等运行时依赖 |

官方说明要点（报警 Demo「请先看这里」）：

- Demo **依赖真实设备布防**后收报警，不是离线重放工具
- 运行目录须带齐 SDK 库与 `HCNetSDKCom` 文件夹

**结论：** SDK 文档/Demo **不能**替代「无设备向 MaterialClient 推识别结果」；它们验证的是「连上真机后回调怎么解析」。

## 仓库内已有的 SDK 字节级伪造

`tests/MaterialClient.Common.Tests/HikvisionGolden/`：

- `HikvisionPlateGoldenFixtureBuilder`：按 **HCNetSDK V6.1.9.48 win-x64 布局** 合成 `alarmer.bin` / `plate_result.bin` + 最小 JPEG
- 单测：`HikvisionPlateGoldenBinaryTests` 等 — 验证 `HikvisionLprService` / 结构体解析，**不启动 Avalonia Urban**

适用：改编码、改 struct、修 ITS vs Upload 路径回归。

不适用：端到端卡口 tab / UM 上云。

## 为何不建议「伪造 MSGCallBack」做 E2E

1. 回调由 SDK 在登录布防后触发；自调非托管回调易踩生命周期/线程问题  
2. 产品边界已收敛到 `LicensePlateRecognizedEventData`；E2E 应从事件层注入  
3. `test-plate` 已覆盖「伪造海康识别结果」的业务语义（`DeviceType=Hikvision`）

若未来要做「带图」的伪造：扩展 `SetTestPlateRequest` 增加可选本地图片路径，或在注入前写临时 jpg 再填 `LprImagePath`（需改代码，本调研不实施）。
