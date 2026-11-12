# MaterialMonospec / pipelines — Agent 约定

本文件是 `pipelines/` 的**唯一 Agent 入口**（取代原 `README.md`）。  
约束验收 Graph 的目录、选型、新建与退役；不约束 `openspec/` 业务规范与 `repos/` 业务代码。

人读深潜仍可指向 `docs/2026-08-13-ai-pipeline-design-philosophy/`；**cook 协议以本目录 Graph 为准**。

---

## 1. 目录角色

| 路径 | 角色 |
|------|------|
| `_shared/`、`_template/`、`scripts/`（若有）、根 `package.json`（若有） | **框架**（共享 Cook、模板、可选 TS workspace） |
| `graphs/<domain>/<slug>/` | **目标产物**（现行验收 Graph） |
| `graphs/_retired/<YYYY-MM>/<slug>/` | **已退役** Graph（按退役年月归档） |
| `graphs/<slug>/`（无 domain） | **遗留平铺**（只读兼容；触及则迁入分层） |
| `pipelines/<slug>/`（与框架平铺） | **极旧遗留**；触及 MUST 迁入 `graphs/<domain>/<slug>/` |

**MUST**：新 Graph 落在 `graphs/<domain>/<slug>/`。  
**MUST NOT**：与 `_shared` / `_template` 平铺混放；**MUST NOT** 在现行路径里用日期文件夹（日期只用于 `runs/` 与 `_retired/`）。

---

## 2. graphs 分层

```text
pipelines/graphs/
  <domain>/
    <slug>/                 # 一条 Graph
      pipeline.md
      config.yaml           # 含 created + graph.* 元数据
      secrets.example.yaml
      scripts/ | src/ | fixtures/ | seeds/   # 按需
      runs/<yyyy-MM-ddTHHmmss>/
  _retired/
    <YYYY-MM>/
      <slug>/
```

### 2.1 `domain` 词表（路径第一层）

| domain | 含义 | 例 |
|--------|------|-----|
| `materialclient` | MaterialClient（Avalonia 称重桌面） | `attended-list-observe` |
| `urban` | UrbanManagement（城管 Web） | `weighing-list-observe` |
| `baseplatform` | FdSoft.BasePlatform | `login-smoke` |
| `govsync` | 政府平台出站/对接探测与采证 | `xiaoshan-gate`；站点图可用 `graphs/govsync/<PointNumber>/<slug>/`（如 `XNYH20251113001/sand-addbatch-2026-01`） |
| `platform` | 跨产品运维：表导入导出、库同步、冒烟等 | `sqlite-reconcile` |
| `ops` | 运维基础设施：SSH 远程执行 / 主机探测（供 Agent 复用） | `ssh-agent` |

新增 domain **MUST** 先改本文件词表，再落盘。

### 2.2 元数据（`config.yaml` 顶栏，选型第二刀）

每个 Graph **MUST** 含：

```yaml
id: "<slug>"
created: "2026-08-27"          # YYYY-MM-DD；本 Graph 落盘创建日（必填）
graph:
  product: urban           # materialclient | urban | baseplatform | platform
  domain: govsync          # 与路径 domain 一致（含 ops）
  family: probe            # observe | ingest | probe | reconcile | transform
  goal: gov-inout-record-save   # kebab；同一 goal 槽互斥
  status: active           # active | retired
```

每个 Graph **MUST** 有顶栏 `created: YYYY-MM-DD`（ISO 日期）。新建时填当日；**MUST NOT** 用路径日期段代替该字段。

| family | 含义 |
|--------|------|
| `observe` | UI/表面采证（截图 / HTTP / 日志 / DevTools） |
| `ingest` | 灌数写入（CSV/SQL/本地库；默认 dryRun） |
| `probe` | HTTP/API/健康探测与请求响应采证 |
| `reconcile` | 双侧对照（如客户端 ↔ UrbanManagement） |
| `transform` | 本地 A→B 派生（不写生产库） |

| product | 含义 |
|---------|------|
| `materialclient` | MaterialClient 为主 |
| `urban` | UrbanManagement 为主 |
| `baseplatform` | FdSoft.BasePlatform 为主 |
| `platform` | 跨产品运维工具，不归属单一业务域 |

兼容字段：旧 Graph 可能仍有顶层 `family` / `goal` / `status`；**新 Graph MUST 写在 `graph.*`**。选型时若两者并存，以 `graph.*` 为准。

### 2.3 日期规则

| 位置 | 规则 |
|------|------|
| `created:`（config 顶栏） | **必填** `YYYY-MM-DD`；Graph 创建日；选型/索引可扫 |
| 现行 Graph 路径 | **禁止** `YYYY-MM-DD` 或 `YYYY-MM` 段 |
| `runs/<yyyy-MM-ddTHHmmss>/` | 每次 cook 证据包 |
| `graphs/_retired/<YYYY-MM>/` | 退役当月；`status: retired`，`pipeline.md` 一行指向继任 slug |

---

## 3. 选型算法（Agent 必做）

执行或生成前：

1. 读本文件。
2. 从用户意图抽取 `product` / `domain` / `family` / `goal`（缺则 Ask，**禁止猜**）。
3. 候选范围：
   - 优先：`graphs/<domain>/*/` 且 `graph.status: active`（及元数据匹配）；
   - 亦扫：`graphs/<domain>/<site-or-point>/*/`（如 govsync 下 PointNumber 站点根）；
   - 兼容：仍存在的平铺 `graphs/<slug>/` 或极旧 `pipelines/<slug>/`（见 §6）。
4. 过滤 `family` / `goal`；列出命中路径。
5. **0 命中** → Ask 是否新建（走 `/gen-*-pipeline` 或手写模板）。  
   **1 命中** → 使用该路径。  
   **>1 命中** → Ask 用户选择，禁止静默挑一个。
6. 新建时：若已有**同一 `goal`** 的 `active` Graph → Ask：替换（旧迁 `_retired/<YYYY-MM>/`）/ 另开 goal / 取消。

Invoke 路径示例（分层后）：

```powershell
# 相对仓库根
powershell -ExecutionPolicy Bypass -File pipelines/graphs/govsync/xiaoshan-gate/scripts/Invoke-XiaoshanUpload.ps1

# TS cook / observe：在 pipelines/ 下经 pnpm + tsx（见 §4.1）
cd pipelines
pnpm exec tsx ./graphs/<domain>/<slug>/scripts/<tool>.ts
# 若启用 observe runner（可选）
# pnpm observe -- ./graphs/<domain>/<slug>
# 相对 _shared：从 graphs/<domain>/<slug>/ 为 ../../../_shared/...
```

遗留平铺仍为 `../../_shared/...`（若有）。

---

## 4. 框架用法（摘要）

**哲学**：与 OpenSpec 同构、**不是** OpenSpec — `/gen-pipeline` 对 propose，`/run-pipeline` 对 apply。

| family | 入口 |
|--------|------|
| 通用 | `/gen-pipeline`、`/run-pipeline`；命令见 `.cursor/commands/` |
| 分族 | `/gen-<family>-pipeline`、`/run-<family>-pipeline` |
| 登录/适配共享 | 放 `_shared/`（按产品写 runbook）；勿各图重写 |

密钥：仅 `secrets.local.yaml`（gitignore）。**MUST NOT** 把密码写进 `pipeline.md` / `config.yaml`。

**Node/TS runtime**：`pipelines/package.json` + pnpm；Graph 编排仍以各 `scripts/*.ps1`（experimental）为主。默认 cook 仍是 Node。SQLite 的 Node cook 用 Node ≥ 22.5 内置 `node:sqlite`。可行性实验可另加 **net10.0** 控制台项目，规则见 §4.2。

### 4.1 Cook 脚本语言选型（Node）

编排入口仍是 **PowerShell**；下列约束仅针对 Graph / `_shared` 下的 Node cook 内核。

| 场景 | **MUST** | 调用 |
|------|----------|------|
| **复杂逻辑**（多模块、强数据结构、守恒/拆分/校验、可复用 transform/ingest） | **TypeScript**（`.ts`） | `pnpm exec tsx`（挂 `pipelines/package.json` scripts；首次需 `pnpm install`） |
| **跨 Graph 复用**工具 | **TypeScript**，放 `_shared/` | 同上 |
| **短探针 / 一次性**、仅 stdlib、逻辑一目了然 | 允许 `.mjs` + 裸 `node` | `& node $ToolPath` |

硬约束：

- **新建**复杂 cook：**MUST** 用 `.ts`，**MUST NOT** 新开大型 `.mjs`「图内核」。
- 复杂脚本 **MUST** 落在根 `pipelines/` workspace（**MUST NOT** 为单 Graph 另建 `package.json`）。
- Invoke **MUST** 与 `solidwaste-pair-ingest` 对齐：检测 `tsx` → 必要时 `pnpm install` → `pnpm exec tsx …`。
- 存量 `.mjs`（如 `expand-january.mjs`、`export-csv.mjs`）**不强制**本 change 迁 TS；**触及重写或大幅扩展时 MUST 迁为 `.ts`**。

参考：`graphs/materialclient/solidwaste-pair-ingest/scripts/ingest-pair.ts`、`_shared/urban/tools/upsert-license-info/`。

### 4.2 .NET 10 实验运行时

默认 cook 保持 Node.js / TypeScript。需要用与 `MaterialClient` 相同的 TFM 重放纯逻辑时，Graph 内可以加一个 **net10.0** 控制台实验项目。这不替换现有 `.ts` cook，也不把产品工程引进 pipeline。

| 规则 | 说明 |
|------|------|
| TFM | `net10.0` |
| SDK | `pipelines/global.json` 指向 10.0，`rollForward: latestFeature`，`allowPrerelease: false` |
| 位置 | `graphs/<domain>/<slug>/src/*.csproj` |
| 调用 | 该 Graph 的 `scripts/*.ps1` 执行 `dotnet run --project <csproj> -- <args>` |
| 脚手架 | 从 [`_template/dotnet/`](_template/dotnet/) 复制，再改命名空间与逻辑 |
| 产物 | `bin/`、`obj/` 已由 `pipelines/.gitignore` 忽略；**MUST NOT** 提交 |
| 边界 | 不 `ProjectReference` 到 `repos/`；不改产品行为；不写生产库；密钥仍只进 `secrets.local.yaml` |

硬约束：

- 现有 `node:sqlite` cook **保持 TypeScript**。不得把已有 Graph 内核改写成 C#。
- 实验项目是 FEV 证据用途。cook 的 P0–P3 仍不代表产品通过。
- 新建实验 Graph 仍走 §3 选型与 §5 清单；`pipeline.md` 写明 Cook 是 `dotnet run`，并标 `experimental`。

---

## 5. 新建 / 退役清单

**新建**

- [ ] `domain` ∈ 词表；路径 `graphs/<domain>/<slug>/`
- [ ] `config.yaml` 含 `created: YYYY-MM-DD`（当日）与完整 `graph.*`；`domain` 与路径一致
- [ ] 共享引用深度正确（分层：`../../../_shared/...`）
- [ ] 同 `goal` 无第二个 `active`
- [ ] 脚本只放该 Graph 的 `scripts/`，标 `experimental`
- [ ] 复杂 Node cook 用 `.ts` + `tsx`（见 §4.1）；短探针才允许 `.mjs`
- [ ] 若该 Graph 含 .NET 实验：TFM `net10.0`，工程在 `src/`，经 `scripts/*.ps1` 调用；不提交 `bin/`、`obj/`（见 §4.2）

**退役**

- [ ] `graph.status: retired`；`pipeline.md` 指向继任
- [ ] 移到 `graphs/_retired/<YYYY-MM>/<slug>/`
- [ ] 修正外链（openspec tasks、docs）

---

## 6. 遗留路径 → 目标路径

平铺 / 极旧 Graph **仍可 cook**；Agent **触及**（改配置、扩场景、重跑并改协议）时 **MUST** 迁到目标路径并补 `graph.*`，同时修相对路径与文档外链。

| 遗留路径 | 目标 `graphs/<domain>/<slug>/` |
|----------|--------------------------------|
| `pipelines/govsync-postweight/` | 遗留平铺；现行继任为 `xiaoshan-*` 三图；历史实现见 `_retired/2026-08/postweight/` |
| `graphs/govsync-postweight/`（若出现） | `_retired/2026-08/postweight/` |

未列入的平铺 slug：按前缀归入 §2.1 domain；不确定则 Ask。

### 6.1 现行索引（可扫元数据；表仅作速查）

| Goal | Family | 路径 | Status |
|------|--------|------|--------|
| gov-xiaoshan-weighbridge-save | probe | `graphs/govsync/xiaoshan-weighbridge/` | active |
| gov-xnxs20240725003-weighbridge-save | probe | `graphs/govsync/xnxs20240725003-weighbridge/` | active |
| gov-gdxs20260520002-weighbridge-save | probe | `graphs/govsync/gdxs20260520002-weighbridge/` | active |
| gov-330109202203290201-weighbridge-save | probe | `graphs/govsync/330109202203290201-weighbridge/` | active |
| gov-xiaoshan-gate-save | probe | `graphs/govsync/xiaoshan-gate/` | active |
| gov-xiaoshan-serve-api-post | probe | `graphs/govsync/xiaoshan-serve-apipost/` | active |
| gov-xiaoshan-product-save | probe | `graphs/govsync/xiaoshan-product/` | active |
| gov-recycle-hmac-auth | probe | `graphs/govsync/recycle-hmac-auth/` | active |
| gov-sand-product-addbatch-2026-01 | transform | `graphs/govsync/XNYH20251113001/sand-addbatch-2026-01/` | active |
| gov-sand-product-addbatch-2026-02 | transform | `graphs/govsync/XNYH20251113001/sand-addbatch-2026-02/` | active |
| gov-sand-product-addbatch-2026-03 | transform | `graphs/govsync/XNYH20251113001/sand-addbatch-2026-03/` | active |
| gov-sand-product-addbatch-2026-04 | transform | `graphs/govsync/XNYH20251113001/sand-addbatch-2026-04/` | active |
| gov-sand-product-addbatch-2026-05 | transform | `graphs/govsync/XNYH20251113001/sand-addbatch-2026-05/` | active |
| gov-sand-product-addbatch-submit | probe | `graphs/govsync/XNYH20251113001/sand-addbatch-submit/` | active |
| login-observe-flaui | observe | `graphs/materialclient/login-flaui/` | active |
| login-observe-devtools | observe | `graphs/materialclient/login-devtools/` | active |
| urban-passage-lpr-probe | probe | `graphs/urban/urban-passage-probe/` | active |
| urban-license-seed-probe | probe | `graphs/urban/urban-license-probe/` | active |
| urban-passage-client-um-reconcile | reconcile | `graphs/urban/urban-passage-um-reconcile/` | active |
| urban-sqlite-accesscode-migrate-verify | probe | `graphs/urban/urban-db-accesscode-migrate/` | active |
| urban-signalr-online-probe | probe | `graphs/urban/urban-signalr-online-probe/` | active |
| solidwaste-missing-join-pair | ingest | `graphs/materialclient/solidwaste-pair-ingest/` | active |
| recycle-site-db-export | transform | `graphs/materialclient/recycle-wenyixilu-export/` | active |
| waybill-softdelete-join-gap | probe | `graphs/materialclient/waybill-softdelete-join-probe/` | active |
| solidwaste-oct-export-include-soft-masters | transform | `graphs/materialclient/solidwaste-oct-export-include-softdelete/` | active |
| solidwaste-legacy-independent-net-flag | ingest | `graphs/materialclient/solidwaste-legacy-net-flag-ingest/` | active |
| urban-busy-weighing-sim | transform | `graphs/materialclient/urban-busy-weighing-sim/` | active |
| urban-stable-upload-cache-replay | transform | `graphs/materialclient/urban-stable-upload-cache-replay/` | active |
| urban-stable-upload-cache-probe | probe | `graphs/materialclient/urban-stable-upload-cache-probe/` | active |
| standard-solidwaste-schema-upgrade-verify | probe | `graphs/materialclient/standard-solidwaste-schema-upgrade/` | active |
| materialclient-working-db-load | probe | `graphs/materialclient/materialclient-working-db-load/` | active |
| ops-ssh-agent | probe | `graphs/ops/ssh-agent/` | active |
| ops-fev-u1-host | probe | `graphs/ops/fev-u1-host/` | active |
| ops-fev-u2-docker | probe | `graphs/ops/fev-u2-docker/` | active |
| ops-fev-u10-uploads-smb | probe | `graphs/ops/fev-u10-uploads-smb/` | active |
| ops-deploy-urban-acceptance | ingest | `graphs/ops/deploy-urban-acceptance/` | active |
| ops-cutover-safety-drill | probe | `graphs/ops/cutover-safety-drill/` | active |
| ops-e2e-urban-phase2 | probe | `graphs/ops/e2e-urban-phase2/` | active |

Retired：`graphs/_retired/2026-09/urban-debug-license-bypass/`（原 `urban-debug-license-bypass`；继任 `urban-license-probe`）。

Retired：`graphs/_retired/2026-09/sand-addbatch-2026-01/`（前任 1 月 sand addBatch；继任同 path 重建）。

Retired：`graphs/_retired/2026-08/postweight/`（原 `gov-inout-record-save`）。

---

## 7. 与仓内其它约定的边界

- **OpenSpec**：SHALL / change tasks 可**指向** Graph；不得把「如何再验收」只写在 `docs/YYYY-MM-DD-*`。
- **根 `AGENTS.md`**：业务仓与 traits；本文件只管 pipelines。
- **`docs/AGENTS.md`**：只管调研笔记目录形态。
- **禁止**：修产品行为塞进 runner；覆盖旧 `runs/`；Agent 把 cook 结果自评为产品通过。

## 8. Handoff 与 Run identity

Contract、Evidence 与 P0–P3 的语义见 [`traits/pipelines-trait.md`](../traits/pipelines-trait.md)。family 词表、`graph.*` 与 Node.js cook 仍以本文件为准。

Cook 或生成前：先按 §3 选型，再读命中 Graph 的 `pipeline.md`、`config.yaml`，以及存在时的 `contract.yaml` 与 `acceptance.md`。步骤也写在 `.agents/skills/pipelines-cook-invoke/SKILL.md`。

引用一次 Run 时使用稳定身份，字段见 [`_shared/evidence/AGENTS.md`](_shared/evidence/AGENTS.md)。DOCS 可以链接该身份，不得把 Pipeline `pass` 写成产品变更许可。Pipeline / DOCS 结论要进入产品行为时，还要 Human `APPROVED` 与 OpenSpec change。

历史 `config.yaml` 的 `expect.level` 保持不变，供现有 cook 读取。新验收说明使用 P0–P3。P3 只由用户判定。
