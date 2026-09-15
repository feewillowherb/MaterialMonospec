# Tasks: add-yaohua-tf1-continuous-query

**Mode B:** Apply 自 `dev-truck-scale-weight` 切出同名分支；验证后 squash 回 `dev-truck-scale-weight`（MaterialClient + MaterialMonospec）。  
**依据：** `docs/2026-09-15-truck-scale-transmission-format-refactor/`（06 §10 / §10.3.1）。

## 1. Branch

- [x] 1.1 确认 MaterialClient / MaterialMonospec 在 `dev-truck-scale-weight`；自该基线创建并切换分支 `add-yaohua-tf1-continuous-query`

## 2. Configuration

- [x] 2.1 `ScaleSettings` 新增 `string? CommunicationParameter`；文档注释标明不透明、由协议实现方解析
- [x] 2.2 提供切 TF 时的默认重置逻辑：耀华 → `"A"`；其它 ScaleType 默认 `null`/空（与 design D3 一致）
- [x] 2.3 Settings UI / ViewModel：切换 `TransmissionFormatType` 或保存路径调用重置；加载时缺省补耀华默认 `A`

## 3. Yaohua Type1 continuous-query protocol

- [x] 3.1 新增命名 `record` 承载皮/毛/净及 `AllValid`（禁止 tuple）；扩展 `ScaleProtocolContext`（或等价回调）以发布实时重量 + 可选分量
- [x] 3.2 实现 `Protocols/Yaohua/YaohuaTf1Protocol`：`OnDataReceived` 连续查询听流解析；**禁止**写串口查询命令取重
- [x] 3.3 `TruckScaleProtocolRouter`：`Yaohua × Type1` → `YaohuaTf1Protocol`；其它 ScaleType × Type1 仍 Unsupported
- [x] 3.4 门面接线：Type1 下持续 `WeightUpdates`；暴露分量只读表面（若采用）供称重消费

## 4. Weighing prefer / fallback

- [x] 4.1 在 `AttendedWeighingService`（或最小适配层）优先采用三分量（`AllValid`）；**任一无效**降级现网稳定窗口路径
- [x] 4.2 确认 Type1 降级路径与 Type0 稳定行为等价可用（同一会话实时流，无第二串口）

## 5. Settings UI Type1 for Yaohua

- [x] 5.1 `TransmissionFormatTypeOptions`：`ScaleType == Yaohua` 时包含 Type0+Type1；非耀华仅 Type0
- [x] 5.2 加载设置时允许保留耀华已存 Type1（移除 Phase 1「强制打回 Type0」逻辑）

## 6. Tests and verify

- [x] 6.1 Router：Yaohua Type1 → Tf1 协议；非耀华 Type1 → Unsupported 抛错
- [x] 6.2 协议/门面：连续查询听流解析样帧；断言生产路径无写查询帧（可测范围内）
- [x] 6.3 分量：三者全有效走优先；任一无效走稳定降级；`CommunicationParameter` 切 TF 重置为 `A`
- [x] 6.4 构建 MaterialClient 通过；勾选本 tasks；准备 squash 合入 `dev-truck-scale-weight`
