## ADDED Requirements

### Requirement: Admin 同时管理城管与 Recycle 项目授权
`UrbanManagement.Admin` SHALL 在同一管理端展示并管理 ProductCode **5001** 与 **5020** 的项目授权（项目名、对接码、授权到期、客户端在线等）。Urban 与 Recycle SHALL NOT 互斥。Recycle 授权行 SHALL NOT 导航至城管称重业务页作为地磅落点。

#### Scenario: 列表可见 5020
- **WHEN** BasePlatform 目录含 ProductCode 5020 的项目且拉取成功
- **THEN** Admin 项目管理 SHALL 展示该 Recycle 授权行
- **AND** 5001 行 SHALL 仍可同时存在

#### Scenario: Recycle 行不进 Admin 城管称重
- **WHEN** 操作员查看 Recycle（5020）授权行
- **THEN** SHALL NOT 以城管称重页作为该行的地磅数据入口
- **AND** Recycle 地磅数据落点仍为 Recycle Web
