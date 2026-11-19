# recycle-urban-shaped-host Specification

## Purpose
TBD - created by archiving change refactor-recycle-urban-host-auth. Update Purpose after archive.
## Requirements
### Requirement: Recycle 宿主对齐 Urban 壳
`MaterialClient.Recycle` SHALL 使用与 `MaterialClient.Urban` 同构的独立称重宿主（`WeighingWindowBase` 顶栏、重量区、列表区），SHALL NOT 以 `AttendedWeighingWindow` + MaterialPlatform 登录作为产品主宿主。SHALL NOT 引用 `MaterialClient.Urban` 工程。

#### Scenario: 启动后进入 Recycle 称重主界面
- **WHEN** 授权有效或激活成功
- **THEN** SHALL 显示 Recycle 称重主界面
- **AND** SHALL NOT 显示 Material 登录窗
- **AND** SHALL NOT 展示「退出登录」或 Material「数据同步」入口

#### Scenario: 采集与上传主路径可用
- **WHEN** 工控完成称重采集（毛重、车牌、必要照片）
- **THEN** SHALL 能将采集结果上传至我方 Recycle Web 接收路径
- **AND** SHALL NOT 要求在工控填写合同号/材料/供应商

