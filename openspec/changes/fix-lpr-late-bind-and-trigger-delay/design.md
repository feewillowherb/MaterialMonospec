## Context

`OnWeightStabilizedAsync` 当前顺序为：枪机抓拍 → `CaptureOnWeightStabilized`（`ContinuousShoot` 触发即返回）→ 立即 `CreateWeighingRecordAsync`。建单只读 `GetCurrentCycleLprImagePath()`；之后 LPR 事件仅写入状态路径，不写附件。下磅 `ResetCycle` 清空路径，晚到图永久丢绑。另：落盘/挂接仍受限 `UrbanMode || CameraConfigs.Count == 0`，非 Urban 且有相机时不会存 `AttachType.Lpr`。

本 change 覆盖：绑定与建单解耦、同周期有车牌优先、主动抓拍延迟、**全客户端 LPR 落盘与挂接**。约束：多值用命名 `record`（禁止 tuple）；ViewModel 不直访问 Repository；无明确要求不顺手清技术债。

## Goals / Non-Goals

**Goals:**

- 本周期「先有图后建单」与「先建单后有图」都能挂上 `AttachType.Lpr`。
- **全客户端（Standard / SolidWaste / Recycle / Urban）** 均落盘并绑定 `AttachType.Lpr`；非 Urban 客户端可不在业务 UI 中使用或展示该附件。
- 候选择优：`HasPlate=true` 压过 `HasPlate=false`；同级较新覆盖。
- `TriggerLprCaptureDelayMs` 持久化，并在 `TriggerLprCaptureForAllAsync` 于抓拍前生效。

**Non-Goals:**

- 不改审批人工换图 / 采纳流程。
- 不跨周期按车牌反查历史记录补绑。
- 不清理磁盘上被替换的旧 LPR 文件。
- 不要求 Recycle / SolidWaste / Standard 的称重/审批 UI 展示或消费 LPR 附件（数据层仍绑定）。
- 不改变枪机等非 LPR 附件的模式差异（如 UrbanPhoto vs UnmatchedEntryPhoto 的既有规则）；仅放宽 **LPR 落盘与挂接** 的模式门禁。

## Decisions

### D1 — 周期候选槽 + 双向绑定

用命名 record：

```csharp
public sealed record CycleLprCandidate(
    string RelativePath,
    bool HasPlate,
    DateTime ReceivedAt);
```

- `WeighingStateManager.TryAcceptLprCandidate`：无→接受；无车牌被有车牌升级；有车牌拒绝无车牌；同级接受较新路径。
- 建单：读当前候选挂接 `AttachType.Lpr`，**不限 WeighingMode / CameraConfigs**（去掉既有 `UrbanMode || CameraConfigs.Count == 0` 门禁）。
- LPR 落盘（Hikvision/Vz `TrySave*LprAttachment`）：有图即落盘，**不限模式**（去掉既有 Urban/无相机门禁）；无相机时的 `UnmatchedEntryPhoto` 双挂接仍仅在无 `CameraConfigs` 时生效。
- LPR 事件：接受成功且存在 `LastCreatedWeighingRecordId` → `UpsertLprAttachmentAsync`。

备选：仅在建单后轮询等待回调——拒绝，阻塞稳定路径且超时难定。

### D2 — Upsert 与异常重算

`UpsertLprAttachmentAsync(long weighingRecordId, CycleLprCandidate candidate)`：无则 Insert；有则替换路径；无 `CameraConfigs` 时同步维护 `UnmatchedEntryPhoto`；**仅当**存在 `UrbanWeighingExtension` 时重算 `IsAnomaly`。仅对本周期 `LastCreatedWeighingRecordId` 操作；`ResetCycle` 后不再补绑。

**Urban 异常时序**：因 `OnWeightStabilizedAsync` 先建单后触发主动 LPR，建单创建扩展时 MUST 推迟异常判定（`evaluateAnomaly: false`），不得因当时缺图写入 `CaptureFailure`。重算时机：（1）LPR Upsert 成功后（先同步识别缓存车牌再检测）；（2）周期重置（下磅）对上笔做最终重算（仍无 LPR → `CaptureFailure`）。

### D3 — 主动抓拍延迟

- `SystemSettings.TriggerLprCaptureDelayMs`：默认 `0`，保存 `Math.Max(0, value)`。
- `WeighingCaptureService.TriggerLprCaptureForAllAsync`：开关通过后、`TriggerCaptureAsync` 前 Delay；**仅**由 WeightStabilized 调用。
- UI：设置窗口「启用 LPR 主动抓拍」下一行延迟输入（建议 NumericUpDown 0–60000）。

### D4 — 可选时序微调（推荐）

`OnWeightStabilizedAsync` 可先建单再 `CaptureOnWeightStabilized`；仍必须保留补绑，因 SDK 回调异步。

### D5 — 主动抓拍阶段收敛

移除 WaitingForStability / OffScale 的 LPR 主动抓拍入口，避免与稳定抓拍延迟并行叠拍。异常下磅仍可触发枪机 `CaptureAllCamerasAsync`（与 LPR 无关）。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 下磅瞬间晚到回调串车 | `ResetCycle` 清空 Id 与候选；不做跨周期补绑 |
| 无车牌先落、有车牌后到 | 择优升级 Upsert |
| 延迟过大影响通行 | UI 上限 60s；默认 0 |
| 非 Urban 多存 LPR 磁盘/DB | 预期可接受；UI 不强制消费 |

## Migration Plan

- 旧 JSON 无 `TriggerLprCaptureDelayMs` → 默认 `0`。
- 无 DB schema 变更；部署后各模式新建记录开始带 LPR 附件。
- 回滚：恢复旧订阅、建单快照与 Urban/无相机落盘门禁即可。

## Open Questions

- 同级覆盖采用较新 `ReceivedAt`（已定）。
- `ResetCycle` 宽限窗首版不做；现场若丢图再议。
