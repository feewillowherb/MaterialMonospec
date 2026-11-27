# MaterialMonospec / assets — Agent 约定

本目录存放**纳入 Git 跟踪**的静态视觉与预览资产（如 Chat 中 AI 生成的 SVG 预览图）。

## 目录索引

| 子目录 | 用途 | 详细约定 |
|--------|------|----------|
| `svg/` | AI 生成或手工维护的 SVG 预览与矢量资产（按 `YYYY/MM/DD/` 组织） | [`svg/AGENTS.md`](svg/AGENTS.md) |

## MUST / MUST NOT

- **MUST** 按子目录各自的 `AGENTS.md` 落盘，不得在 `assets/` 根目录散放未分类文件。
- **MUST** 仅存放适合进 Git 的轻量资产；禁止将大型二进制文件、构建产物、临时日志或含密钥的截图放入本目录。
- **MUST NOT** 在本目录及子目录下新建 `README.md`（见根仓库 `traits/agents-md-only-trait.md`）。

## 与父级目录的边界

- 本目录仅负责静态资产存储，不替代 `docs/` 的调研文档，也不替代 `openspec/` 的产品规范。
- 调研或提案文档引用本目录资产时，使用相对路径链接即可；若资产被长期引用，清理旧日期目录前须检查引用关系。
