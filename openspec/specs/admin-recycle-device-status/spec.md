# admin-recycle-device-status Specification

## Purpose
TBD - created by archiving change add-recycle-business-persistence. Update Purpose after archive.
## Requirements
### Requirement: 独立 Recycle 在线列表
Admin SHALL 提供独立 Recycle 设备在线页面、查询入口和权限；SHALL 按 ProId 和产品归属查询，SHALL NOT 与 Urban 共用混合 PageList。

#### Scenario: 双产品并存
- **WHEN** Admin 中存在 Urban 5001 与 Recycle 5020 设备
- **THEN** Recycle 页面仅返回授权项目的 Recycle 设备，Urban 原列表不混入 Recycle

### Requirement: 真实心跳判定
Recycle 在线状态 SHALL 基于可信心跳的服务端接收时间及独立配置的超时阈值；无心跳 SHALL 显示未知，超时 SHALL 显示离线，授权有效 SHALL NOT 等同在线。

#### Scenario: 心跳超时
- **WHEN** 设备最近心跳距当前时间超过 Recycle 配置阈值
- **THEN** 独立页面显示离线与最近心跳时间，不改变 Urban 的在线判定

### Requirement: 在线状态访问控制
在线状态查询 SHALL 校验 Admin 权限和 ProId 范围，SHALL NOT 返回授权令牌或激活码。

#### Scenario: 越权查询
- **WHEN** 无目标项目权限的用户请求设备状态
- **THEN** 拒绝访问，不泄露设备状态或凭据

