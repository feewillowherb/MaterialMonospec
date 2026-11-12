# standard-solidwaste-schema-upgrade（materialclient）

## 目的 / Goal

用正式样本 `_tmp/1110/MaterialClient.db` 的**本地副本**验证 Standard / SolidWaste 产品迁移：内核称重行主键还在，产品历史表写上，固废扩展行按 `WeighingMode = 1` 补齐且第二次不覆盖。

Goal 槽：`standard-solidwaste-schema-upgrade-verify`

Status: **active**

路径：`pipelines/graphs/materialclient/standard-solidwaste-schema-upgrade/`

OpenSpec：`openspec/changes/refactor-standard-solidwaste-schema-isolation/`

## 非目标

- 不写回 `_tmp/1110/MaterialClient.db`
- 不修改 `repos/` 业务代码
- 不启动 MaterialClient 桌面进程（单实例互斥，连接串按 exe 目录解析）
- 不在 Graph 里 `ProjectReference` 到 `repos/`
- 不提交 secrets / runs
- 不把 cook 结果写成产品通过。P3 只由用户判定

## Cook

Node.js / TypeScript，`node:sqlite`。编排入口是 `scripts/Invoke-StandardSolidWasteSchemaUpgrade.ps1`（experimental）。

Cook 从产品迁移文件读取 `migrationBuilder.Sql`，从 `SolidWasteInfoExtensions` 读取键名、默认发货单位和联单号长度，然后只在工作副本上执行。内核迁移文件名用来对照 `__EFMigrationsHistory_Kernel`，不另写一套 DDL。

## 配置指针

- `./config.yaml`
- `./secrets.local.yaml`（gitignore；可覆盖 `sourceDb`）
- `./secrets.example.yaml`

## Sockets

| | |
|--|--|
| Start | sqlite-client-snapshot |
| End | schema-upgrade-checked |
| Cook | new-object |

## 前置

1. Node.js 22.5 及以上。`pipelines/` 已能 `pnpm exec tsx`。
2. `config.yaml` 的 `sourceDb` 指向可读的样本。
3. 样本上的内核历史应已经包含当前内核迁移文件；缺迁移时 cook 失败，不在 Node 里补内核 DDL。
