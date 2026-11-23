## ADDED Requirements

### Requirement: 桌面称重持久上传与确认

客户端 SHALL 在称重保存后以受信设备身份上传到 Recycle Web，并在 Web 确认已持久化时更新平台接收状态。平台接收状态 SHALL 与市平台上报状态独立。

#### Scenario: 称重保存并入库

- **WHEN** 已授权设备保存有效称重
- **THEN** Web 在绑定项目内持久化一单，台账可见且公斤值保持不变

#### Scenario: 失败后重传

- **WHEN** 请求超时或客户端离线后重启
- **THEN** 待传称重保留并使用原来源键重试，同内容只产生一单

#### Scenario: 不可信来源

- **WHEN** 请求未授权或设备与绑定项目不符
- **THEN** 服务器拒绝写入，客户端不标记接收成功

### Requirement: 回收周期结束才进入待上传

回收宿主 SHALL 使用 `MaterialClient.Common.Recycle` 的称重副作用实现 `IUrbanWeighingRecordSideEffects`。称重周期结束且记录尚未被平台确认时，SHALL 将该记录标为待上传并请求上传。空副作用 SHALL NOT 成为回收宿主的实现。

#### Scenario: 周期结束

- **WHEN** 一条回收称重正常或异常下磅并完成周期
- **THEN** 该记录进入待上传并被安排上传

#### Scenario: 已确认不再标记

- **WHEN** 记录已经是平台确认状态
- **THEN** 周期结束不把状态改回待上传

### Requirement: 过磅照片独立上传

客户端 SHALL 先提交称重事实，确认后再把已保存的过磅相机照片（`AttachType.UnmatchedEntryPhoto`）以 multipart 文件发到 `/api/transports/{id}/photos`。照片上传 SHALL NOT 使用 Base64。照片失败 SHALL NOT 取消已确认的称重同步，并 SHALL 在后续轮询中单独重试。没有这张照片时 SHALL 不再重试。

#### Scenario: 照片上传失败

- **WHEN** 称重接收已成功，随后的照片请求失败
- **THEN** 本地同步状态保持已同步，下一轮只重试照片

#### Scenario: 没有相机照片

- **WHEN** 记录没有过磅相机照片
- **THEN** 称重事实仍提交，且不再尝试照片

#### Scenario: 已同步记录补照片

- **WHEN** 记录已同步、本地有过磅相机照片、且照片尚未上传成功
- **THEN** 只向原运输单上传照片文件，不因照片失败新增单据或改回待上传

### Requirement: 设备令牌校验使用工作单元

设备接收的项目查询 SHALL 在工作单元内执行。查询基础设施失败时 SHALL 记录警告。凭证不匹配时 SHALL 拒绝写入。

#### Scenario: 有效设备令牌

- **WHEN** 令牌的项目和机器码与绑定的 5020 项目一致
- **THEN** 接收继续进入保存，而不是因为缺少工作单元被拒绝
