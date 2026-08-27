## 1. Settings UI — 城管配置

- [x] 1.1 `SettingsWindow` 导航插入「城管配置」为最后一项；仅 Urban 可见；默认仍选中地磅设置
- [x] 1.2 「城管配置」面板：三模式/静态字段；**无** `configVersion` UI；打开/刷新走服务端 Get
- [x] 1.3 确认主程序 / Recycle 无「城管配置」（`ShowUrbanConfigSettings` 依赖 UrbanMode + Facade，主程序无 Facade）

## 2. LocalEvent 推送与失败舍弃

- [x] 2.1 EventData `record` 承载待推送草稿（**不含** expectedVersion 语义）；禁止 tuple
- [x] 2.2 Save：脏则 `PublishAsync`；干净跳过；VM 不注 Refit
- [x] 2.3 Urban Handler：Write 服务端；成功刷新 UI；失败舍弃草稿 + Get 服务端覆盖 + 提示；`ILogger` 记结果；不回滚硬件设置
- [x] 2.4 可选：面板内「从服务器刷新」按钮

## 3. 移除 Cache / version / 独立入口

- [x] 3.1 删除 `XiaoshanUploadConfigCache` 实体/DbSet 及未上线的 AddXiaoshan* migrations；还原 ModelSnapshot
- [x] 3.2 移除客户端 `configVersion` 展示与冲突 UX；Write 占位字段按现 API 最小兼容（推送前 Get 取 expected）
- [x] 3.3 移除主窗「上报配置」菜单与独立 `XiaoshanUploadConfigWindow` 主路径

## 4. 收尾

- [x] 4.1 Epic 冒烟：编译 Urban/Main 通过；联调需现场验证推送成功/失败舍弃路径
- [x] 4.2 `Settings.UrbanSettingsJson` + `UrbanSettings` 聚合萧山本地镜像；变更留在 `epic/xiaoshan-platform-upload`
- [x] 4.3 迁移 `AddSettingsUrbanSettingsJson` 已添加
