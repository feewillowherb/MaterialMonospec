# MaterialMonospec

编排仓。产品代码在子仓，规格与变更在本仓 `openspec/`。

## 子仓

| 路径 | 用途 |
|------|------|
| `repos/MaterialClient` | 工业材料称重桌面应用。`MaterialClient.Urban` 是工控客户端，须开机自动运行且主窗口保持前台 |
| `repos/UrbanManagement` | 城市管理 Web 应用 |
| `repos/FdSoft.BasePlatform` | 企业级基础平台 Web 应用 |

## 权威

| 层 | 落点 |
|----|------|
| 产品 SHALL / change | `openspec/` |
| Agent 行为契约 | `traits/` |
| 可复用知识 | `docs/` |
| Node.js cook 与验收 Graph | `pipelines/` |
| 规划仪式产物 | `_bmad-output/`，路由见 `docs/AGENTS.md` |

## 技术栈边界

本文件不改变子仓技术栈，也不改变 Node.js cook。cook 选型见 `pipelines/AGENTS.md` §4。密钥、连接串与本机私有路径不写入本目录。
