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
| `govsync` | 政府平台出站/对接探测与采证 | `xiaoshan-gate` |
| `platform` | 跨产品运维：表导入导出、库同步、冒烟等 | `sqlite-reconcile` |

新增 domain **MUST** 先改本文件词表，再落盘。

### 2.2 元数据（`config.yaml` 顶栏，选型第二刀）

每个 Graph **MUST** 含：

```yaml
id: "<slug>"
created: "2026-08-27"          # YYYY-MM-DD；本 Graph 落盘创建日（必填）
graph:
  product: urban           # materialclient | urban | baseplatform | platform
  domain: govsync          # 与路径 domain 一致
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

# 若日后启用 TS observe（可选）
cd pipelines
pnpm observe -- ./graphs/<domain>/<slug>
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

**可选 TS runtime**：若引入 Node Cook，用 `scripts/Setup-TsEnv.ps1` + pnpm workspace；当前仓库以各 Graph 的 `scripts/`（experimental）为主。

---

## 5. 新建 / 退役清单

**新建**

- [ ] `domain` ∈ 词表；路径 `graphs/<domain>/<slug>/`
- [ ] `config.yaml` 含 `created: YYYY-MM-DD`（当日）与完整 `graph.*`；`domain` 与路径一致
- [ ] 共享引用深度正确（分层：`../../../_shared/...`）
- [ ] 同 `goal` 无第二个 `active`
- [ ] 脚本只放该 Graph 的 `scripts/`，标 `experimental`

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
| gov-xiaoshan-gate-save | probe | `graphs/govsync/xiaoshan-gate/` | active |
| gov-xiaoshan-product-save | probe | `graphs/govsync/xiaoshan-product/` | active |
| login-observe-flaui | observe | `graphs/materialclient/login-flaui/` | active |
| login-observe-devtools | observe | `graphs/materialclient/login-devtools/` | active |
| urban-passage-lpr-probe | probe | `graphs/materialclient/urban-passage-probe/` | active |

Retired：`graphs/_retired/2026-08/postweight/`（原 `gov-inout-record-save`）。

---

## 7. 与仓内其它约定的边界

- **OpenSpec**：SHALL / change tasks 可**指向** Graph；不得把「如何再验收」只写在 `docs/YYYY-MM-DD-*`。
- **根 `AGENTS.md`**：业务仓与 traits；本文件只管 pipelines。
- **`docs/AGENTS.md`**：只管调研笔记目录形态。
- **禁止**：修产品行为塞进 runner；覆盖旧 `runs/`；Agent 宣布 L3 通过。
