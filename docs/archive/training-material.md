# Monospec 团队培训材料

## 1. 什么是 Monospec？

Monospec 是一种多仓库文档管理架构，将多个项目的 OpenSpec 文档统一到一个主仓库中管理。

### 核心理念

- **文档集中**：所有 specs 和变更记录在一个仓库中
- **代码分散**：代码仍各自在子仓库中管理
- **统一视图**：跨项目的变更和依赖一目了然

### 架构对比

```
迁移前：分散管理
├── ProjectA/openspec/ (独立文档)
└── ProjectB/openspec/ (独立文档)

迁移后：Monospec 统一管理
└── MonospecRepo/
    ├── openspec/ (统一文档)
    └── repos/
        ├── ProjectA/ (仅代码)
        └── ProjectB/ (仅代码)
```

## 2. 日常工作流程

### 创建新功能变更

```bash
# 1. 在主仓库创建变更
cd MaterialMonospec
openspec create add-new-feature

# 2. 编写提案
# 编辑 openspec/changes/add-new-feature/proposal.md

# 3. 编写设计和 specs
# 编辑 design.md 和 specs/ 目录

# 4. 生成 tasks
# 编辑 tasks.md

# 5. 在子仓库实现代码
cd repos/MaterialClient  # 或 repos/UrbanManagement
# 进行代码修改...

# 6. 完成后归档
cd ../..  # 回到主仓库
openspec archive add-new-feature
```

### 查看现有功能

```bash
# 查看所有 specs
openspec list --specs

# 查看特定 spec 的内容
cat openspec/specs/attended-weighing/spec.md

# 查看活动变更
openspec list

# 查看变更状态
openspec status --change <change-name> --json
```

### 查看历史变更

```bash
# 归档变更在
ls openspec/changes/archive/
```

## 3. 关键命令速查

| 操作 | 命令 |
|------|------|
| 创建变更 | `openspec create <name>` |
| 列出变更 | `openspec list` |
| 列出 specs | `openspec list --specs` |
| 变更状态 | `openspec status --change <name> --json` |
| 获取指引 | `openspec instructions apply --change <name> --json` |
| 验证变更 | `openspec validate <name> --strict` |
| 归档变更 | `openspec archive <name>` |
| 验证配置 | `powershell -File scripts/validate-config.ps1` |
| 验证迁移 | `powershell -File scripts/validate-migration.ps1` |

## 4. 常见场景

### 场景 1：修改 MaterialClient 的称重功能

1. 在主仓库创建变更 `openspec create update-weighing-logic`
2. 编写 proposal.md 说明修改原因和内容
3. 在 `openspec/specs/attended-weighing/` 下更新 delta spec
4. 在 `repos/MaterialClient/` 中修改代码
5. 在 MaterialClient 仓库提交代码
6. 回到主仓库归档变更

### 场景 2：跨仓库的功能更新

1. 创建变更时在 proposal.md 中标明影响范围
2. tasks.md 中分别列出每个子仓库的任务
3. 分别在各子仓库实现代码
4. 分别提交各子仓库代码
5. 归档主仓库变更

## 5. 注意事项

- 子仓库代码需**单独提交和推送**，归档不会自动提交子仓库代码
- 变更命名使用动词前缀（add-、update-、remove-、refactor-）
- 归档前确认所有任务已完成
- 遇到问题参考 `docs/troubleshooting.md`
