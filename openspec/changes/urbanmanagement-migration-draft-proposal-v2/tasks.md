# UrbanManagement 迁移实施任务清单

## Execution Status

**当前状态：✅ 可以执行**

### 前置依赖状态

- ✅ **BasePlatform PublicApi AccessCode/MachineCode 分列**：已完成
- ✅ **BasePlatform PublicApi JWT 签发基础设施**：已完成
- ✅ **BasePlatform API 端点可用性**：已验证可正常访问

### UrbanManagement 执行准备

- ✅ **提案规格文档**：已完成（proposal.md、design.md）
- ✅ **任务清单**：已完成（本文档）
- ✅ **API 对接规格**：已明确
- ⏳ **代码执行**：可立即开始

### 执行建议

1. **可立即开始执行**：所有外部依赖已满足
2. **建议执行顺序**：按本文档章节顺序执行（§1 → §2 → §3 → §4）
3. **灰度策略**：使用 Feature Flag 控制启用，确保可快速回滚
4. **测试验证**：每阶段完成后执行对应的测试任务

## 前置条件

- ✅ BasePlatform PublicApi 已完成 AccessCode 与 MachineCode 分列（见 `2026-06-24-add-access-token-support` 提案）
- ✅ BasePlatform PublicApi 已完成 JWT 签发基础设施（见 `2025-06-25-baseplatform-jwt` 提案）
- ✅ BasePlatform `/Api/ProjectCatalog/ListProjects` 已返回 `accessCode`、`machineCode` 字段
- ✅ BasePlatform `/api/auth/license-file` 已支持 GET 方法签发 ProductCode=5001 JWT
- ✅ BasePlatform `/api/auth/activate-urban` 已实现在线激活功能

## BasePlatform 已实现功能规格

### ProjectCatalog API
- 端点：`GET /Api/ProjectCatalog/ListProjects?pageIndex={}&pageSize={}`
- 响应字段：
  - `ProId` (Guid)
  - `ProName` (string)
  - `ProductCode` (int) - 固定为 5001
  - `ProAddress` (string)
  - `ShigongUnitName` (string)
  - `AccessCode` (string) - 接入码
  - `MachineCode` (string) - 机器码
  - `FdBuildLicenseNo` (string) - MD5 处理后的许可证号
  - `AuthEndTime` (DateTime?)

### Auth License File API
- 端点：`GET /api/auth/license-file?productCode={}&machineCode={}&proId={}&authEndDate={}&format={}`
- 请求参数：
  - `productCode`: 固定为 5001（Urban 产品）
  - `machineCode`: 机器码
  - `proId`: 项目 ID（Guid 字符串）
  - `authEndDate`: 授权截止日期
  - `format`: 返回格式（`json` 或 `stream`，默认 `json`）
- 响应格式：
  ```json
  {
    "success": true,
    "msg": "签发成功",
    "data": {
      "jwtToken": "eyJhbGc...",
      "proId": "...",
      "proName": "...",
      "authEndDate": "2026-12-31"
    }
  }
  ```

### Activate Urban API
- 端点：`POST /api/auth/activate-urban`
- 请求体：
  ```json
  {
    "productCode": 5001,
    "code": "授权码",
    "machineCode": "机器码"
  }
  ```
- 功能：验证 Redis 授权码、回写 MachineCode、签发 JWT

## 1. EF 实体与数据库迁移

- [ ] 1.1 修改 `GovProject` 实体：将 `BuildLicenseNo` 属性重命名为 `AccessCode`
- [ ] 1.2 修改 `GovProject` 实体：新增 `MachineCode` 可空字符串属性
- [ ] 1.3 修改 `GovProject` 实体：新增 `AuthToken` 可空字符串属性
- [ ] 1.4 更新 `UrbanManagementDbContext`：修改实体配置（`BuildLicenseNo` → `AccessCode`）
- [ ] 1.5 更新 `UrbanManagementDbContext`：新增 `MachineCode` 和 `AuthToken` 列配置（最大长度 200，可空）
- [ ] 1.6 更新 `UrbanManagementDbContext`：修改索引配置（`IX_Gov_Projects_BuildLicenseNo` → `IX_Gov_Projects_AccessCode`）
- [ ] 1.7 生成 EF Core 迁移脚本：`dotnet ef migrations add RenameBuildLicenseNoToAccessCode`
- [ ] 1.8 验证迁移脚本：检查生成的 SQL 是否包含 RENAME COLUMN 和 ADD COLUMN 语句
- [ ] 1.9 在测试环境执行迁移：`dotnet ef database update` 并验证数据无损
- [ ] 1.10 创建回滚脚本：手动编写 SQL 回滚脚本（RENAME 回、DROP 新列）

## 2. 拉取同步逻辑更新

- [ ] 2.1 修改 `IBasePlatformProjectHttpClient`：在 `ProjectCatalogItemResponse` 中新增 `AccessCode` 属性（对接 BasePlatform 已实现字段）
- [ ] 2.2 修改 `IBasePlatformProjectHttpClient`：在 `ProjectCatalogItemResponse` 中新增 `MachineCode` 属性（对接 BasePlatform 已实现字段）
- [ ] 2.3 修改 `IBasePlatformProjectHttpClient`：在 `ProjectCatalogItemResponse` 中新增 `AuthToken` 属性（存储授权令牌，非 BasePlatform 字段）
- [ ] 2.4 修改 `GovProjectPullManager.MapRemoteToNewEntity`：映射 `remote.AccessCode` → `entity.AccessCode`
- [ ] 2.5 修改 `GovProjectPullManager.MapRemoteToNewEntity`：映射 `remote.MachineCode` → `entity.MachineCode`
- [ ] 2.6 修改 `GovProjectPullManager.MapRemoteToNewEntity`：映射 `remote.AuthToken` → `entity.AuthToken`
- [ ] 2.7 修改 `GovProjectPullManager.ApplyRemoteFieldsIfChanged`：比较 `entity.AccessCode` 与 `remote.AccessCode`
- [ ] 2.8 修改 `GovProjectPullManager.ApplyRemoteFieldsIfChanged`：如果不同，更新 `entity.AccessCode`
- [ ] 2.9 修改 `GovProjectPullManager.ApplyRemoteFieldsIfChanged`：比较 `entity.MachineCode` 与 `remote.MachineCode`
- [ ] 2.10 修改 `GovProjectPullManager.ApplyRemoteFieldsIfChanged`：如果不同，更新 `entity.MachineCode`
- [ ] 2.11 新增 `GovProjectPullManager.NormalizeRemoteItems`：过滤 `ProductCode != 5001` 的项目（BasePlatform API 已实现 ProductCode 过滤）
- [ ] 2.12 更新 `GovProjectPullManager.PullAndInsertNewProjectsAsync`：调用 `NormalizeRemoteItems` 进行数据清洗
- [ ] 2.13 编写单元测试：验证 `NormalizeRemoteItems` 正确过滤无效项目
- [ ] 2.14 编写单元测试：验证 `ApplyRemoteFieldsIfChanged` 正确映射新字段
- [ ] 2.15 编写集成测试：验证拉取同步流程包含 `AccessCode`、`MachineCode`、`AuthToken`

## 3. JWT 委托逻辑实现

- [ ] 3.1 新增 `IBasePlatformAuthHttpClient` Refit 接口：定义 `GetLicenseFileAsync` 方法（对接 BasePlatform `/api/auth/license-file`）
- [ ] 3.2 新增 `LicenseFileResponse` 类：包含 `JwtToken`、`ProId`、`ProName`、`AuthEndDate` 属性（匹配 BasePlatform 响应格式）
- [ ] 3.3 新增 `BasePlatformApiResponse<LicenseFileResponse>` 类：包装 BasePlatform 响应
- [ ] 3.4 在 `UrbanManagementCoreModule` 中注册 `IBasePlatformAuthHttpClient`：使用 Refit 配置
- [ ] 3.5 新增 `BasePlatformAuthOptions` 配置类：包含 `BaseUrl` 配置属性
- [ ] 3.6 在 `appsettings.json` 中新增 `BasePlatform:AuthUrl` 配置项
- [ ] 3.7 修改 `GovProjectLicenseAppService.GenerateAsync`：注入 `IBasePlatformAuthHttpClient`
- [ ] 3.8 修改 `GovProjectLicenseAppService.GenerateAsync`：调用 `GetLicenseFileAsync(ProductCode=5001, MachineCode, ProId, AuthEndDate)`
- [ ] 3.9 修改 `GovProjectLicenseAppService.GenerateAsync`：验证响应成功并提取 `JwtToken`
- [ ] 3.10 修改 `GovProjectLicenseAppService.GenerateAsync`：返回 `FileContentResult` 包含 BasePlatform JWT
- [ ] 3.11 修改 `JwtAntiTamperService.VerifyAndCompareAsync`：注入 `IBasePlatformAuthHttpClient`
- [ ] 3.12 修改 `JwtAntiTamperService.VerifyAndCompareAsync`：在验签通过后调用 `GetLicenseFileAsync`
- [ ] 3.13 修改 `JwtAntiTamperService.VerifyAndCompareAsync`：处理 BasePlatform 调用失败情况（返回 Fail）
- [ ] 3.14 修改 `JwtAntiTamperService.VerifyAndCompareAsync`：移除 `_urbanLicenseGenerator.GenerateLicenseToken` 调用
- [ ] 3.15 修改 `JwtAntiTamperService` 构造函数：移除 `IUrbanLicenseGenerator` 依赖注入
- [ ] 3.16 修改 `DeviceStatusHub.GetClientProjectLicenseInfo`：确保 `BuildLicenseNo` 来自 `GovProject.AccessCode`
- [ ] 3.17 更新 `DeviceStatusHub` SignalR 推送：确保推送的 JWT 来自 BasePlatform（如有推送逻辑）
- [ ] 3.18 标记 `UrbanLicenseGenerator` 为 `[Obsolete("Use BasePlatform JWT API instead")]`
- [ ] 3.19 编写单元测试：验证 `GovProjectLicenseAppService` 正确代理调用 BasePlatform
- [ ] 3.20 编写单元测试：验证 `JwtAntiTamperService` 验签后返回 BasePlatform JWT
- [ ] 3.21 编写集成测试：使用 Mock BasePlatform API 验证完整授权流程

## 4. Feature Flag 与配置

- [ ] 4.1 新增 `UrbanAuthOptions` 配置类：包含 `UseAccessCodeMigration` 和 `UseBasePlatformJwtIssuer` 属性
- [ ] 4.2 在 `UrbanManagementCoreModule` 中绑定 `UrbanAuthOptions`：从 `appsettings.json` 加载配置
- [ ] 4.3 在 `appsettings.json` 中新增 `UrbanAuth` 配置节
- [ ] 4.4 设置 `UrbanAuth:UseAccessCodeMigration` 默认值为 `true`
- [ ] 4.5 设置 `UrbanAuth:UseBasePlatformJwtIssuer` 默认值为 `true`
- [ ] 4.6 修改 `GovProjectPullManager`：注入 `IOptions<UrbanAuthOptions>`
- [ ] 4.7 在 `GovProjectPullManager` 映射逻辑中添加 Feature Flag 判断
- [ ] 4.8 修改 `GovProjectLicenseAppService`：注入 `IOptions<UrbanAuthOptions>`
- [ ] 4.9 在 `GovProjectLicenseAppService` 中添加 Feature Flag 判断
- [ ] 4.10 修改 `JwtAntiTamperService`：注入 `IOptions<UrbanAuthOptions>`
- [ ] 4.11 在 `JwtAntiTamperService` 中添加 Feature Flag 判断
- [ ] 4.12 编写配置文档：说明 Feature Flag 的作用和推荐值
- [ ] 4.13 编写单元测试：验证 Feature Flag 为 `false` 时回退到旧逻辑

## 5. 脏数据修复脚本（可选）

- [ ] 5.1 新增 `AccessCodeMigrationBackgroundWorker` 类：继承 `AsyncPeriodicBackgroundWorkerBase`
- [ ] 5.2 实现修复逻辑：查询所有 `GovProject` 记录
- [ ] 5.3 实现修复逻辑：从 BasePlatform 拉取最新数据
- [ ] 5.4 实现修复逻辑：更新 `AccessCode`、`MachineCode`、`AuthToken` 字段
- [ ] 5.5 添加分页处理：避免一次性加载所有项目
- [ ] 5.6 添加执行间隔：配置每 10 秒修复一批
- [ ] 5.7 添加日志记录：记录修复的记录数量和失败原因
- [ ] 5.8 在 `UrbanManagementCoreModule` 中注册后台 Worker
- [ ] 5.9 编写单元测试：验证修复逻辑正确更新数据
- [ ] 5.10 在测试环境验证：后台 Worker 成功修复脏数据

## 6. 测试验证

- [ ] 6.1 执行所有单元测试：`dotnet test` 并确保全部通过
- [ ] 6.2 执行所有集成测试：验证 BasePlatform API 调用
- [ ] 6.3 手动测试 AccessCode 迁移：验证数据库字段正确重命名
- [ ] 6.4 手动测试拉取同步：验证新字段正确映射
- [ ] 6.5 手动测试 JWT 授权：验证客户端能成功获取 BasePlatform JWT
- [ ] 6.6 手动测试 JWT 验签：验证 `JwtAntiTamperService` 返回 BasePlatform JWT
- [ ] 6.7 测试 Feature Flag 回退：设置 `false` 验证旧逻辑仍可用
- [ ] 6.8 性能测试：验证 BasePlatform API 调用延迟在可接受范围
- [ ] 6.9 监控测试：验证日志输出包含足够的调试信息
- [ ] 6.10 安全测试：验证敏感信息不记录到日志

## 7. 部署上线

- [ ] 7.1 备份生产数据库：复制 `urbanmanagement.db` 文件
- [ ] 7.2 设置 Feature Flag 为 `false`：初始使用旧逻辑
- [ ] 7.3 部署新版本代码到生产环境
- [ ] 7.4 验证应用启动成功：检查启动日志无错误
- [ ] 7.5 监控业务指标 1 小时：观察拉取同步成功率和授权成功率
- [ ] 7.6 设置 `UseAccessCodeMigration=true`：启用 AccessCode 映射
- [ ] 7.7 监控拉取同步成功率：确认无异常下降
- [ ] 7.8 设置 `UseBasePlatformJwtIssuer=true`：启用 JWT 委托
- [ ] 7.9 监控授权成功率：确认无异常下降
- [ ] 7.10 观察 24 小时：确认系统稳定运行
- [ ] 7.11 移除 Feature Flag：从代码中删除条件判断逻辑
- [ ] 7.12 删除 `UrbanLicenseGenerator` 旧代码：清理过时代码
- [ ] 7.13 更新 API 文档：说明 JWT 签发来源变更

## 8. 文档与清理

- [ ] 8.1 更新 `AGENTS.md`：记录新的字段命名约定（`AccessCode` 替代 `BuildLicenseNo`）
- [ ] 8.2 更新 API 文档：说明 BasePlatform JWT 签发端点
- [ ] 8.3 编写迁移指南：供其他团队参考类似迁移
- [ ] 8.4 清理测试代码：移除调试代码和注释掉的代码
- [ ] 8.5 代码审查：确保所有变更符合编码规范
- [ ] 8.6 性能优化：检查是否有性能瓶颈（如 N+1 查询）
- [ ] 8.7 安全审查：确保敏感信息不暴露
- [ ] 8.8 归档变更文档：将相关文档移动到 `archive` 目录

## 9. 回滚准备

- [ ] 9.1 验证回滚脚本：在测试环境执行 SQL 回滚脚本
- [ ] 9.2 测试应用回滚：设置 Feature Flag 为 `false` 验证旧逻辑可用
- [ ] 9.3 准备回滚文档：编写详细的回滚步骤
- [ ] 9.4 通知相关人员：告知回滚预案和联系方式
- [ ] 9.5 监控告警配置：设置关键指标告警阈值
