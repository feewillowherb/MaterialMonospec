## 0. Branch（Mode B）

- [x] 0.1 确认三仓位于 `dev-recycle-resource-alignment`；在 **MaterialMonospec**、**UrbanManagement**、**MaterialClient** 自 `dev-recycle-resource-alignment` 切出并切换到 `refactor-recycle-client-capture-upload`
- [x] 0.2 合入目标记为 squash → `dev-recycle-resource-alignment`（禁止直接入 trunk）

## 1. UrbanManagement — 接收 API

- [x] 1.1 在 `UrbanManagement.XiaoShanResource` 增加 `POST /api/recycle/weighing/receive`，请求/响应为命名 record
- [x] 1.2 接收逻辑：校验车辆池车牌 → 毛重 − 皮重 → 写入与运输清单同源 Store；缺皮重/未知车牌失败
- [x] 1.3 确认列表 API 能读到新接收记录；不要求合同/产品/凭证

## 2. MaterialClient — 表单采集化

- [x] 2.1 精简 `RecycleModeFormView`：移除供应商、材料、单价、合同控件（保留车牌等采集字段）
- [x] 2.2 更新 `RecycleWeighingDetailViewModel`：完成校验仅车牌 + 毛重；去掉供应商/材料必填
- [x] 2.3 更新 `IRecycleWeighingService` / `UpdateRecycleModeInput`：不再以单价/合同/供应商/材料为采集必填写入路径

## 3. MaterialClient — 平台上传

- [x] 3.1 新增平台接收 Refit（或等价）客户端与 `RecyclePlatform:BaseUrl` 配置
- [x] 3.2 实现上传服务（对齐 Urban：完成后天上传、失败可重试）；载荷不含业务主数据
- [x] 3.3 `MaterialClientRecycleModule` 注册平台客户端与上传服务；本地标记平台同步状态

## 4. MaterialClient — 停用市同步主路径

- [x] 4.1 默认 `RecycleSync:Enabled=false`；Enabled 为 false 时不注册/不启动市平台轮询
- [x] 4.2 完成路径不再依赖「待市平台上报」作为产品主状态

## 5. 验证

- [x] 5.1 本机：接收 API → 运输清单可见；毛重/净重正确（HTTP 联调；桌面完整完成链待人测）
- [x] 5.2 确认默认配置下无市平台 HMAC 请求（`RecycleSync:Enabled=false`，不注册市轮询）
- [x] 5.3 `openspec validate refactor-recycle-client-capture-upload --strict`
