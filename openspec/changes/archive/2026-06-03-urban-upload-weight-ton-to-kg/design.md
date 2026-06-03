## Context

- **客户端**：`WeighingRecord.TotalWeight` 与 Urban 有人值守 UI 使用**吨**；`MaterialMath.ConvertTonToKg` / `ConvertKgToTon` 已存在于 `MaterialClient.Common`。
- **服务端**：`UrbanWeighingRecord.TotalWeight` 与政府同步 `BuildGovPayload` 将同一字段作为 **kg** 使用（`TotalWeight > 4500` 判定大车）；Web 审批 `Index.cshtml` 标签为「重量（千克）」。
- **缺口**：`UrbanServerUploadService` 第 100 行 `TotalWeight = record.TotalWeight` 未换算。
- **异常检测**：客户端 `UrbanAnomalyDetection` 阈值为吨；服务端 `UrbanAnomalyDetectionOptions` 默认 30 / 2 与客户端数字相同，但 `ApproveAsync` 在 **kg** 存库上复检，量纲不一致。

## Goals / Non-Goals

**Goals:**

- 上云 `Receive` 请求的 `totalWeight` 为千克，与政府同步与 Web 管理端一致。
- 复用 `MaterialMath.ConvertTonToKg`，四舍五入到整数千克（与既有工具行为一致）。
- 服务端异常阈值配置改为千克，避免审批后误标异常。

**Non-Goals:**

- 不将本地 SQLite `WeighingRecord` 改为 kg 存储。
- 不修改地磅实时显示（仍为吨）。
- 不批量修正历史错误数据（单独运维/脚本）。
- 不改变 `GovSyncHttpClient` 载荷字段结构。

## Decisions

### D1: 换算仅在客户端上云边界执行

**选择**：在 `UrbanServerUploadService` 构建 `UrbanWeighingRecordSubmitDto` 时设置  
`TotalWeight = MaterialMath.ConvertTonToKg(record.TotalWeight)`。

**理由**：单一转换点；本地业务、列表、客户端异常检测仍用吨，与 Attended 主程序一致。

**备选**：服务端 `ReceiveAsync` 内检测数值 &lt; 100 则 ×1000 — 启发式易误判，拒绝。

### D2: 使用既有 `MaterialMath.ConvertTonToKg`

**选择**：不新增 helper；单元测试可针对 `UrbanServerUploadService` 或 `MaterialMath` 已有测试扩展。

**理由**：项目内已有标准换算与舍入规则（整数千克）。

### D3: 服务端 `UrbanAnomalyDetection` 默认值改为千克

**选择**：`UpperLimit` 默认 `30000`，`LowerLimit` 默认 `2000`（对应原 30t / 2t）；`UrbanManagement.App/appsettings.json` 与 `UrbanAnomalyDetectionOptions` 同步。

**理由**：`ApproveAsync` 与 `GovSync` 均按 kg 解释 `TotalWeight`；接收新记录时虽主要用 `input.IsAnomaly`，审批路径必须量纲正确。

### D4: 幂等重复 Receive 不更新重量

**选择**：保持现有行为——`ClientRecordId` 已存在时仅补附件关联，不覆盖 `TotalWeight`。

**理由**：避免重复上云覆盖人工审批结果；重量纠错走 Web/客户端编辑后 Pending 重传需另开 change（当前无此需求）。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 历史记录存为「吨数值」被当作 kg | 文档说明；运维按需 UPDATE；新上传记录正确 |
| 客户端 `IsAnomaly` 仍按吨计算，与服务端 kg 阈值独立 | 接收仍传 `IsAnomaly`；服务端审批复检用 kg 配置 |
| 极小重量（&lt;0.001t）换算为 0 kg | `ConvertTonToKg` 舍入；若 ≤0 服务端校验失败，保持 Pending |

## Migration Plan

1. 部署 MaterialClient.Urban（含换算）与 UrbanManagement（含 appsettings 默认）。
2. 可选：将错误历史记录的 `Urban_WeighingRecord.TotalWeight` ×1000；将待重传客户端扩展 `SyncStatus` 置 Pending。
3. 验证：上云一条约 8.5t 记录，服务端应为约 `8500` kg；政府同步 `carType` 为 Large（若 &gt;4500）。

## Open Questions

- 是否需要在 `UrbanWeighingRecordReceiveInputDto` XML 注释中标注 `kg`（实现阶段建议加上，无行为变化）。
