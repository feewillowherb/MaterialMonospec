## 1. Core 出站模型与响应契约

- [x] 1.1 在 `UrbanManagement.Core` 新增 `GovSyncWeightPayload` record，字段与联调成功 payload 对齐，使用 `[JsonPropertyName]`（含 `snapImages` 为 `string?[]`、`deviceID` camelCase）
- [x] 1.2 更新 `GovResponseBase<T>`：为 `Code`/`Msg`/`Data` 保留 JSON 映射；移除或 `[JsonIgnore]` `Success`，避免误用
- [x] 1.3 将 `IGovSyncHttpClient.PostWeightAsync` 参数类型由 `object` 改为 `GovSyncWeightPayload`

## 2. GovSyncManager 载荷与成功判定

- [x] 2.1 重构 `BuildGovPayload` 返回 `GovSyncWeightPayload`：`snapImages` 使用 `ReadAttachmentFilesAsync` 结果（空为 `[]`），`carType` 为 `"大车"`/`"小车"`
- [x] 2.2 将 `ProcessRecordAsync` 成功判定改为 `response.Code == 200`（提取常量 `GovApiSuccessCode`）
- [x] 2.3 失败分支日志记录 `Code` 与 `Msg`；成功分支同样记录以便运维核对

## 3. Refit JSON 配置

- [x] 3.1 在 `UrbanManagementAppModule` 为 `IGovSyncHttpClient` 单独配置 `RefitSettings` + `System.Text.Json`（camelCase、`WhenWritingNull`）
- [x] 3.2 确认 `IBasePlatformProjectHttpClient` 注册不受影响

## 4. 单元测试

- [x] 4.1 添加测试：`GovResponseBase` 反序列化 `{ "code": 200, "msg": "操作成功", "data": null }` 后 `Code == 200`
- [x] 4.2 添加测试：`BuildGovPayload` 无附件时 `snapImages` 为空数组、`TotalWeight=5000` → `carType` 为 `"大车"`、`TotalWeight=1000` → `"小车"`
- [x] 4.3 添加测试：`ProcessRecordAsync` 在 `Code==200` 时设置 `SyncType=1`，在 `Code==500` 时设置 `SyncType=2` 并递增 `RetryCount`

## 5. 验证

- [x] 5.1 `dotnet build` UrbanManagement 解决方案通过
- [x] 5.2 `dotnet test` 相关测试项目通过
- [x] 5.3 使用 `_temp/post-weight-test.ps1` 联调确认政府平台仍返回 `code: 200`（可选，需内网；由用户在可访问政府 API 的网络下执行）
