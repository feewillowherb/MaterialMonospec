## 1. UrbanManagement 服务与 API

- [x] 1.1 `IRecycleTransportAppService` 增加 `DeleteAsync`；`ReceivingTime` 非空时抛 `RECYCLE:TRANSPORT_RECEIVED`，否则 `DeleteAsync` 软删。
- [x] 1.2 `RecycleWebEndpoints` 注册 `DELETE /api/transports/{id:guid}`，成功返回 `204`。

## 2. Recycle Web 运输清单

- [x] 2.1 `Transports.vue`：未收货行显示「删除」；`ElMessageBox.confirm` 后调用 `DELETE` 并刷新列表；已收货无删除。

## 3. 验证

- [x] 3.1 运行 `openspec validate add-recycle-web-transport-delete --strict`
- [ ] 3.2 本地或 138：删除待收货行成功；已收货行无删除按钮且 API 拒绝