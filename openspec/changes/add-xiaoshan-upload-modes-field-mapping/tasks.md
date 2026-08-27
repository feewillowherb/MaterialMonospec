## 1. UrbanManagement — 结构化 envelope 与校验

- [ ] 1.1 定义 `XiaoshanUploadModesEnvelope` / `XiaoshanUploadSettingsEnvelope` 与 per-mode settings record；JSON 序列化 helpers；禁止 tuple
- [ ] 1.2 Write 路径解析/校验 `ModesJson`/`SettingsJson`；非法 schema 拒绝；合法则 canonicalize 再持久化（仍走 INT-002 version）
- [ ] 1.3 Get 路径：空/legacy `{}` materialize 默认（仅 Weighbridge enabled）

## 2. UrbanManagement — 字段映射 Service

- [ ] 2.1 实现 `IXiaoshanUploadFieldMappingService`：按 mode + 静态 envelope + 称重上下文 → `XiaoshanFieldMappingResult` record（含 SkippedFields）
- [ ] 2.2 实现 `buildLicenseNo` 通道变换 helper（Gate/Weighbridge 原值，Product `-02` 不重复拼）
- [ ] 2.3 单元测试：默认模式、多选、skip、Product 后缀

## 3. UrbanManagement — 管理端 UI

- [ ] 3.1 ProjectManagement 上报配置弹窗：三模式多选 + 分模式参数 + 静态字段；替换 raw JSON 为主路径
- [ ] 3.2 可选无源字段展示「无数据源，跳过」；保留高级 JSON 折叠/只读

## 4. MaterialClient.Urban — 配置与映射

- [ ] 4.1 DTO/缓存对齐 structured envelope（与 UM 同 schema）；配置窗结构化编辑
- [ ] 4.2 引入字段映射 Service（或共享逻辑）；上报路径（如 UrbanServerUpload）调用并打 skip 结构化日志
- [ ] 4.3 配置 UI 展示 skip 提示与 mode/version 并存

## 5. 收尾

- [ ] 5.1 双端联调：多模式保存/读回、version 仍递增、skip 日志可见
- [ ] 5.2 确认未实现 INT-004 旧端矩阵与 GovSync HTTP 全量；变更留在 `epic/xiaoshan-platform-upload`
