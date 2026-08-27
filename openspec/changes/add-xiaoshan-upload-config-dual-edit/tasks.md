## 1. UrbanManagement — 权威配置模型

- [x] 1.1 新增按 `ProId` 绑定的萧山上报配置实体与 EF 映射/迁移
- [x] 1.2 定义 Get/Write 用命名 DTO/`record`（可扩展 envelope；禁止 tuple）
- [x] 1.3 实现 `IXiaoshanUploadConfigAppService`（或等价）：Get + Write，`[UnitOfWork]` 写入
- [x] 1.4 暴露 HTTP API（或确认 Blazor 直调 AppService 的管理端路径）并校验项目绑定

## 2. UrbanManagement — 管理端编辑

- [x] 2.1 在 ProjectManagement 或独立页提供查看/编辑权威配置 UI
- [x] 2.2 保存走同一 Write 路径；保存后读回校验

## 3. MaterialClient.Urban — 拉取与本地缓存

- [x] 3.1 在 `IUrbanManagementApi`（或等价）增加 Get/Write 配置客户端方法与 DTO
- [x] 3.2 实现 Service：拉取权威配置、写入本地对齐缓存（独立实体或明确配置节）
- [x] 3.3 设置/配置界面展示当前对齐配置；支持刷新从服务端覆盖本地对齐缓存

## 4. MaterialClient.Urban — 回写与生效语义

- [x] 4.1 支持本地草稿编辑；保存时调用服务端 Write
- [x] 4.2 成功：用服务端返回（或再 Get）覆盖对齐缓存并标为已对齐
- [x] 4.3 失败：保持草稿/未对齐，向用户提示，不得宣称已生效

## 5. 联调与收尾

- [ ] 5.1 双端联调：服务端改 → 客户端刷新；客户端改 → 服务端可见
- [x] 5.2 确认未实现 INT-002/003/004 范围（version 裁决、三模式映射、旧端矩阵）
- [ ] 5.3 子仓变更合入各自 `epic/xiaoshan-platform-upload`；主仓 OpenSpec 状态留在 Epic 集成分支
