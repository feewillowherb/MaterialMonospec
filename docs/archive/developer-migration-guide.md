# 开发者迁移操作指南

## 目标读者

需要从独立 OpenSpec 工作流迁移到 Monospec 工作流的开发者。

## 迁移概览

本迁移将 OpenSpec 文档从各子仓库集中到 MaterialMonospec 主仓库。迁移完成后：

- 所有 specs 在主仓库 `openspec/specs/` 中
- 所有变更记录在主仓库 `openspec/changes/` 中
- 子仓库仅包含代码，不再有 openspec/ 目录
- 使用 `repos/` 目录联接访问子仓库代码

## 迁移前准备

### 1. 克隆主仓库

```bash
git clone <MaterialMonospec-url>
cd MaterialMonospec
```

### 2. 确认子仓库联接

主仓库使用目录联接（junction）访问子仓库：

```powershell
# 检查联接是否存在
ls repos/

# 如果需要重新创建联接
New-Item -ItemType Junction -Path "repos/MaterialClient" -Target "<MaterialClient路径>"
New-Item -ItemType Junction -Path "repos/UrbanManagement" -Target "<UrbanManagement路径>"
```

## 迁移后的工作方式变化

### 创建变更（变化）

**迁移前**：在各子仓库的 openspec/ 中创建变更
```bash
cd MaterialClient
openspec create add-feature
```

**迁移后**：在主仓库中创建变更
```bash
cd MaterialMonospec
openspec create add-feature
```

### 查看 Specs（变化）

**迁移前**：在各子仓库查看
```bash
cd MaterialClient
openspec list --specs
```

**迁移后**：在主仓库统一查看
```bash
cd MaterialMonospec
openspec list --specs
```

### 实现代码（不变）

代码实现仍在子仓库中进行：
```bash
cd repos/MaterialClient
# 修改代码...
git add .
git commit -m "feat: implement feature"
git push
```

### 归档变更（变化）

**迁移前**：在子仓库归档
```bash
cd MaterialClient
openspec archive add-feature
```

**迁移后**：在主仓库归档
```bash
cd MaterialMonospec
openspec archive add-feature
# specs 会自动提交到主仓库
```

## 验证迁移成功

运行验证脚本：
```bash
powershell -ExecutionPolicy Bypass -File scripts/validate-migration.ps1
```

所有检查通过即表示迁移成功。

## 常见问题

### Q: 以前的归档变更去哪了？

所有历史归档变更已迁移到主仓库 `openspec/changes/archive/` 中，可随时查看。

### Q: 子仓库中还有 openspec/ 目录吗？

不应该有。迁移完成后子仓库的 openspec/ 目录已被删除。如果仍存在，说明迁移未完成。

### Q: 如何访问子仓库代码？

通过主仓库的 `repos/` 目录联接访问：
- `repos/MaterialClient/` - MaterialClient 代码
- `repos/UrbanManagement/` - UrbanManagement 代码

### Q: 代码提交和推送在哪里做？

在子仓库中（通过 repos/ 联接），不在主仓库中。
