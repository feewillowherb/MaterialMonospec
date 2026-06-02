## 1. 配置与入口准备

- [x] 1.1 在 `MaterialClient.Urban` 确认并补齐 `UrbanManagement:BaseUrl` 配置读取链路（appsettings、secret、模块读取）。
- [x] 1.2 在 Urban 项目中定义 MinimalWebHost 测试结果 DTO（至少包含 `Success`、`Message`、可选错误详情）。
- [x] 1.3 确认测试触发入口位置（调试入口或 UI 入口）并补充调用约定。

## 2. MinimalWebHostService 实现

- [x] 2.1 在 `MaterialClient.Urban` 新增 `MinimalWebHostService.cs`，按“直接复制功能”方式实现最小测试流程。
- [x] 2.2 在服务中实现对 UrbanManagement 的最小请求验证，并返回结构化结果。
- [x] 2.3 为服务增加异常处理与错误消息规范，保证不可达场景可诊断。
- [x] 2.4 通过 ABP 依赖注入注册并接入调用方，不引入跨项目复用抽象。

## 3. 验证与回归

- [x] 3.1 验证正常场景：`UrbanManagement:BaseUrl` 可达时返回成功结果。
- [x] 3.2 验证异常场景：地址错误或服务关闭时返回失败结果与错误消息。
- [x] 3.3 回归确认：不影响现有 Urban 称重主流程与上传流程。
- [x] 3.4 更新相关文档/注释，明确该能力为测试用途与复制实现策略。
