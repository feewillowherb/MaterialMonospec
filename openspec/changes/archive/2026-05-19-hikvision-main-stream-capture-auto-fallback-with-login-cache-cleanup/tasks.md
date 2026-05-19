## 1. 数据模型

- [x] 1.1 为 `BatchCaptureResult` 类添加 `FallbackUsed` 属性（默认 `false`）

## 2. 会话生命周期

- [x] 2.1 在 `HikvisionService` 中新增私有方法 `LogoutAndClearCache(HikvisionDeviceConfig config)`：从缓存获取 userId，调用 `NET_DVR_Logout`，移除缓存条目
- [x] 2.2 修改 `EnsureLogin`：调用 `Login` 前检查缓存 userId >= 0；如是，调用 `NET_DVR_Logout` 并驱逐，然后进行全新登录
- [x] 2.3 在 `CaptureJpegFromStreamBatchAsync` 主码流批量处理器的 `finally` 块中调用 `LogoutAndClearCache`
- [x] 2.4 在 `CaptureJpegBatchInternalAsync`（子码流路径）的 `finally` 块中调用 `LogoutAndClearCache`

## 3. 主码流抓拍降级

- [x] 3.1 在 `CaptureJpegFromStreamBatchAsync` 主码流批量处理器中：`CaptureJpegFromStream` 返回失败后，使用相同 config、channel、saveFullPath 和 jpegQuality 调用 `CaptureJpeg`
- [x] 3.2 降级成功时设置 `FallbackUsed=true`
- [x] 3.3 主码流和降级均失败时，合并两者的错误信息
- [x] 3.4 增加降级尝试日志：包含设备 IP、通道、主码流错误码和降级结果

## 4. 测试

- [x] 4.1 单元测试：主码流抓拍成功，不触发降级，`FallbackUsed=false`
- [x] 4.2 单元测试：主码流抓拍失败，降级成功，`FallbackUsed=true`
- [x] 4.3 单元测试：主码流抓拍失败，降级也失败，包含两者错误信息
- [x] 4.4 单元测试：`LogoutAndClearCache` 调用 `NET_DVR_Logout` 并移除缓存条目
- [x] 4.5 单元测试：`EnsureLogin` 缓存中存在有效 userId 时在重新登录前调用登出
- [x] 4.6 单元测试：抓拍过程中抛出异常时会话清理仍然执行
