## 1. 实施与联调

- [x] 1.1 MaterialClient：实现称重落盘后的持久待传和失败恢复，沿用稳定来源键。
- [x] 1.1a MaterialClient：回收周期副作用放在 Common.Recycle，并作为 `IUrbanWeighingRecordSideEffects` 替换空实现。
- [x] 1.2 UrbanManagement：设备令牌的项目查询在工作单元内执行；凭证不匹配仍拒绝写入。
- [x] 1.2b MaterialClient：称重确认后单独用 multipart 上传过磅相机照片；照片失败不回退同步状态，也不使用 Base64。
- [ ] 1.2a UrbanManagement：验证并发重传与内容冲突。
- [ ] 1.3 双端：在 138 通过桌面保存一笔已知重量，核对返回记录、Web 台账与持久化数据；验证断网重启、拒绝和重传。

## 2. 验收

- [ ] 2.1 在目标联调环境验证上述主路径与失败场景，保留业务记录及响应证据，目标 ICD L3。
