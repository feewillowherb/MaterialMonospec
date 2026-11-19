## Why

萧山资源化利用网页端已有车辆管理与合同管理 mock。参考图 `_tmp/萧山资源化利用/1116` 还需「生产管理」与「运输清单」两页，才能对齐车运管理菜单闭环，并让后续工控上传 / 市平台上报有对应 Web 落点。

## What Changes

- 在现有 `UrbanManagement.XiaoShanResource` Vue 外壳侧栏增加「生产管理」「运输清单」，页签规则与车辆/合同一致（打开才出现、关闭即消失）。
- 新增生产管理列表页：筛选（标识编号、批次编号、生产日期、上报状态）、批量上报、表格列与合计行按参考图；数据走本站进程内 mock API，不落库、不调市平台。
- 新增运输清单列表页：筛选（车牌号、运输人、产品、运输状态、上报状态、出货/收货时间）、批量上报、表格列（含合同编号、产品净重、出货/收货凭证）与净重合计按参考图；数据同样为本站 mock API。
- 本单不实现工控接收、净重计算、真实附件上传、市平台 HMAC；批量上报仅更新 mock 上报状态。
- 不改城管 Admin、Gateway、MaterialClient、FdSoft.SSO；不改 ProductCode 5041。

## Capabilities

### New Capabilities

- （无）两页并入既有网页能力，不另起 capability 名。

### Modified Capabilities

- `xiaoshan-resource-web`: 侧栏与页签扩展为四页；新增生产管理与运输清单的 mock 列表、筛选、分页与批量上报行为

## Impact

- **子仓库**：`repos/UrbanManagement` — `UrbanManagement.XiaoShanResource`（Vue `client/`、Mock API、外壳菜单）。
- **分支**：Mode A — `add-xiaoshan-resource-production-transport`
- **输入**：`_tmp/萧山资源化利用/1116`；对齐笔记 [`docs/2026-11-16-materialclient-recycle-resource-alignment/`](../../../docs/2026-11-16-materialclient-recycle-resource-alignment/00-调研总览.md)
- **不动**：独立建表、工控第一跳、Worker 第二跳、Resource→Recycle rename（另 change）
