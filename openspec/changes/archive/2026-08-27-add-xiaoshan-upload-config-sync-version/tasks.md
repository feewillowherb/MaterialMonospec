## 1. UrbanManagement — version 字段与 Write 冲突

- [x] 1.1 `XiaoshanUploadConfig` 增加 `ConfigVersion`；迁移默认 0；DTO Get/Write 带 `configVersion` / `expectedConfigVersion`
- [x] 1.2 Write 改为乐观并发：expected 匹配才落库并 +1；不匹配返回冲突结果（含权威快照），命名 record，禁止 tuple
- [x] 1.3 空配置 Get 返回 version=0；首次成功 Write → 1

## 2. UrbanManagement — 变更日志

- [x] 2.1 新增变更日志实体/表与迁移；Write 成功同 UoW 追加一行（source/actor/summary/version）
- [x] 2.2 提供按项目查询最近日志的 AppService API
- [x] 2.3 项目管理「上报配置」弹窗展示 version，并列出最近日志

## 3. MaterialClient.Urban — 缓存与回写

- [x] 3.1 本地缓存与 Refit DTO 增加 `configVersion`；Refresh 对齐 version
- [x] 3.2 Save 携带 `expectedConfigVersion`；成功用返回体对齐；冲突则刷新/应用快照并保持未对齐提示
- [x] 3.3 配置窗口展示 version 与对齐/冲突状态文案

## 4. 收尾

- [ ] 4.1 在 `epic/xiaoshan-platform-upload` 联调：服务端连写递增、客户端落后冲突、日志可查
- [x] 4.2 确认未实现 INT-003/004；子仓与主仓变更留在 Epic 集成分支
