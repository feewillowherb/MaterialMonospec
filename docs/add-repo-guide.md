# 添加子仓库指南

## 前提条件

- 已初始化 Monospec 主仓库
- 子仓库已存在于 Git 远程地址
- 有主仓库的写入权限

## 添加步骤

### 1. 更新 monospecs.yaml

在 `repositories` 数组末尾添加新条目：

```yaml
repositories:
  # ... 现有仓库 ...
  - path: repos/<RepoName>
    url: https://github.com/<org>/<RepoName>.git
    displayName: <RepoName>
    type: <Desktop|WebServer|Library|Mobile|Service|Other>
    optional: false
    tags: [<tag1>, <tag2>]
```

### 2. 创建 repos 目录联接

在主仓库的 `repos/` 目录下创建指向实际代码仓库的联接（junction）：

```powershell
# Windows
New-Item -ItemType Junction -Path "repos/<RepoName>" -Target "<实际仓库路径>"

# Linux/macOS
ln -s <实际仓库路径> repos/<RepoName>
```

### 3. 迁移现有 specs（如果有）

如果子仓库已有 OpenSpec 文档：

```bash
# 复制 specs
cp -r <RepoPath>/openspec/specs/* openspec/specs/

# 复制归档变更
cp -r <RepoPath>/openspec/changes/archive/* openspec/changes/archive/

# 删除子仓库的 openspec 目录
rm -rf <RepoPath>/openspec/
```

### 4. 验证

```bash
# 验证配置
openspec status --change <any-change> --json

# 列出所有 specs
openspec list --specs
```

### 5. 提交

```bash
git add monospecs.yaml
git commit -m "feat: add <RepoName> to monospec configuration"
```

## 注意事项

- 迁移前务必备份子仓库的 openspec 目录
- 检查归档变更的文件名是否与现有变更冲突
- 更新 AGENTS.md 中的子仓库信息
