## Why

回收端只要产生了称重数据，磅单就必须进入 Recycle Web 台账，数据是否齐全、是否合理由 Web 端处理。平台侧没有「异常数据」这个概念。当前客户端在 `RecycleServerUploadService.SendAsync` 遇到空车牌直接跳过，服务端 `RecycleTransportRecord.Receive` 又强制要求车牌并拒绝负毛重，这些磅单永远不会上传。服务端返回 400 的拒绝目前还会被客户端每轮无限重试，界面上看不出失败。

## What Changes

- 客户端不再因车牌为空跳过上传；称重数据照常提交，车牌为空就按空值提交。
- 服务端接收只保留存储层面的限制（字段长度、小数精度、来源键）：车牌可为空，`PlateNumber` 列改可空；毛重为负也照常入库。
- 服务端以 400 拒绝的记录，客户端标记为同步失败并在列表显示，不再每轮重试；认证失败、网络错误和 5xx 仍照常重试。
- Recycle Web 运输清单与收货面板对空车牌显示「—」；车牌在收货面板中补选，见 `fix-recycle-web-receiving-plate-select`。
- 一并提交子仓里尚未提交的在途实现：客户端过磅照片 multipart 上传，以及服务端对应的 Base64 入参移除与照片端点的设备令牌校验（原属 `fix-recycle-client-weighing-upload` 任务 1.2b）。

## Capabilities

### New Capabilities

### Modified Capabilities

- `recycle-platform-api-boundary`：称重数据无条件上传、永久拒绝标记失败。
- `recycle-web-persistence-api`：空车牌运输单的展示与筛选。

## Impact

- `MaterialClient.Recycle`：`RecycleServerUploadService`、`RecycleTransportSubmitDto`。
- `MaterialClient.Common`：`WeighingRecord` 的同步状态写入。
- `UrbanManagement.Core`：`RecycleTransportRecord.Receive`、`RecycleTransportAppService.ReceiveAsync`、`RecycleDbContext` 及一条 EF migration。
- `UrbanManagement.Recycle`：`Transports.vue` 空车牌显示。
- 不改 `/api/transports/receive` 的字段名；只放宽服务端对接收内容的校验。
