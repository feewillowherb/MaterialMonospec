## Why

萧山上报配置目前挂在 Urban 主窗独立菜单「上报配置」，不在系统设置内，且客户端用独立表 `XiaoshanUploadConfigCaches` + `configVersion` 乐观并发，现场心智过重。需要收进系统设置「城管配置」，以**服务端配置为唯一权威**；客户端保存时推送，失败则舍弃本地编辑并回读服务端。

## What Changes

- 在共享 `SettingsWindow` 左侧导航**新增「城管配置」**，**置于导航末位**；**仅 MaterialClient.Urban** 可见。
- 将既有萧山上报编辑面（三模式、静态字段等）迁入「城管配置」；**移除**独立菜单「上报配置」与独立配置窗主路径。
- 系统设置「保存」时：将城管/萧山配置写入 **`Settings.UrbanSettingsJson`**（`UrbanSettings` 聚合），再经 **`ILocalEventBus`** 推送到服务端；ViewModel 不直调 Refit/API。推送结果写入应用日志。
- **一致性**：服务端为准。推送成功 → UI 与 `UrbanSettingsJson` 以服务端为准；**推送失败 → 舍弃本地编辑**，拉取服务端配置覆盖 UI 与本地 `UrbanSettingsJson`。
- **移除客户端 `configVersion` 相关行为**（UI 展示、冲突流）。
- **移除 `XiaoshanUploadConfigCaches`**（未上线迁移/实体已删）。新增 **`UrbanSettingsJson`** 列专存放 Urban 聚合配置（含萧山上报本地镜像）。
- **不做**：UrbanManagement 管理端改版；GovSync 实际上报改造；主程序/Recycle 增加城管配置。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `xiaoshan-upload-config`: 客户端入口改为系统设置「城管配置」；LocalEvent 推送；服务端权威且失败舍弃本地；去掉客户端 `configVersion` 与 `XiaoshanUploadConfigCaches` 依赖。

## Impact

- **Repos**: MaterialClient（`MaterialClient.UI` 设置导航/面板；`MaterialClient.Urban` 可见性、LocalEvent Handler、删除独立窗与 Cache 用法）。
- **可能触及**: 客户端 Write DTO 不再依赖 `expectedConfigVersion` 冲突 UX（若 API 仍要求字段，可传占位并由服务端既有逻辑处理，但客户端不据此做冲突合并 UI）。
- **集成分支**: `epic/xiaoshan-platform-upload`（不合 `main`）。
- **追溯**: Epic `xiaoshan-platform-upload-epic`；theme `xiaoshan-upload`。
