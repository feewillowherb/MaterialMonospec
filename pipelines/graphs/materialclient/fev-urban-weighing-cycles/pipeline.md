# fev-urban-weighing-cycles

通过本地诊断 API 驱动 `MaterialClient.Urban` 客户端连续完成多周期（默认 100 周期）上磅、判稳和下磅，核对工作库中 `WeighingRecords`、`UrbanWeighingExtensions` 及 `WeighingCycleRecovery` 状态，并检测运行期间是否出现 `SQLite Error 5 / SQLITE_BUSY`、丢单或 Recovery / Polling 阻塞。

实验仅观察客户端内部自然并发（`WeighingCycleRecoveryWorker`、`PollingBackgroundService`、`WeighingRecordService`），不注入外部 SQLite 写事务。

FEV 调研文档：[`docs/2026-11-24-materialclient-urban-100-weighing-sqlite-busy-fev/00-FEV-Urban100条称重数据SQLiteBusy.md`](../../../../docs/2026-11-24-materialclient-urban-100-weighing-sqlite-busy-fev/00-FEV-Urban100条称重数据SQLiteBusy.md)。

## 运行

先启动连接独立测试库的 `MaterialClient.Urban` 客户端，启用诊断口（`MinimalWebHost__EnableOnStartup=true`）并通过 `POST /api/settings` 将地磅切换为 `ScaleType.TestMode (2)`。出现授权提示时由用户手动完成授权，等待称重服务就绪后再运行。指定客户端**实际打开**的测试库和日志目录。探针只读数据库，客户端会正常写入测试记录。

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-urban-weighing-cycles/scripts/Invoke-FevUrbanWeighingCycles.ps1 -Database <工作库绝对路径> -LogRoot <日志目录绝对路径> -Cycles 100 -Fast
```

每次使用唯一车牌，注入稳定重量后观察 `WeighingRecords` 与 `UrbanWeighingExtensions` 新行，再注入离磅重量 `0.3t`。观察到离磅状态后立即进入下一周期（`-Fast` 或默认 `departureSettleMs=0`），最大化暴露后台 `WeighingCycleRecoveryWorker` 与 `PollingBackgroundService` 的写锁重叠。全部周期结束后额外等待 10 秒以采集延迟 Recovery 重试日志，再复查全表记录。

`pass` 表示全部周期请求和离磅均完成，每个车牌对应正确重量与 Urban 模式（`201`），不同 `CycleId` 各有且只有一行 `WeighingRecords` 与 `UrbanWeighingExtensions`，观察窗无 `SQLite Error 5 / SQLITE_BUSY` 锁错误且无未恢复异常。`fail` 表示实测缺单、重复、数据不符、扩展缺失或观察到锁错误。`blocked` 表示前置未满足或证据采集失败。

Run 写入 `runs/<yyyy-MM-ddTHHmmss>/`，保存 `summary.json`、`http.json`、`log-excerpt.txt`、`manifest.yaml` 与 `report.md`。P3 由用户判定。
