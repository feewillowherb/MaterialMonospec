# monospecs.yaml 配置模板文档

## 概述

`monospecs.yaml` 是 Monospec 主仓库的核心配置文件，定义了子仓库信息和全局配置选项。

## 配置模板

```yaml
# 配置文件版本号（字符串格式）
version: "1.0"

# 子仓库存放目录（相对于主仓库根目录）
repo_dir: repos

# 归档变更时是否自动提交 specs 到主仓库
commit_when_archive: true

# 子仓库列表
repositories:
  - # 仓库路径（相对于主仓库根目录，格式：repos/<repo-name>）
    path: repos/MaterialClient
    # Git 仓库远程地址
    url: https://github.com/example/MaterialClient.git
    # 显示名称
    displayName: MaterialClient
    # 仓库类型：Desktop | WebServer | Library | Mobile | Service | Other
    type: Desktop
    # 是否为可选仓库
    optional: false
    # 分类标签（用于筛选和分组）
    tags: [avalonia, industrial]

  - path: repos/UrbanManagement
    url: https://github.com/example/UrbanManagement.git
    displayName: UrbanManagement
    type: WebServer
    optional: false
    tags: [abp, web]
```

## 字段说明

### 全局字段

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `version` | string | 是 | 配置文件版本号，当前为 `"1.0"` |
| `repo_dir` | string | 是 | 子仓库目录名称，默认为 `repos` |
| `commit_when_archive` | boolean | 是 | 归档时是否自动提交 specs 变更 |

### 仓库字段

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `path` | string | 是 | 仓库相对路径，格式：`repos/<repo-name>` |
| `url` | string | 是 | Git 远程仓库地址 |
| `displayName` | string | 是 | 显示名称 |
| `type` | string | 是 | 仓库类型（见下方枚举） |
| `optional` | boolean | 否 | 是否为可选仓库，默认 `false` |
| `tags` | string[] | 否 | 分类标签数组 |

### type 枚举值

| 值 | 说明 |
|----|------|
| `Desktop` | 桌面应用程序 |
| `WebServer` | Web 服务器应用 |
| `Library` | 类库项目 |
| `Mobile` | 移动应用 |
| `Service` | 后台服务 |
| `Other` | 其他类型 |

## 添加新子仓库

在 `repositories` 数组中添加新条目即可：

```yaml
repositories:
  # ... 现有仓库 ...
  - path: repos/NewProject
    url: https://github.com/example/NewProject.git
    displayName: NewProject
    type: Library
    optional: false
    tags: [new-tag]
```

## 注意事项

1. **路径格式**：必须使用相对路径 `repos/<repo-name>`，不要使用绝对路径
2. **路径分隔符**：使用正斜杠 `/`，确保跨平台兼容
3. **version 格式**：使用字符串 `"1.0"`，不要用数字 `1.0`
4. **tags 格式**：使用 YAML 数组语法 `[tag1, tag2]` 或列表语法
