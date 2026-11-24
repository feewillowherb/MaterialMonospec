# fev-solidwaste-ten-weighing-cycles

通过本地诊断 API 驱动固废客户端连续完成十次上磅、判稳和下磅，核对工作库中每个周期的记录。实验观察日常写库路径，不注入外部 SQLite 写事务。自动匹配或轮询是否实际参与，以运行时日志为准。

## 运行

先启动连接测试库的 SolidWaste 客户端，启用诊断口和地磅测试模式。出现授权或登录提示时由用户手动完成，等待称重服务就绪后再运行。指定客户端**实际打开**的测试库和日志目录。探针只读数据库，客户端会正常写入测试记录。

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-solidwaste-ten-weighing-cycles/scripts/Invoke-FevSolidWasteTenWeighingCycles.ps1 -Database <工作库绝对路径> -LogRoot <日志目录绝对路径>
```

每次使用唯一车牌，注入稳定重量后观察新行，再注入离磅重量。观察到离磅状态并留出收尾时间后进入下一周期。最后复查全部记录，避免把迟到的重复写入漏掉。

`pass` 表示十次请求和离磅均完成，每个车牌对应正确重量与固废模式，十个不同 CycleId 各有且只有一行，观察窗无 SQLite 锁错误。`fail` 表示实测缺单、重复、数据不符或观察到锁错误。`blocked` 表示前置未满足或证据采集失败。结果仅覆盖这十次实际运行。

Run 写入 `runs/<yyyy-MM-ddTHHmmss>/`，保存 API 请求状态、逐周期记录、日志摘要和 P0–P2 结果。P3 由用户判定。

可传 `-Cycles 100 -Fast` 执行 100 次短间隔验证。此模式每 100 毫秒观察落库和离磅，确认离磅后立即进入下一周期。通过条件中的周期数随参数变化。
