# Admin UI surface expect（layout + pages）— lab 138

对照源码：`repos/UrbanManagement/src/UrbanManagement.Admin/Pages/AdminLayout.razor` 的 `_navItems`。  
目标：`http://192.168.3.138:5333`（经 Redis 会话登录后）。

## 0. 登录（P0）

| 断言 | 预期 |
|------|------|
| SSO | `POST http://192.168.3.135:8500/GetToken` 业务码 200 且有 Token（证据只记 hasToken） |
| Redis | SSO 写入 `FdSoftSSO:{userId}:{clientId}`（或证据注明由 GetToken 触发） |
| Admin | 浏览器持有 `UrbanAdmin.Session`；打开 `/` 非登录页 |

## 1. 布局壳

| 断言 | 预期 |
|------|------|
| 根 | `.layui-layout-admin` |
| 品牌 | 「萧山城管」/「对接平台」 |
| 侧栏 8 项 | 城管项目、资源化项目、称重记录、卡口进出、成品进出、异常审批、客户端日志、Recycle 设备在线 |
| 顶栏 | 「刷新」「退出」可见 |
| 多标签 | `.layui-tab-title` 存在 |

## 2. 各路由表面

| path | 标题 | 最低可见 |
|------|------|----------|
| `/` | 城管项目 | 状态筛选 + 搜索 + 表/空态 |
| `/recycle-projects` | 资源化项目 | 同上 |
| `/weighing` | 称重记录 | 车牌/项目筛选 + 表/空态 |
| `/checkpoint-passage` | 卡口进出 | 卡片 + 表/空态 |
| `/finished-product-passage` | 成品进出 | 卡片 + 表/空态 |
| `/weighing-approval` | 异常审批 | 卡片 + 表/空态；不点通过/驳回 |
| `/client-logs` | 客户端日志 | 卡片 + 表/空态 |
| `/recycle/device-status` | Recycle 设备在线 | 卡片 + 表/空态 |

## 3. 交互点检（只读）

侧栏切换、筛选或分页可见可点；可选只读照片/详情对话框开闭。禁止写库操作。

## 4. 非断言

正式口 191、Recycle 5334、业务行正确性（P3）。
