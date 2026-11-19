# MaterialClient.Recycle 客户端重构

知识状态：INFERRED（目标行为已 CONFIRMED；具体类拆分与是否复用 Urban 窗体仍 PENDING_VALIDATION）。

## 目标

把 `MaterialClient.Recycle` 从「称重 + 业务表单」改成与 `MaterialClient.Urban` 同构的**采集上传端**：

- 采集**毛重**、车牌，以及称重流程需要的**现场**照片（皮重在 Web 车辆信息池；净重由平台计算；上传结果归入 Web **运输清单**；见 [`04-业务闭环.md`](04-业务闭环.md)、[`05-生产管理与运输清单页面.md`](05-生产管理与运输清单页面.md)）。
- 把采集结果上传到我方平台（见 [`03-urbanmanagement-recycle实现.md`](03-urbanmanagement-recycle实现.md)）。
- **不再**在客户端填合同号/材料/供应商/收货凭据；这些在 Web **运输清单**补全。**不**维护车辆皮重、不算净重。

ProductCode 保持 **5020**，`WeighingMode.Recycle = 301`。英文工程名保持 `MaterialClient.Recycle` / `MaterialClient.Common.Recycle`。

## 现状（要改掉的形态）

| 区域 | 现状 | 证据 |
|------|------|------|
| 称重明细表单 | 车牌 + 供应商 + 材料名称 + 销售合同号；保存前强制选供应商和材料 | `MaterialClient.AttendedWeighing` 的 `RecycleModeFormView.axaml`、`RecycleWeighingDetailViewModel` |
| 主程序外壳 | 独立项目 `MaterialClient.Recycle`，主窗仍是最小状态壳，文案指向 §2.2 直连上报 | `RecycleMainWindow` / `RecycleMainWindowViewModel` |
| 本地扩展 | `RecycleWaybillExtension` 存单价、销售合同号、收货时间，服务 §2.2 | `MaterialClient.Common.Recycle` |
| 同步 | `RecycleDataSyncService` 等按历史方向偏向市平台 HMAC / §2.2 | `MaterialClient.Recycle/Services` |
| 对照参考 | Urban 工控端上传我方平台：`IUrbanManagementApi` → `/api/app/urban-weighing-record/receive`，由 `UrbanServerUploadService` 等驱动 | `MaterialClient.Urban` |

历史提案 [`docs/SyncDoc/2026-07-09-recycle-client-proposal-draft.md`](../SyncDoc/2026-07-09-recycle-client-proposal-draft.md) 仍按「表单在客户端 + 直连市平台」写；本 Topic 的职责与上传链路 **取代** 该方向。

## 重构范围

### 界面与流程

1. **去掉业务表单控件与校验**  
   供应商、材料名、销售合同号的录入/新增对话框不再作为工控必填路径。车牌与**毛重**（及照片）保留。
2. **对齐 Urban 采集体验**  
   有人值守称重仍可用 Attended 流程，但明细区行为应对齐 Urban：现场采集，不维护主数据。是否直接复用 `UrbanAttendedWeighingWindow` 未定。
3. **主窗从「§2.2 管线看板」改为采集主界面**  
   启动授权/登录后进入可称重、可查看本地待上传队列的界面，而不是只显示市平台同步状态行。

### 上传

1. **第一跳：只上我方平台**  
   新增或改造上传服务，行为对齐 `UrbanServerUploadService`：本地落库 → 调用 UrbanManagement 侧 Recycle 接收 API → 记录同步状态。
2. **删除或降级客户端直连市平台**  
   `RecycleDataSyncService` / HMAC Handler 等「工控 → 杭州市接口」路径不再作为主路径；市平台由我方平台第二跳完成。
3. **本地字段**  
   `RecycleWaybillExtension` 中仅服务客户端表单的字段可收缩或改为由平台回写/组装；具体列变更另开 OpenSpec。

### 不做

- 不在客户端实现车辆管理、合同管理 Web 页。
- 不把 ProductCode 改成 5041（5041 是 Web）。
- 不在本重构里完成 Web 的 `Resource` → `Recycle` rename。

## 与 Urban 的对照

| 能力 | MaterialClient.Urban | 重构后 MaterialClient.Recycle |
|------|----------------------|-------------------------------|
| 产品码 | 5001 | 5020 |
| 现场采集 | 视城管产品而定 | **毛重**、车牌、照片；净重不在工控算 |
| 业务主数据 | 不在工控维护城管项目主数据 | 不在工控维护供应商/材料/合同 |
| 上传第一跳 | UrbanManagement 接收 API | UrbanManagement.Recycle（我方平台）接收 API |
| 上传第二跳 | 城管/政务通道在平台侧 | 杭州市资源化利用厂接口 V1.0 在平台侧 |

## 建议实施切片（非 tasks 勾选）

1. 明确 Recycle 接收 DTO 与 Urban `receive` 的差异（字段表另开）。
2. 去掉 `RecycleModeFormView` 中供应商/材料/合同录入，改采集校验。
3. 接入「上传我方平台」服务，替换直连 §2.2 主路径。
4. 联调：本地称重 → 我方平台可见 →（平台侧）再测市接口。

进入代码前须 OpenSpec change + Human `APPROVED`。
