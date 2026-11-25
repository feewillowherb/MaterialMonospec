# 08 - 缺失 LPR 图片异常原因细分现状与目标

创建日期：2026-11-25。生命周期：`ACTIVE`。知识状态：代码现状为 `CONFIRMED`；目标与范围已由用户提出（仅记录现状与 Goal，**暂不进 `docs/intake/` 与 `openspec/`**，不修改业务代码）。

---

## 1. 业务目标（Goal）

在称重记录异常体系中，**明确区分「没有上传 LPR 图片」与「车牌为空」**，并让 **Admin 运维人员在平台上直接看清没有 LPR 图片的具体原因**，例如：

- **LPR 设备离线**（网络不通 / 心跳超时）
- **LPR 登录失败**（账号密码错误、端口不通、SDK 登录失败及错误码）
- **LPR 未配置 / 未启用**
- **LPR 在线但本次未触发抓拍 / 回调无图**（如车辆未触发线圈、SDK 回调未返回图片）
- **本地已抓拍但图片上传失败**（附件上传接口失败/超时）

> 归属原则：与本 Topic 的统一运维原则一致，Urban（5001）与 Recycle（5020）共用同一套异常原因细分；对 Recycle Web（5334）不展示，仅面向 Admin 运维排查。

---

## 2. 现状核对（`CONFIRMED`）

| 环节 | 当前实现 | 问题与缺口 | 源码定位 |
|------|----------|------------|----------|
| **异常原因枚举** | `AnomalyReason` 仅 4 项：`CaptureFailure`（抓拍异常）、`EmptyPlate`（车牌为空）、`OverUpperLimit`（超上限）、`UnderLowerLimit`（低下限） | 颗粒度过粗，未细分 LPR 离线、登录失败、无图、上传失败等具体原因 | `repos/MaterialClient/src/MaterialClient.Common/Entities/Enums/AnomalyReason.cs:8-21` |
| **客户端判定逻辑** | `UrbanAnomalyDetector.GetAnomalyReason(..., bool hasLprAttachment = true)` 默认 `hasLprAttachment = true` | 仅传入单一布尔值 `hasLprAttachment`，无 LPR 运行状态上下文；且调用方若未显式传入 `hasLprAttachment = false`，缺图且无车牌的记录会直接落入 `EmptyPlate`（「车牌为空」） | `repos/MaterialClient/src/MaterialClient.Common/Services/UrbanAnomalyDetector.cs:43-64` |
| **服务端与 Admin 展示** | `UrbanWeighingRecord.AnomalyReason` 为可空 `string?`；`WeighingApproval.razor` 通过 `GetAnomalyReasonOptionsAsync()` 动态加载过滤下拉 | 服务端和前端本身支持字符串异常原因展示与筛选，但缺少客户端上报的「缺失图片具体原因/诊断明细」字段 | `repos/UrbanManagement/src/UrbanManagement.Core/Entities/UrbanWeighingRecord.cs:111-113`、`WeighingApproval.razor:103-108, 611-616` |

---

## 3. 后续设计阶段关键决策点（预留）

1. **原因分类 vs 诊断明细**：
   - `AnomalyReason` 主原因保持有限枚举便于 Admin 下拉筛选（如新增/细分：`LprOffline`「LPR离线」、`LprLoginFailed`「LPR登录失败」、`LprNoImage`「LPR未抓拍/无图」、`ImageUploadFailed`「图片上传失败」，与 `EmptyPlate`「车牌为空」严格分离）；
   - 另附可选诊断明细字段（如设备 IP、海康/臻识 SDK 错误码、登录失败原因），在 Admin 列表 Tooltip 或详情弹窗展示，方便运维直接定位。
2. **数据来源联动**：
   - 称重落库/上报时，从客户端 LPR 服务运行时状态（连接态、最近一次登录结果与错误码）实时采样快照，写入称重记录并随记录上报 Admin。
3. **1.0 / 2.0 兼容**：
   - `UrbanWeighingRecord.AnomalyReason` 已是字符串列，新原因值对 1.0 老客户端完全向后兼容（1.0 继续上报旧值，2.0 上报细分原因与诊断明细）。
