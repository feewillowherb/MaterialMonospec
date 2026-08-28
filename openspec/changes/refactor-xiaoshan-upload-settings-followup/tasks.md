## 1. 仅验收 UI → UrbanSettingsJson

- [x] 1.1 Common 静态扩展：核心 UI 字段 ↔ `ModesJson`；命名 record；UI 不得引用 Urban
- [x] 1.2 `XiaoshanUploadLocalConfig` 仅 `ModesJson`；`SaveAsync` → `ISettingsService.SaveSettingsAsync`
- [x] 1.3 打开设置从 `UrbanSettingsJson` 还原；AccessCode 只读不入库
- [x] 1.4 验证：改核心字段 → 保存 → 再打开一致（**不做**同步到 UM 的验收）

## 2. 删除 MC 配置同步栈

- [x] 2.1 删除 LocalEvent / `XiaoshanUploadConfigSaveRequestedEventData` / handler
- [x] 2.2 删除 Facade、`XiaoshanUploadConfigClientService`、draft/snapshot、Refit 配置 Get/Write
- [x] 2.3 删除本地 `SettingsJson` 与 `XiaoshanUploadSettingsEnvelope`（MC/UM）
- [x] 2.4 删除 `XiaoshanUploadFieldMappingService`（MC/UM）及 skip log；UM 信封仅服务映射一并删除
- [x] 2.5 grep：MC 无配置同步死代码

## 3. 删除 UM 配置同步面（不验收客户端→服务端）

- [x] 3.1 删除 `IXiaoshanUploadConfigAppService` Get/Write 及 HTTP 暴露
- [x] 3.2 删除配置 Write DTO / `configVersion` 协议字段 / 管理端「上报配置」弹窗
- [x] 3.3 删除变更日志实体；migration `DropXiaoshanUploadConfig` 删表
- [x] 3.4 不编写、不执行「客户端配置同步到服务端」测试或联调清单

## 4. 分区导航 / 本地保存失败（已落地）

- [x] 4.1 分区 `IsVisible` 绑定 `SelectedSettingsSection`
- [x] 4.2 本地保存失败提示且不关窗

## 5. 验证

- [x] 5.1 编译 MaterialClient 与 UrbanManagement（配置同步 API 应已不存在）
- [x] 5.2 冒烟：mapper 单测 round-trip 核心字段；未跑完整 Avalonia 设置窗
