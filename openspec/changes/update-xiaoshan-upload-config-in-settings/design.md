## Context

Epic 分支上已有独立窗 + `XiaoshanUploadConfigCache` 表 + `configVersion` 客户端对齐流。用户要求改为：系统设置「城管配置」、LocalEvent 推送、**服务端唯一权威**、失败舍弃本地；并去掉客户端 version/Cache 表依赖；**不新增/不修改 EF Migration**。

**约束**

- ViewModel → Service；禁止 tuple，多值用命名 `record`
- 不新增、不改写客户端 Migration；不 Drop 已有 `XiaoshanUploadConfigCaches` 表（代码停用即可）
- 集成分支 `epic/xiaoshan-platform-upload`

## Goals / Non-Goals

**Goals:**

- 「城管配置」置底、仅 Urban
- 保存经 LocalEvent 推送到服务端，并打应用日志
- 推送失败 → 舍弃本地编辑 → Get 服务端覆盖 UI
- 移除客户端 `configVersion` 行为与 `XiaoshanUploadConfigCaches` 用法
- 移除独立「上报配置」菜单主路径

**Non-Goals:**

- 新增/修改/删除 EF Migration；物理 Drop `XiaoshanUploadConfigCaches`
- 强制删除服务端 `ConfigVersion` / ChangeLog 列或 API 字段（可保留服务端侧；客户端不消费）
- 管理端 UI / GovSync HTTP 全量
- 主程序 / Recycle 城管配置

## Decisions

### D1：导航 —「城管配置」末位、Urban 专属

`SettingsWindow` 导航末项；仅 Urban `IsVisible`；打开设置默认仍选中地磅设置。

### D2：面板字段 — 无 version UI

迁入三模式/静态字段等；**不展示** `configVersion`、对齐 version 文案、冲突 version 快照流。打开面板时 **Get 服务端**（或上次成功推送后的内存快照）；不以 Cache 表为源。

### D3：保存推送 — LocalEvent；失败舍弃

1. 系统设置 Save：硬件等照常 `SaveSettingsAsync`
2. 若城管配置脏：`PublishAsync(XiaoshanUploadConfigSaveRequestedEventData)`（`record`，含待推送草稿；**不含** expectedVersion 语义）
3. Urban Handler：Write 服务端；`ILogger` 记录成功/失败
4. **成功**：用服务端返回或再 Get 刷新 UI
5. **失败 / 未推送成功**：丢弃本地草稿，Get 服务端配置覆盖 UI，并提示用户；**不**保留未对齐草稿；硬件设置已保存不回滚
6. Settings VM 不注入 Refit

### D4：删除 `XiaoshanUploadConfigCaches`（未上线）

- 删除实体、DbSet、`AddXiaoshanUploadConfigCache*` migrations
- ModelSnapshot 回退至上一迁移（`AddWeighingRecordRemark`）状态
- 本地若曾 apply 过这两条 migration：删库重建，或手工 Drop 表并清理 `__EFMigrationsHistory` 对应行

### D5：去掉客户端 `configVersion`

- UI / EventData / 本地 mirror **不**依赖 version
- Write 若 API 仍有 `ExpectedConfigVersion`：传服务端可接受的占位（如 0 或省略策略按现 API），客户端**不做**冲突分支 UI；任意非成功 → 走 D3 失败舍弃 + Get 服务端

### D6：本地持久化 — `Settings.UrbanSettingsJson`

**决策**：`SettingsEntity` 新增列 `UrbanSettingsJson`，反序列化为 `UrbanSettings`（聚合 Urban 相关配置；当前含 `XiaoshanUpload` 本地镜像）。打开设置先读本地再 Get 服务端覆盖；保存写入该列后再 LocalEvent 推送；推送成功/失败后均以服务端结果回写该列。

**备选**：仅塞进 `SystemSettingsJson` → 与硬件杂项耦合；拒绝作为主路径。  
**备选**：仅内存 → 无法离线回看上次对齐配置；拒绝。

### D7：移除独立菜单窗

删除「上报配置」菜单与独立 Window 主路径。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 无离线草稿 | 产品接受：未推送成功即舍弃 |
| 服务端仍返回 conflict/version | 客户端统一当失败 → Get 覆盖 |
| DbSet 去掉后旧库留表 | 可接受；禁止为 Drop 加迁移 |
| 主程序误显城管配置 | IsVisible + 冒烟 |

## Migration Plan

1. UI + LocalEvent + 失败舍弃
2. 停用 Cache / 去掉 version UI
3. 删独立入口；编译 Urban/Main（无新 migration）
4. 回滚：Epic 分支 revert

## Open Questions

- OQ-1：面板是否保留显式「从服务器刷新」按钮？（建议保留）
- OQ-2：Write API 占位 `ExpectedConfigVersion` 具体传值与现 UM 实现对齐，apply 时看接口。
