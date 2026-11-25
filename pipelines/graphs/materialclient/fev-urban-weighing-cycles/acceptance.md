# Acceptance

| 等级 | 条件 |
|---|---|
| P0 | 专用 Urban 客户端诊断口可达，指定工作库可查询且为 UrbanMode + TestMode |
| P1 | 指定次数的车牌、上磅和下磅请求均成功，逐次观察到离磅 |
| P2 | 每个唯一周期各有一条正确的 `WeighingRecords` 与 `UrbanWeighingExtensions` 记录，Recovery 无失败，观察窗口没有 SQLite 锁错误 |
| P3 | 等待用户评审本次 Run |
