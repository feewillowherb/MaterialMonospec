# OpenSpec 到 Monospec 迁移指南

## 概述

本指南描述如何将独立使用 OpenSpec 的项目仓库迁移到 Monospec 统一管理架构。

## 迁移架构

```
迁移前：
├── ProjectA/
│   └── openspec/    ← 独立 OpenSpec
├── ProjectB/
│   └── openspec/    ← 独立 OpenSpec

迁移后：
├── MonospecRepo/    ← 统一管理
│   ├── openspec/
│   │   ├── specs/   ← 所有 specs
│   │   └── changes/ ← 所有变更
│   ├── repos/
│   │   ├── ProjectA/ ← 代码（无 openspec）
│   │   └── ProjectB/ ← 代码（无 openspec）
│   └── monospecs.yaml
```

## 迁移步骤

### 阶段 1：准备工作

1. **初始化 Monospec 主仓库**
   ```bash
   mkdir MonospecRepo && cd MonospecRepo
   git init
   mkdir -p openspec/specs openspec/changes/archive repos
   ```

2. **创建 monospecs.yaml**
   - 使用标准模板（参见 `monospecs-yaml-template.md`）
   - 配置所有子仓库信息

3. **配置 .gitignore**
   ```
   repos/
   ```

4. **备份所有子仓库的 openspec/ 目录**

### 阶段 2：试点迁移

1. 选择一个小规模子仓库作为试点
2. 复制 specs 和归档变更到主仓库
3. 验证完整性
4. 测试 OpenSpec CLI 工具兼容性
5. 删除子仓库的 openspec/ 目录

### 阶段 3：全面迁移

1. 按照试点验证的流程迁移其余子仓库
2. 处理归档变更的文件名冲突
3. 迁移项目文档（project.md、PROPOSAL_DESIGN_GUIDELINES.md 等）
4. 创建 AGENTS.md

### 阶段 4：验证和文档

1. 验证所有 specs 和归档变更完整性
2. 创建配置模板和工具脚本
3. 更新文档和培训材料

## 常见问题

### Q: 归档变更文件名冲突怎么办？

如果两个子仓库有相同日期前缀的归档变更，添加仓库名前缀区分：

```
2026-01-15-materialclient-doc-org
2026-01-15-urbanmanagement-init
```

### Q: 子仓库的代码需要修改吗？

不需要。迁移只涉及 OpenSpec 文档，子仓库代码完全不变。

### Q: 如何回滚？

1. 从备份恢复子仓库的 openspec/ 目录
2. 删除主仓库中迁移的文件
3. 恢复原有独立管理方式

### Q: commit_when_archive 有什么影响？

启用后，归档变更时 OpenSpec 会自动提交 specs 变更到主仓库的 Git。子仓库的代码变更仍需手动提交。
