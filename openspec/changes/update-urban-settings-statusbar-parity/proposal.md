## Why

MaterialClient.Urban 已与主应用共享 `MaterialClient.UI` 的 `SettingsDialog` 和 `DeviceStatusBar` 框架，但 Urban 仅注册 4 个设置分区（地磅、摄像头、车牌、系统），状态栏也只显示地磅、摄像头、车牌，而主应用有 7 个设置分区并显示打印机、音频、USB 摄像头等完整设备列表。现场部署与主应用使用相同外设时，Urban 操作员无法在城管变体中配置或查看这些设备，造成功能缺口与运维不一致。

## What Changes

- 将主应用的 7 个设置分区（地磅、称重、摄像头、车牌、系统、音频、打印机）在 Urban 中完整可用，分区内容与保存行为与主应用一致
- 将 Urban 设备状态栏的设备集合与主应用对齐（地磅、摄像头、USB 摄像头、打印机、音频、车牌识别）
- 抽取或复用主应用已有的 `ISettingsSection` 实现，避免 Urban 与主应用维护两套分区逻辑
- 更新 `settings-ui`、`device-status-bar`、`materialclient-urban-desktop` 规范，移除 Urban「精简子集」要求
- 确认 Urban ABP 模块已注册打印机、音频、称重相关服务，使设置加载/保存与状态查询可正常工作

## Capabilities

### New Capabilities

（无 — 本变更为既有能力的对齐，不引入新 capability 名称。）

### Modified Capabilities

- `settings-ui`: Urban 必须注册与主应用相同的 7 个设置分区；移除「Urban 不得包含打印机等不适用分区」的限制
- `device-status-bar`: Urban 设备状态栏必须与主应用显示相同设备类型集合
- `materialclient-urban-desktop`: 更新设备状态栏与系统设置相关需求场景，与主应用功能对等

## Impact

**受影响的代码（MaterialClient 子仓库）：**

- `MaterialClient.Urban/Views/Settings/` — 替换或删除 Urban 专用 Section，改为共享实现
- `MaterialClient/Views/Settings/` — 可能迁移 Section 至共享项目供两应用引用
- `MaterialClient.UI/` — 可选：新增 `Settings/Sections/` 存放共享分区实现
- `MaterialClient.Urban` / `MaterialClient` — `DeviceStatusBarViewModel` 初始化或设备发现逻辑对齐
- `MaterialClient.Urban` ABP 模块 — 确保打印机、音频、称重相关服务已注册

**OpenSpec：**

- `openspec/specs/settings-ui/spec.md`
- `openspec/specs/device-status-bar/spec.md`
- `openspec/specs/materialclient-urban-desktop/spec.md`

**非目标：**

- 不改变 Urban 无登录、顶栏精简、UrbanMode=201 等产品定位
- 不修改 Web 端 UrbanManagement
- 不重构主窗口四行布局或称重业务逻辑
