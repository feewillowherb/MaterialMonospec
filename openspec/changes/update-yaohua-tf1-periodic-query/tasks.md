# Tasks: update-yaohua-tf1-periodic-query

Mode B: baseline `dev-truck-scale-weight`. Change branch: `update-yaohua-tf1-periodic-query`.

## 1. Branch

- [x] 1.1 MaterialMonospec + MaterialClient 确认在 `dev-truck-scale-weight`；切出同名分支 `update-yaohua-tf1-periodic-query`

## 2. Serial write surface

- [x] 2.1 `ISerialPort` / `SerialPortWrapper` 增加 `Write(byte[] buffer, int offset, int count)`

## 3. Yaohua Type1 Demo-style exchange

- [x] 3.1 `YaohuaTf1Protocol`：`BuildQuery` + `Exchange`（Discard→Write→读至 ETX）；10s Timer；`OnDataReceived` 空实现
- [x] 3.2 解析 Demo 应答并 `PublishWeight`；超时/无法解析打 Warning
- [x] 3.3 `TruckScaleWeightService`：`OnStart`/`OnStop` 在 WriteLock 外；避免首发锁冲突与关口死锁

## 4. Tests & verify

- [x] 4.1 单测：`BuildQuery`、`Exchange`、应答解析
- [x] 4.2 `dotnet test` 相关用例通过；勾选 tasks
