# Tasks: update-yaohua-tf1-periodic-query

Mode B: baseline `dev-truck-scale-weight`. Change branch: `update-yaohua-tf1-periodic-query`.

## 1. Branch

- [x] 1.1 MaterialMonospec + MaterialClient 确认在 `dev-truck-scale-weight`；切出同名分支 `update-yaohua-tf1-periodic-query`

## 2. Serial write surface

- [x] 2.1 `ISerialPort` / `SerialPortWrapper` 增加 `Write(byte[] buffer, int offset, int count)`

## 3. Yaohua Type1 Demo-style B-C-D poll

- [x] 3.1 `YaohuaTf1Protocol`：`BuildQuery` + `Exchange`；轮询 B→C→D，间隔 200ms；`OnDataReceived` 空实现
- [x] 3.2 存储 B/C/D 为毛/皮/净并 `PublishComponentWeights`；`B` 驱动实时重量
- [x] 3.3 `TruckScaleWeightService`：`OnStart`/`OnStop` 在 WriteLock 外

## 4. Tests & verify

- [x] 4.1 单测：`BuildQuery`、`Exchange`、应答解析、`CommandInterval=200ms`
- [x] 4.2 `dotnet test` 相关用例通过
