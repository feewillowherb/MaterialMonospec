## 为什么

MaterialClient.Urban 当前在授权检查失败（无 `license.urban`、无有效 JWT、无 `ProId`）时仍继续启动并进入称重主界面，导致现场误以为系统可用，但上传、项目关联与 SignalR 授权同步实际无法工作。生产部署应以有效项目授权为准入条件，在缺少有效 `ProId` 时明确中断启动并提示「软件未授权」。

## 变更内容

- **破坏性变更** 启动授权检查由「非阻塞」改为「阻塞」：JWT 验签失败、授权过期或无法解析 `proId` 时，不得打开称重主界面
- 新增未授权提示界面：显示「软件未授权」及 `license.urban` 部署指引，用户确认后退出应用
- 有效授权判定以启动时 JWT 校验结果为准（优先 `LatestJwtToken`，其次 `license.urban`），成功后才写入或覆盖 `LicenseInfo`（含 `ProjectId`）
- 所有构建配置（含 Debug）均强制执行启动门禁，不提供任何绕过开关
- 移除「授权失败继续启动」「不得显示授权对话框」等与上述策略冲突的既有行为

## 能力

### 新增能力

- `urban-license-startup-gate`：MaterialClient.Urban 启动时授权门禁——有效 JWT / `ProId` 校验、未授权对话框、中断主界面与设备管线启动

### 修改能力

- `materialclient-urban-desktop`：静态授权检查由非阻塞日志改为阻塞启动；允许显示未授权提示界面；授权成功仍为进入主界面的前置条件

## 影响

| 范围 | 说明 |
|------|------|
| **子仓库** | MaterialClient（`MaterialClient.Urban`、`MaterialClient.Common`） |
| **代码** | `MaterialClientUrbanModule.cs`、`App.axaml.cs`；可能新增未授权对话框 View / ViewModel |
| **规范冲突** | 替换 `materialclient-urban-desktop` 中「授权失败继续启动」「不显示授权 UI」等场景 |
| **运维** | 首次部署须将有效 `license.urban` 置于程序目录（或数据库中已有有效 `LatestJwtToken`） |
| **向后兼容** | **破坏性变更**：无授权文件的历史环境将无法直接进入称重界面 |
