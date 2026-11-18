## Why

同回调单次入队与音柱播报隔离已经合并，但唯一在途建单任务仍可能跨越下磅重置，读取下一车的车牌，或把旧 RecordId 写回下一周期。Urban 下磅收尾失败还会残留旧 RecordId 和车牌缓存，可能阻止下一车建单。

依据：`docs/2026-11-18-weighing-kernel-reliability/03-FEV-跨周期串数据.md` 与 `06-异常注入与恢复调查.md`。它们是测试宿主中的受控复现，不代表现场有抓拍延迟或崩溃故障。Human 在该 topic 对话中已批准 Guid CycleId、旧任务隔离、异常记录与有限恢复，见 `04-已确认业务决策.md`；附件上传失败保留 Pending 的最新澄清优先。

## What Changes

- 每次称重周期分配 Guid CycleId，建单后关联 RecordId；重量、车辆信息和异步任务保持周期归属。
- 同周期最多创建一条记录，旧任务不能使用下一周期的信息或修改其状态。
- 周期已结束而尚未开始数据库创建的迟到任务直接结束；已提交记录保留原周期数据，允许不完整，在 ExtraProperties 标记异常。
- 下磅释放当前周期与旧记录收尾分离；旧记录收尾失败不阻止下一车，按固定 CycleId、RecordId 后台有限重试并保留诊断状态。
- 没有图片、车牌本身不阻止已存在记录按原同步流程处理；已有附件上传失败仍保留 Pending 重试。

## Capabilities

### New Capabilities

- `weighing-cycle-recovery`: 旧周期收尾的持久诊断与有界恢复。

### Modified Capabilities

- `attended-weighing`: 周期身份、同周期单次创建与跨周期状态隔离。

## Impact

- 实现仓库仅 MaterialClient：Common 称重编排、状态、建单服务；Common.Urban 收尾副作用；必要的恢复调度及测试。
- 使用记录现有 ExtraProperties 存储周期与恢复信息，原则上不新增数据库列、表或外键；服务端及同步协议不扩展。
- 保留音柱隔离、单回调单次入队、现行队列并发度及正常车牌改写规则。
- 不包括抓拍耗时诊断、SDK 请求关联改造、整体状态机重写、整段建单自动重试或附件上传失败策略变更。
