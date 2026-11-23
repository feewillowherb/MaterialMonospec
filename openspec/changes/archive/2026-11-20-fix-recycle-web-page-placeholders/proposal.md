## Why

车辆、合同和运输清单有一批格子写死文案，或保存后被丢掉。用户改完刷新仍看到原值。当前版本先让仍在使用的三页只显示已存储的事实，并拿掉没有落库的控件。

## What Changes

- 车辆列表显示 `CreationTime`。移除车辆状态列、筛选项和编辑框，移除批量导入，移除固定为「未上报」的市上报列。车辆上报动作保持现有行为。
- 合同上报状态显示三种中文：`None` 与 `Pending` 为「未上报」，`Succeeded` 为「已上报」，`Failed` 为「上报失败」。筛选使用原始枚举，「未上报」同时匹配 `None` 和 `Pending`。只有已记录的平台业务 `code` 200 才显示「已上报」。
- 移除合同 PDF 选择、只弹出文件名的「查看」和占位附件列，并清掉对应的页面状态。新建合同的生产方从空值开始。
- 运输列表显示 `WeighedAt`、`TransporterName` 和 `UnloadPoint`。列名使用「过磅时间」和「卸点」。状态按 `AwaitingTare` 与 `ReceivingTime` 显示「待补皮重」「待收货」「已收货」。移除旧阶段筛选、运输批量上报按钮和仅供该按钮使用的勾选列。
- 收货保存仍提交合同、明细和材料标识并走服务校验。卸点继续由服务按合同 `ShipAddress` 写入。成功和失败提示使用 HTTP 结果与错误体。手动过磅的车牌和毛重从空值开始。
- 生产管理保持当前版本隐藏：侧栏不出现该入口，`/productions` 回到车辆管理。日产量接口和页面文件保留，本变更不改其占位字段。
- 不在本变更接入附件文件，也不从运输记录推导车辆「运输中」。上报方向、照片前置和重试仍归 `add-recycle-web-platform-reporting`。

## Capabilities

### New Capabilities

### Modified Capabilities

- `recycle-web-persistence-api`: 车辆、合同、运输清单只展示已存储字段，并移除未落库控件。生产管理在当前版本保持隐藏。

## Impact

UrbanManagement Recycle 的页面行投影、车辆、合同和运输清单 Vue 页面。不新增表，不改迁移。日产量服务和市平台上报实现不在本变更内。
