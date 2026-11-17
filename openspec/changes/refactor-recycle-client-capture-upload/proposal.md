## Why

`MaterialClient.Recycle` 仍按「工控填业务表单 + 直连市平台 §2.2/§2.3」演进，与已确认职责（Web 管表单、工控只采毛重/车牌/照片、第一跳上我方平台）冲突。Recycle 未正式发布，无兼容性约束，应一次性改成与 `MaterialClient.Urban` 同构的采集上传端。

## What Changes

- **BREAKING**：`RecycleModeFormView` / `RecycleWeighingDetailViewModel` 去掉供应商、材料、单价、销售合同号等业务录入与完成校验；保留车牌、毛重与现场照片采集路径。
- **BREAKING**：停用客户端直连市平台主路径（`RecycleDataSyncService` / `IRecycleDataApi` / HMAC 默认不再上报）；市平台第二跳改由我方平台侧完成（本单不实现 Worker）。
- 新增「第一跳」上传：对齐 Urban 的本地落库 → 调我方平台接收 API → 记同步状态；载荷为车牌、毛重（及照片引用），不含合同/材料/供应商。
- 在 `UrbanManagement.XiaoShanResource` 增加工控接收 API，落点为运输清单（当前进程内 Store / 与既有 mock 闭环一致）；净重仍由平台用车辆池皮重计算。
- 收缩或旁路仅服务客户端表单的 `RecycleWaybillExtension` 单价/合同字段依赖；不在工控做收货确认业务表单。
- 不改 ProductCode **5020** / `WeighingMode.Recycle = 301`；不做 Web `Resource`→`Recycle` 工程改名；不改 MaterialClient.Urban / SolidWaste。

## Capabilities

### New Capabilities

- `recycle-client-platform-upload`: Recycle 工控第一跳上传我方平台（接收 DTO、上传服务、同步状态）

### Modified Capabilities

- `recycle-weighing-form`: 表单改为采集字段；移除供应商/材料/单价/合同必填与录入要求
- `recycle-platform-api-boundary`: 业务上报边界从市平台 HMAC 改为我方平台接收 API
- `recycle-data-sync`: 市平台同步不再作为产品主路径（默认关闭或移除注册）
- `recycle-weighing-service`: 完成/更新校验与持久化不再依赖供应商/材料业务主数据
- `xiaoshan-resource-web`: 增加工控过磅/运输清单接收 API，与运输清单列表同源

## Impact

- **子仓库**：`repos/MaterialClient`（`MaterialClient.Recycle`、`MaterialClient.Common.Recycle`、`MaterialClient.AttendedWeighing` Recycle 表单/VM）；`repos/UrbanManagement`（`UrbanManagement.XiaoShanResource` 接收 API + Store）。
- **分支**：Mode B — 自 `dev-recycle-resource-alignment` 切出同名 change 分支 `refactor-recycle-client-capture-upload`，合入目标为 `dev-recycle-resource-alignment`。
- **输入**：[`docs/2026-11-16-materialclient-recycle-resource-alignment/`](../../../docs/2026-11-16-materialclient-recycle-resource-alignment/00-调研总览.md)（含无兼容性 CONFIRMED）。
- **不动**：市平台 Worker 第二跳、BasePlatform 5020 注册细节（若已存在则沿用）、SolidWaste/Urban 产品路径。
