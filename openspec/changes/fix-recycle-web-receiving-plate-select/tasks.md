## 0. 随本 change 一并提交的在途实现

以下是 `UrbanManagement` 工作区里已完成但尚未提交的代码，随本 change 提交。

- [x] 0.1 `fix-recycle-web-transport-completion` 1.2b / 1.2c：收货页只改毛重、已收货只查看；运输清单按过磅时间（默认今天）、合同、公司、材料筛选。
- [x] 0.2 `add-recycle-web-transport-delete` 1.1 / 1.2 / 2.1：未收货行可确认后软删除，`DELETE /api/transports/{id}`。
- [x] 0.3 `wwwroot` 构建产物。

## 1. UrbanManagement 服务端

- [x] 1.1 `RecycleTransportRecord`：新增实例方法 `ChangeVehicle(RecycleVehicle)`，写 `PlateNumber` 并经 `ApplyTareSnapshot` 刷新皮重、净重、所有人与运输人。
- [x] 1.2 `RecycleTransportCompleteDto`：新增可空 `PlateNumber`。
- [x] 1.3 `RecycleTransportAppService.CompleteAsync`：车牌有变化且记录已收货时抛 `RECYCLE:TRANSPORT_RECEIVED`；按 `ProId + IsEnabled + PlateNumber` 查车辆，查不到抛 `RECYCLE:VEHICLE`；调用 `ChangeVehicle` 后保存。
- [x] 1.4 `IRecycleVehicleAppService.GetListAsync`：增加 `enabledOnly` 参数。
- [x] 1.5 `RecycleWebEndpoints`：`TransportEnrichWrite` / `ToComplete` 增加 `plateNo`；`GET /api/vehicles` 透传 `enabledOnly`。
- [ ] 1.6 `RecyclePersistenceRulesTests`：覆盖换车刷新快照、未知车辆拒绝、车牌不变、已收货拒绝、`enabledOnly`。

## 2. Recycle Web 收货面板

- [x] 2.1 `Transports.vue`：收货面板显示车牌；未收货时有「修改」，进入 `el-select`（`filterable` + `remote`），选项来自 `GET /api/vehicles?plateNumber=&enabledOnly=true`；已收货只显示。
- [x] 2.2 `enrich` 与 `openEnrich` 带入车牌，`saveEnrich` 仅在车牌变化时提交 `plateNo`，失败时展示响应体中的错误信息。
- [x] 2.3 重新构建 `wwwroot` 产物。

## 3. 验证

- [ ] 3.1 本地或 138：打开无车牌行的收货面板，搜索并选择车辆后保存，核对列表车牌、皮重、净重与运输人。
- [ ] 3.2 输入车辆管理中不存在的车牌：无可选选项，直接提交被 `RECYCLE:VEHICLE` 拒绝。
- [ ] 3.3 已收货行：车牌只显示，无「修改」。
