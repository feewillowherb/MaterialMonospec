# MaterialMonospec / docs — Agent 约定

本文件**仅约束** `MaterialMonospec/docs/` 下的调研笔记、说明与 walkthrough 产出。  
不约束 `openspec/`、`repos/` 中的 OpenSpec 规范与业务代码（那些仍遵守仓库根目录 `AGENTS.md`）。

## 源码引用

本仓库源码位于 `repos/`（目录联接），调研文档中引用的路径均相对 MaterialMonospec，例如：

| 写法示例 | 含义 |
|----------|------|
| `repos/MaterialClient/src/MaterialClient.Common/...` | MaterialClient 子仓库 |
| `repos/UrbanManagement/...` | UrbanManagement 子仓库 |
| `openspec/changes/<name>/` | 本仓库 OpenSpec 变更 |

历史文档中若写 `MaterialClient.Common/Services/...`（无 `repos/` 前缀），亦指上述 MaterialClient 路径。

## Output Language

- 默认输出语言为中文。
- 专用名词（函数名、命名空间、NuGet 包名、API 名称、类型名等）保留原文，不翻译。

## Research Output Format

每次调研产出统一放置在 `docs/` 下的**独立文件夹**中，而非散落为多个独立文件。文件夹命名格式：

```
docs/<YYYY-MM-DD>-<提案或主题名称>/
```

示例：

```
docs/2026-01-01-topic-name/
├── 00-调研总览.md
├── 01-使用指南.md
├── 02-技术参考.md
├── 03-快速参考.md
└── ...
```

规则：

- 文件夹名称由日期和提案/主题名称组成，使用连字符分隔。
- 文件夹内的文档按编号排序，编号从 `00` 开始。
- 每个调研文件夹应包含一个 `00-调研总览.md` 作为入口索引。

### 例外（既有文档）

以下类型**不强制**迁入 `YYYY-MM-DD-主题/` 结构，可保持现有布局：

- 运维/迁移类固定手册（如 `troubleshooting.md`、`migration-guide.md`、`monospecs-yaml-template.md`）
- 按产品域长期维护的目录（如 `UrbanManagement/`、`HikLpr/`、`SyncDoc/`）

**新建调研**仍应使用上文的日期文件夹格式。
