# PRD：MaterialClient.Urban 城市管理称重桌面端

**Epic ID**: `materialclient-urban-epic`  
**版本**: 0.2  
**状态**: 规划完成，待 OpenSpec 衔接  
**影响子仓库**: MaterialClient（新桌面端 `MaterialClient.Urban`）、UrbanManagement

---

## 1. 背景与问题

MaterialClient 面向工业材料称重，具备运单匹对、实时授权、多页面 UI 等能力。城市管理场景（UrbanManagement）需要 **UrbanMode = 201 专用桌面端**：在**单一称重界面**内完成采集与列表查看，将 **WeighingRecord** 上报服务端，**不**做运单匹对、**不**提供登录页与授权页；静态授权文件在**启动时后台校验**（首期仅日志占位）。

UrbanManagement 需掌握各采集端的**设备状态、软件运行状态与错误日志**。

**UI 布局草稿**：`repos/MaterialClient/MaterialClient.Demo/Views/WeighingSystemWindow.axaml`（详见 `ui-layout-reference.md`）。

## 2. 目标用户与场景

| 角色 | 场景 |
|------|------|
| 现场称重操作员 | 打开应用即进入唯一主界面，查看实时重量与历史称重记录 |
| 平台运维 | 在 UrbanManagement 查看设备在线/异常、客户端版本与错误日志 |
| 开发/集成 | ProductCode 5030、WeighingMode 201 标识 Urban 产品线 |

## 3. 产品目标

1. 新增 **MaterialClient.Urban** — **UrbanMode = 201 专用 Avalonia 桌面应用**（非 Generic Host / 非 headless），配置体系与 MaterialClient 类似。
2. **仅一个主界面**（称重系统窗），**无登录页、无授权页**；启动后直接显示主窗口。
3. 仅处理 **WeighingRecord**，**不**配对 waybill。
4. 上传称重记录至 **UrbanManagement**。
5. **ProductCode = 5030**、**WeighingMode = 201（UrbanMode）**。
6. 静态授权：启动时读文件 + 日志占位，**无授权相关 UI**。
7. UrbanManagement 接收设备/软件状态与错误日志。

## 4. 非目标（Out of Scope — 首期）

- 多窗口导航、登录 Window、授权配置 Window
- 用户登录、Session、Token 刷新、实时授权 API 轮询
- 静态授权文件完整加解密 UI 或签名校验实现（仅后台日志）
- Waybill 同步、匹对、推荐、SolidWaste 等 MaterialClient 专有流程
- 上传除 WeighingRecord 以外的实体

## 5. 功能需求

### FR-1 桌面端与配置

- **FR-1.1** 新增 `MaterialClient.Urban` Avalonia 可执行项目，引用共享 Domain/Application/Infrastructure。
- **FR-1.2** 默认 **ProductCode = 5030**、**WeighingMode = 201（UrbanMode）**。
- **FR-1.3** 主界面布局以 `WeighingSystemWindow.axaml` 为草稿落地（标题栏、重量区、记录列表、照片侧栏、设备状态栏）。
- **FR-1.4** 配置：UrbanManagement 基址、设备 ID、授权文件路径、上传重试等。

### FR-2 授权（静态文件，无 UI）

- **FR-2.1** 应用启动时（`App` / 模块初始化）读取 `Urban:LicenseFilePath`。
- **FR-2.2** 缺失或不可读 → Error 日志；存在 → Information 日志。
- **FR-2.3** **不**提供授权页面；**不**在每次上传时做实时授权。

### FR-3 称重与数据范围

- **FR-3.1** 仅 **WeighingRecord**；**不**调用 waybill 匹对。
- **FR-3.2** 记录携带 ProductCode 5030、WeighingMode 201。
- **FR-3.3** 主界面列表绑定本地记录；称重完成后上传 UrbanManagement。

### FR-4 上传（客户端）

- **FR-4.1** REST 上传 WeighingRecord DTO。
- **FR-4.2** 请求含 DeviceId、ClientVersion 等元数据。

### FR-5 UrbanManagement

- **FR-5.1** 接收并持久化 WeighingRecord。
- **FR-5.2** 设备心跳/状态 API。
- **FR-5.3** 错误日志 API。
- **FR-5.4** 管理端可查询设备与日志。

## 6. 非功能需求

| 类别 | 要求 |
|------|------|
| UI | 单主窗口；Avalonia + ReactiveUI；与 MaterialClient 视觉风格一致（Demo 草稿） |
| 可靠性 | 上传失败重试 |
| 安全 | 无登录 UI；静态授权后台占位 |
| 部署 | 独立安装包，与 MaterialClient 主程序分离 |

## 7. 成功标准

- [ ] 启动后**直接进入**唯一主界面（无登录/授权页）。
- [ ] 界面布局与 `WeighingSystemWindow` 草稿一致（允许精简顶栏菜单）。
- [ ] 产生 UrbanMode 称重记录并上传成功。
- [ ] 底栏设备状态可见；UrbanManagement 可查设备与错误日志。
- [ ] MaterialClient 主程序无回归。

## 8. 假设与依赖

- Demo 中 `WeighingSystemWindow` 可迁移为 Urban 正式 View + ViewModel。
- 共享 `WeighingRecord` 实体与称重设备基础设施。

## 9. 开放问题

| ID | 问题 | 状态 |
|----|------|------|
| OQ-1 | 上传实时 vs 批量？ | 建议：异步单次 + 重试 |
| OQ-2 | 称重触发方式？ | **已闭合**：主界面实时重量区 + 设备事件（非 headless） |
| OQ-3 | 设备 ID 来源？ | 配置 + 机器标识 |
| OQ-4 | 服务端表结构？ | 新建 `UrbanWeighingRecord`（slice 03） |

## 10. Epic 映射

见 `epic-traceability.md`。
