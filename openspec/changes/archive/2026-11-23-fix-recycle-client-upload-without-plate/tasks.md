## 0. 随本 change 一并提交的在途实现

以下是子仓工作区里已完成但尚未提交的代码，原属 `fix-recycle-client-weighing-upload` 任务 1.2b，随本 change 提交。

- [x] 0.1 MaterialClient：称重确认后单独用 multipart 上传过磅相机照片；照片失败不回退同步状态。
- [x] 0.2 UrbanManagement：接收 DTO 移除 `WeighPhotoBase64` 与对应的保存逻辑；设备令牌校验覆盖 `POST /api/transports/{id}/photos`。

## 1. UrbanManagement 服务端

- [x] 1.1 `RecycleTransportRecord.Receive`：`plateNumber` 改为可空，空白规整为 `null`，非空时仍校验长度；去掉毛重非负校验；`MatchesSource` 把 `null` 与空白车牌视为相等。
- [x] 1.2 `RecycleDbContext`：`PlateNumber` 去掉 `IsRequired()`，新增 EF migration。
- [x] 1.3 `GET /api/transports`：传入 `plateNumber` 时不返回空车牌行。
- [ ] 1.4 `RecyclePersistenceRulesTests`：覆盖无车牌接收、负毛重接收、空车牌重传幂等、车牌筛选。

## 2. MaterialClient 客户端

- [x] 2.1 `RecycleTransportSubmitDto`：`PlateNumber` 改为可空；新增 `FromWeighingRecord(record, sourceClientId)` 生成请求，空白车牌输出 `null`。
- [x] 2.2 `WeighingRecord`：新增 `MarkRecycleSyncFailed()`，已同步记录不回退，不保存失败原因。
- [x] 2.3 `RecycleServerUploadService.SendAsync`：去掉空车牌跳过；用 `FromWeighingRecord` 生成请求；400 调用 `MarkRecycleSyncFailed`，响应体只写日志；401、网络异常、5xx 保持待上传。
- [x] 2.4 `FlushPendingAsync`：只取待上传记录，失败记录不再进入提交。

## 3. Recycle Web 运输清单

- [x] 3.1 `Transports.vue`：空车牌在列表与收货面板显示「—」，空车牌行仍有「收货」。
- [x] 3.2 重新构建 `wwwroot` 产物。

## 4. 验证

- [ ] 4.1 本地或 138：制造一条无车牌磅单，核对客户端已同步、Web 台账出现该行且车牌为「—」。
- [ ] 4.2 制造一条负毛重磅单：按原值进入台账。
- [ ] 4.3 断网后恢复：待上传记录在恢复后提交成功。
- [ ] 4.4 制造一条被服务端 400 拒绝的记录：客户端显示失败且不再重试。
