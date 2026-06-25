# Urban AccessCode 迁移规范

## Purpose

优化 UrbanManagement 系统中的政府项目许可证数据语义，将 `BuildLicenseNo` 字段重命名为 `AccessCode`，并新增 `MachineCode` 和 `AuthToken` 字段以支持完整的授权信息存储和 BasePlatform JWT 委托集成。

## Requirements

### Requirement: GovProject 实体字段 AccessCode 替代 BuildLicenseNo

系统 SHALL 将 `GovProject.BuildLicenseNo` 字段重命名为 `AccessCode`，并新增 `MachineCode` 和 `AuthToken` 可空字符串字段，以优化数据语义并支持完整的授权信息存储。

#### Scenario: EF 实体字段定义

- **WHEN** UrbanManagement 启动并加载 EF Core 模型
- **THEN** `GovProject` 实体 SHALL 包含 `AccessCode` 字段（string?，最大长度 200）
- **AND** `GovProject` 实体 SHALL 包含 `MachineCode` 字段（string?，最大长度 200）
- **AND** `GovProject` 实体 SHALL 包含 `AuthToken` 字段（string?，最大长度 200）
- **AND** `AccessCode` 字段 SHALL 在数据库中有索引（用于查询性能）

#### Scenario: 数据库迁移脚本执行

- **WHEN** 执行 EF Core 迁移命令
- **THEN** 系统 SHALL 生成 SQLite 迁移脚本
- **AND** 脚本 SHALL 包含 `ALTER TABLE Gov_Project RENAME COLUMN BuildLicenseNo TO AccessCode` 语句
- **OR** 脚本 SHALL 包含 `ADD AccessCode` + `UPDATE AccessCode = BuildLicenseNo` + `DROP BuildLicenseNo` 序列
- **AND** 脚本 SHALL 包含 `ADD MachineCode` 和 `ADD AuthToken` 列语句
- **AND** 迁移 SHALL 保留现有数据（数据无损迁移）

### Requirement: GovProjectPullManager 映射 AccessCode 和 MachineCode

系统 SHALL 在从 BasePlatform PublicApi 拉取项目目录时，映射 `accessCode` 和 `machineCode` 字段到 `GovProject` 实体，不再读取 `buildLicenseNo` 字段。

#### Scenario: 拉取新项目时映射字段

- **WHEN** `GovProjectPullManager.PullAndInsertNewProjectsAsync` 从 BasePlatform 拉取新项目
- **THEN** 系统 SHALL 读取 `ProjectCatalogItemResponse.AccessCode` 字段
- **AND** 系统 SHALL 读取 `ProjectCatalogItemResponse.MachineCode` 字段
- **AND** 系统 SHALL 将 `AccessCode` 赋值给 `GovProject.AccessCode`
- **AND** 系统 SHALL 将 `MachineCode` 赋值给 `GovProject.MachineCode`
- **AND** 系统 SHALL 将 `AuthToken` 赋值给 `GovProject.AuthToken`

#### Scenario: 更新已存在项目时映射字段

- **WHEN** `GovProjectPullManager` 检测到已存在的 `GovProject` 且远程字段有变化
- **THEN** 系统 SHALL 调用 `ApplyRemoteFieldsIfChanged` 方法
- **AND** 该方法 SHALL 比较 `entity.AccessCode` 与 `remote.AccessCode`
- **AND** 如果值不同，该方法 SHALL 更新 `entity.AccessCode`
- **AND** 该方法 SHALL 比较 `entity.MachineCode` 与 `remote.MachineCode`
- **AND** 如果值不同，该方法 SHALL 更新 `entity.MachineCode`
- **AND** 该方法 SHALL 返回 `true` 表示有字段变更

#### Scenario: 脏数据修复脚本执行

- **WHEN** 管理员执行脏数据修复脚本
- **THEN** 系统 SHALL 查询所有本地 `GovProject` 记录
- **AND** 系统 SHALL 以 BasePlatform 拉取结果为准覆盖本地 `AccessCode`
- **AND** 系统 SHALL 记录修复的记录数量到日志
- **AND** 系统 SHALL 处理拉取失败的情况（记录警告日志）

### Requirement: 政府平台出站协议字段名称保持不变

系统 SHALL 在向政府平台发送数据时，使用 `buildLicenseNo` 作为协议字段名，但其值 SHALL 来自 `GovProject.AccessCode`。

#### Scenario: 政府出站序列化

- **WHEN** 系统构建政府平台出站 payload
- **THEN** payload 对象 SHALL 包含 `buildLicenseNo` 字段（字符串）
- **AND** `buildLicenseNo` 的值 SHALL 等于 `govProject.AccessCode`
- **AND** 协议字段名 SHALL 保持 `buildLicenseNo`（不改为 `accessCode`）

#### Scenario: 政府平台反序列化忽略大小写

- **WHEN** 系统接收政府平台返回的数据
- **THEN** 系统 SHALL 正确处理 `buildLicenseNo` 字段（无论大小写）
- **AND** 系统 SHALL 将该字段映射到内部 `AccessCode` 属性

### Requirement: BasePlatform PublicApi 响应字段扩展

系统 SHALL 要求 BasePlatform PublicApi 的 `ProjectCatalogItemResponse` 包含 `AccessCode`、`MachineCode` 和 `AuthToken` 字段。

#### Scenario: PublicApi 响应包含新字段

- **WHEN** 调用 BasePlatform `/Api/ProjectCatalog/ListProjects`
- **THEN** 响应对象 SHALL 包含 `accessCode` 字段（string）
- **AND** 响应对象 SHALL 包含 `machineCode` 字段（string）
- **AND** 响应对象 SHALL 包含 `authToken` 字段（Guid?）
- **AND** 这些字段 SHALL 可为 null（表示未设置）

### Requirement: Feature Flag 灰度控制

系统 SHALL 提供 `UseAccessCodeMigration` 特性标志，用于控制是否启用 AccessCode 映射逻辑。

#### Scenario: Feature Flag 启用时使用新字段

- **WHEN** `UseAccessCodeMigration = true`
- **THEN** `GovProjectPullManager` SHALL 映射 `accessCode` 和 `machineCode`
- **AND** 系统 SHALL 使用 `AccessCode` 字段进行业务逻辑

#### Scenario: Feature Flag 禁用时回退旧逻辑

- **WHEN** `UseAccessCodeMigration = false`
- **THEN** `GovProjectPullManager` SHALL 回退到映射 `buildLicenseNo`
- **AND** 系统 SHALL 保持向后兼容（仅在灰度期使用）

#### Scenario: Feature Flag 默认值

- **WHEN** 系统首次启动或配置缺失
- **THEN** `UseAccessCodeMigration` SHALL 默认为 `true`（新部署默认启用）
- **AND** 旧版本升级时可通过配置手动设置为 `false` 进行回滚

### Requirement: 数据验证与约束

系统 SHALL 对 `AccessCode`、`MachineCode` 和 `AuthToken` 字段施加适当的数据验证和约束。

#### Scenario: AccessCode 长度约束

- **WHEN** 设置 `GovProject.AccessCode` 属性
- **THEN** 值长度 SHALL 不超过 200 字符
- **AND** 超长值 SHALL 被截断或拒绝（根据配置）

#### Scenario: MachineCode 格式验证

- **WHEN** 设置 `GovProject.MachineCode` 属性
- **THEN** 值 SHALL 符合机器码格式（字母数字组合）
- **AND** 无效格式 SHALL 被拒绝并记录警告

#### Scenario: AuthToken GUID 验证

- **WHEN** 设置 `GovProject.AuthToken` 属性
- **THEN** 值 SHALL 为有效的 GUID 字符串（或 null）
- **AND** 无效 GUID SHALL 被拒绝并记录错误

### Requirement: 向后兼容与回滚机制

系统 SHALL 提供向后兼容机制，确保迁移过程中业务连续性。

#### Scenario: EF 兼容属性支持

- **WHEN** 旧代码访问 `BuildLicenseNo` 属性
- **THEN** 系统 SHALL 提供兼容属性（指向 `AccessCode`）
- **AND** 该属性 SHALL 标记为 `[Obsolete]` 警告使用新属性名
- **AND** 编译时 SHALL 生成警告但不阻止构建

#### Scenario: 回滚到旧字段名

- **WHEN** 系统回滚到迁移前版本
- **THEN** 数据库 SHALL 保留 `BuildLicenseNo` 列（只读别名）
- **AND** 应用程序 SHALL 能够读取旧字段名数据
- **AND** 业务逻辑 SHALL 继续正常工作

#### Scenario: 灰度期双写模式

- **WHEN** 系统处于迁移灰度期
- **THEN** 写入操作 SHALL 同时更新 `AccessCode` 和 `BuildLicenseNo`（如果有别名）
- **AND** 读取操作 SHALL 优先使用 `AccessCode`
- **AND** 这确保数据一致性并支持平滑过渡
