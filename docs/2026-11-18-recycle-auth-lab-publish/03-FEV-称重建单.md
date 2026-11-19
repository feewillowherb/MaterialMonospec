# 03 FEV — 授权后的称重建单

> 环：`Unknown → Experiment → Evidence → Verdict`  
> 只回答「已授权的 Recycle 能否落一条资源化称重记录」。不是 Capability 交付，不表示上传到 Recycle Web 已通过。

## 1. 问题

已完成 5020 在线激活并进入称重主窗之后，诊断口注入一次稳定重量，能否写出一条 `WeighingMode = 301` 的 `WeighingRecords`，并出现在称重列表？

## 2. 实验

| 项 | 内容 |
|----|------|
| 进程 | `.build-verify/MaterialClient.Recycle/MaterialClient.Recycle.exe`，2026-11-18 11:25 启动 |
| 库内设置 | `Settings.ScaleSettingsJson` 的 `ScaleType=2`（测试模式），`DefaultWeighingMode=301` |
| 注入 | `POST http://localhost:9960/api/lpr/test-plate` 车牌 `浙A FEV01`；`POST /api/scale/weight` 重量 `1.25` |
| 判别 | 日志出现 `Created weighing record`；表中新增 1 行且 `WeighingMode=301`；主窗列表从 0 条变为 1 条 |

启动前库内 `WeighingRecords` 为 0 行。本次启动日志没有 `Truck scale serial port opened`，地磅按测试模式起来。

## 3. 证据

日志 `repos/MaterialClient/.build-verify/MaterialClient.Recycle/Logs/2026/11/18/MaterialClient.Recycle-20261118.log`：

- 11:25:53 测试车牌与 `1.25 t` 注入成功
- 11:25:53 进入 `WaitingForStability`（0.810 t）
- 11:25:57 `Weight stabilized (status transition)`，重量 1.250 t
- 11:25:57 `Created weighing record successfully, ID: 1, Weight: 1.25t, PlateNumber: 浙A FEV01`
- 同一秒：`Recycle 上传请求已收到 WeighingRecordId=1；我方 Recycle receive API 尚未接入`

库：`WeighingRecords` 一行，`Id=1`，`TotalWeight=1.25`，`PlateNumber=浙A FEV01`，`WeighingMode=301`。

主窗「资源化利用厂称重系统」列表：`共 1 条`，车牌 `浙A FEV01`，`1.25 吨`，状态「正常」，上传时间为空。

## 4. Verdict

`FEASIBLE`：授权后的 Recycle 称重主链可以用地磅测试重量生成并展示一条资源化称重记录。

未覆盖：真实 COM 口地磅、摄像头抓拍、上传到 Recycle Web。上传时间仍为空，对应任务 5.3。本结论不是 ICD `PASS`。
