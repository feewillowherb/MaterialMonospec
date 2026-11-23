## Why

无车牌或车牌识别错误的磅单现在也会进入运输清单，需要有人工纠正车牌的入口。收货面板目前不显示车牌，也没有任何修改方式。

## What Changes

- 收货面板显示当前车牌，未收货时可通过「修改」更换，已收货后只显示。
- 车牌只能从车辆管理中当前项目已启用的车辆里搜索选择，不能自由输入。
- 保存收货时一并提交车牌；服务端校验车辆存在，并用所选车辆刷新皮重、净重与运输人快照。
- 车辆搜索走 `GET /api/vehicles?plateNumber=`，只返回已启用的车辆。

## Capabilities

### New Capabilities

### Modified Capabilities

- `recycle-web-persistence-api`：收货面板车牌选择与车辆校验。

## Impact

- `UrbanManagement.Core`：`RecycleTransportCompleteDto`、`RecycleTransportAppService.CompleteAsync`、`RecycleTransportRecord`、车辆列表查询。
- `UrbanManagement.Recycle`：`RecycleWebEndpoints`、`Transports.vue` 及 `wwwroot` 产物。
- 不涉及市平台上报，不新增表字段，不改客户端。
