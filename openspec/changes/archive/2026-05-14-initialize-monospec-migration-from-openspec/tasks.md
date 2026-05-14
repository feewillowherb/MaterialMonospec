# 实施任务清单

## 1. 准备工作

- [x] 1.1 验证主仓库目录结构存在（openspec/、repos/、.gitignore）
- [x] 1.2 创建 monospecs.yaml 配置文件
- [x] 1.3 配置子仓库信息（MaterialClient 和 UrbanManagement）
- [x] 1.4 验证 monospecs.yaml YAML 语法正确性
- [x] 1.5 验证所有必需字段存在（version、repo_dir、commit_when_archive、repositories）
- [x] 1.6 验证仓库路径使用相对路径格式（repos/<repo-name>）
- [x] 1.7 验证 type 字段使用有效值（Desktop、WebServer）
- [x] 1.8 备份 ../MaterialClient/openspec/ 目录到安全位置
- [x] 1.9 备份 ../UrbanManagement/openspec/ 目录到安全位置

## 2. UrbanManagement 迁移（试点阶段）

- [x] 2.1 复制 ../UrbanManagement/openspec/specs/ 下所有 6 个 spec 目录到主仓库 openspec/specs/
- [x] 2.2 验证复制的 spec 目录数量（应为 6 个）
- [x] 2.3 验证每个 spec.md 文件内容完整性
- [x] 2.4 复制 ../UrbanManagement/openspec/changes/archive/ 下所有归档变更到主仓库
- [x] 2.5 验证归档变更数量和内容
- [x] 2.6 检查并处理可能的文件名冲突
- [x] 2.7 验证迁移完整性：对比源目录和目标目录的文件数量
- [x] 2.8 删除 ../UrbanManagement/openspec/ 目录
- [x] 2.9 验证 ../UrbanManagement/ 目录中不存在 openspec/ 子目录
- [x] 2.10 在主仓库创建测试变更验证工作流
- [x] 2.11 测试 commit_when_archive 自动提交功能
- [x] 2.12 验证 OpenSpec CLI 工具兼容性
- [x] 2.13 记录试点阶段发现的问题和解决方案

## 3. MaterialClient 迁移

- [x] 3.1 复制 ../MaterialClient/openspec/specs/ 下所有 46 个 spec 目录到主仓库 openspec/specs/
- [x] 3.2 验证复制的 spec 目录数量（应为 46 个）
- [x] 3.3 随机抽检 10 个 spec.md 文件内容完整性
- [x] 3.4 复制 ../MaterialClient/openspec/changes/archive/ 下所有归档变更到主仓库
- [x] 3.5 处理与 UrbanManagement 归档变更的文件名冲突（添加 materialclient- 前缀）
- [x] 3.6 验证归档变更数量（应包含 2026-01 到 2026-03 的变更）
- [x] 3.7 验证迁移完整性：对比源目录和目标目录的文件数量
- [x] 3.8 删除 ../MaterialClient/openspec/ 目录
- [x] 3.9 验证 ../MaterialClient/ 目录中不存在 openspec/ 子目录
- [x] 3.10 复制 PROPOSAL_DESIGN_GUIDELINES.md 到主仓库根目录
- [x] 3.11 整合 project.md 内容到主仓库 AGENTS.md

## 4. 配置完善和工具支持

- [x] 4.1 创建 monospecs.yaml 配置模板文档
- [x] 4.2 编写配置字段说明和示例
- [x] 4.3 创建子仓库添加模板和流程文档
- [x] 4.4 创建迁移指南文档
- [x] 4.5 编写故障排除指南
- [x] 4.6 创建配置验证工具脚本
- [x] 4.7 测试配置验证工具功能
- [x] 4.8 创建迁移验证工具脚本
- [x] 4.9 测试迁移验证工具功能

## 5. 文档更新

- [x] 5.1 创建或更新主仓库 AGENTS.md 文件
- [x] 5.2 在 AGENTS.md 中说明 Monospec 工作流程
- [x] 5.3 在 AGENTS.md 中说明子仓库代码实现流程
- [x] 5.4 在 AGENTS.md 中说明变更创建和归档流程
- [x] 5.5 创建变更管理最佳实践文档
- [x] 5.6 创建团队培训材料
- [x] 5.7 编写开发者迁移操作指南

## 6. 验证和测试

- [x] 6.1 创建跨仓库测试变更
- [x] 6.2 验证变更在主仓库创建
- [x] 6.3 验证代码在子仓库实现
- [x] 6.4 验证归档操作自动提交 specs
- [x] 6.5 验证子仓库代码需单独提交
- [x] 6.6 验证所有 52 个 specs 都可访问
- [x] 6.7 验证所有归档变更都保留完整
- [x] 6.8 验证 OpenSpec CLI 工具正常工作
- [x] 6.9 验证 HagiCode 应用兼容性（如使用）

## 7. 团队培训和推广

- [x] 7.1 准备团队培训演示材料
- [ ] 7.2 介绍 Monospec 架构和优势
- [ ] 7.3 演示新工作流程
- [ ] 7.4 演示变更创建和归档操作
- [ ] 7.5 解答团队疑问
- [ ] 7.6 收集团队反馈和改进建议
- [ ] 7.7 根据反馈优化文档和流程

## 8. 后续优化

- [ ] 8.1 评估是否需要 HagiCode 桌面应用支持
- [ ] 8.2 研究子仓库 CI/CD 集成需求
- [ ] 8.3 探索自动化迁移工具开发
- [ ] 8.4 建立配置同步和仓库状态监控
- [ ] 8.5 收集并分析迁移后的性能数据
