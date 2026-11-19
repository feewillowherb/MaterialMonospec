# recycle-project-persistence Specification

## Purpose
TBD - created by archiving change add-recycle-business-persistence. Update Purpose after archive.
## Requirements
### Requirement: 独立持久化和审计
系统 SHALL 使用 Recycle 独立表、DbContext 和迁移，同库同表，以 Guid 为新表主键并复用 ABP 完整审计和软删除字段；SHALL NOT 引入 PlantId 或照搬旧 Material 模型。

#### Scenario: 数据库升级
- **WHEN** 在已有 Urban 数据库执行 Recycle 迁移
- **THEN** 新增 Recycle 表且旧 Urban 业务数据不变，新记录含审计字段并可在重启后查询

### Requirement: 按 ProId 授权隔离
所有 Recycle 数据 SHALL 归属必填 ProId；服务 SHALL 校验可信项目权限及关联对象同项目；关联 SHALL 仅使用逻辑 Id，不创建 FK 或 EF 关系。

#### Scenario: 跨项目访问被拒绝
- **WHEN** 项目 A 的用户提交项目 B 的业务 Id 或材料/公司 Id
- **THEN** 系统拒绝读取或修改且项目 B 数据保持不变

### Requirement: 同库多项目
系统 SHALL 支持每个 ProId 维护自身资料及业务，不分库分表。

#### Scenario: 同名资料共存
- **WHEN** 两个项目分别创建同名材料和公司
- **THEN** 各自可保存且查询仅返回授权项目数据

