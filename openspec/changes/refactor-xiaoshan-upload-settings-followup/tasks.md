## 1. 仅验收 UI → UrbanSettingsJson

- [ ] 1.1 Common mapper：核心 UI 字段 ↔ `ModesJson`；命名 record；UI 不得引用 Urban
- [ ] 1.2 `XiaoshanUploadLocalConfig` 仅 `ModesJson`；`SaveAsync` → `ISettingsService.SaveSettingsAsync`
- [ ] 1.3 打开设置从 `UrbanSettingsJson` 还原；AccessCode 只读不入库
- [ ] 1.4 验证：改核心字段 → 保存 → 再打开一致（**不做**同步到 UM 的验收）

## 2. 删除 MC 配置同步栈

- [ ] 2.1 删除 LocalEvent / `XiaoshanUploadConfigSaveRequestedEventData` / handler
- [ ] 2.2 删除 Facade、`XiaoshanUploadConfigClientService`、draft/snapshot、Refit 配置 Get/Write
- [ ] 2.3 删除 `XiaoshanUploadSettingsEnvelope`、本地 `SettingsJson`
- [ ] 2.4 删除仅服务配置同步的 `XiaoshanUploadFieldMappingService`；上报流水仍引用则保留并注明
- [ ] 2.5 grep：MC 无配置同步死代码

## 3. 删除 UM 配置同步面（不验收客户端→服务端）

- [ ] 3.1 删除 `IXiaoshanUploadConfigAppService` Get/Write 及 HTTP 暴露
- [ ] 3.2 删除配置 Write DTO / `configVersion` 协议字段 / 管理端上报**配置**编辑 UI
- [ ] 3.3 删除仅服务 Write 的变更日志；配置实体无引用则 migration 删除
- [ ] 3.4 不编写、不执行「客户端配置同步到服务端」测试或联调清单

## 4. 分区导航 / 本地保存失败（已落地）

- [x] 4.1 分区 `IsVisible` 绑定 `SelectedSettingsSection`
- [x] 4.2 本地保存失败提示且不关窗

## 5. 验证

- [ ] 5.1 编译 MaterialClient 与 UrbanManagement（配置同步 API 应已不存在）
- [ ] 5.2 冒烟：仅核心字段写入客户端 UrbanJson 并读回
