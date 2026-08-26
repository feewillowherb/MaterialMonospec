# Addendum — urban-v2-four-machine-code

机制、分叉选项与 Architecture/OpenSpec 输入。**不替代** `prd.md` 的能力叙述。

## A. 建议默认（可被 Architecture 推翻）

| ID | Topic | Default | Rationale |
|----|-------|---------|-----------|
| D8 | ProductCode 数值 | 魔术占位 **`5002`** | 实现/联调用；**完工后用户改正式值并全仓确认**；常量宜单点定义（如 `UrbanV2ProductCode = 5002`）便于替换 |
| D9 | 存储 | **子表/多行，槽可空**（已锁定） | 利 D37 按 Slot 清空；与 5001 单字段隔离 |
| D10 | Catalog | **同端点扩展 `∈ {5001, 5002}`**；入目录=有绑定；响应**不暴露四槽**；同 ProId 双产品可两行（已锁定） | 少 BP 合并/互斥逻辑；四槽明细二期可定 |
| D11 | 激活 API | **扩展 `ActivateUrban`**（V2+Slot）；不兼容时才 `ActivateUrbanV2`（已锁定） | 优先单路径，降 BP 复杂度 |
| D12 | JWT machineCode | 仍单值=请求机 | Client StaticLicenseChecker 不变 |
| D13 | aud | 仍 `MaterialClient.Urban` | 除非要强制旧客户端拒 V2 令牌 |
| D14 | Refresh/LicenseFile | 请求机 ∈ 非空四槽 | 禁止「主槽」代签 |
| D16 | 发码 UI | 展示各槽当前码（遮掩） | 降发错槽 |
| D17 | 同机两槽 | 拒绝 | 避免浪费名额 |
| D18 | 同槽同机再激活 | 幂等刷新 JWT | |
| D20 | V1/V2 关系 | **系统 B + 用户侧互斥（已锁定）** | 系统不写互斥；用户侧人工只开一种并淘汰 V1；BP 仅按 ProductCode 分路径，禁止交叉废止/互斥查询 |
| D26 | Client 入口 | 仅新 ProductCode；WeighingMode 仍 Urban | UI 与 5001 同 |
| D29 | 占用 n/4 UI | 二期 | |
| D31 | 5001→V2 迁移 | 不迁移；商务重开 V2 | |
| D32 | SiteName | 二期 | |
| D33 | 本期 Unbind | 不做 | 与 D5 一致；禁止写成永不做 |

## D37 预留清单（Architecture 必须吸收）

| 层 | 要求 | 禁止 |
|----|------|------|
| 模型 | Slot 1–4 寻址；机器码可 null/空；F4 只认非空集合 | 有行就必须有码 |
| 存储 | 子表或可空列 | 逗号拼接 |
| BP 契约 | 按 Slot 激活/查询；预留 UnbindSlot 扩展点 | 对外永远「整项目单 MachineCode」且无法演进 |
| UM/Catalog | 同步可空槽；目录「任一非空」 | 假设四槽永满 |
| 换机 vs 解绑 | 本期=覆盖；后期=置空 | 用覆盖冒充最终解绑语义 |

## Catalog 契约详解（D10）

### 今天（V1）在做什么

权威端点：`GET /Api/ProjectCatalog/ListProjects`（`FdSoft.BasePlatform.PublicApi`）。

| 维度 | 现行契约（`openspec/specs/baseplatform-project-catalog-api`） |
|------|------|
| 过滤 | 仅 `JC_ProductAuthority` 且 `ProductCode = 5001`、`MachineCode` **非空**、`DeleteStatus = 0` |
| 响应字段 | `proId`, `proName`, `productCode`, `proAddress`, `shigongUnitName`, `buildLicenseNo`, `fdBuildLicenseNo`, `authEndTime` |
| `productCode` | 项内恒为 `5001` |
| **不含** | 机器码、槽位、密钥类字段 |
| 鉴权 | `X-Api-Key`；分页有上下限 |

消费方：UrbanManagement `GovProjectPullManager`（`openspec/specs/gov-project-baseplatform-pull-sync`）

| 维度 | 现行消费契约 |
|------|------|
| 边界校验 | 只接受 `productCode == 5001`；其它码 **跳过 + 告警**，不落库 |
| 写入 | 同步 catalog 字段到 `GovProject`；**不**持久化 `productCode` 列 |
| 机器码 | **本 API 不传机器码**；本地 `GovProject.MachineCode` 来自激活代理，不是 pull |

因此 Catalog 的产品职责是：**「哪些城管项目有资格出现在 UM 项目目录里」**，不是「同步四台机器码权威」。

### V2 必须改什么（否则必挂）

若仍只认 `5001` + 单字段非空 `MachineCode`：

1. 纯 V2 授权项目 → **进不了目录** → UM 拉不到 → 现场无项目。
2. 若错误地按「单 MachineCode 列」过滤，而权威已迁到**子表四槽** → 可能误判「无绑定」而丢项目。
3. UM 边界若仍 `== 5001` → 即使 BP 返回 `productCode=5002`，也会被 **跳过**。

### D10 已锁定默认（本期）拆成三层

**① 端点形态（a）— 同端点扩展**

- 仍用 `GET /Api/ProjectCatalog/ListProjects`。
- 过滤改为：`ProductCode ∈ {5001, 5002}`（`5002` = D8 魔术占位）。
- **不做**新路径 / 新 query 专端（除非后期多产品爆炸再拆）。

**② 入目录条件（有绑定即可）**

| ProductCode | 入目录条件 |
|-------------|------------|
| 5001 | 与今相同：权威单字段 `MachineCode` 非空 |
| 5002 (V2) | 四槽子表中 **至少一个 Slot 的机器码非空** |

解绑预留：某槽清空后，只要其它槽仍非空 → 仍在目录；四槽全空 → 出目录（与 5001「无码不出目录」同构）。

**③ 响应是否暴露四槽（本期：否）**

- **本期**：响应字段集合与今相同；**不**加 `machineCode1…4` / `slots[]`。
- 理由：UM pull **本来就不靠 Catalog 写机器码**；四槽权威在激活/签发路径维护。Catalog 只负责「项目可见 + productCode 分流提示」。
- **二期可选**：若外部系统或运维台需要看槽占用，再加只读槽摘要；那是契约增量，不阻塞 V2 主路径。

### 同端点下 `productCode` 的语义（配合 D20：系统 B + 用户侧互斥）

返回行的 `productCode` 为**该条授权**对应的产品码（5001 或 5002）。

- Catalog 可同时列出 V1 与 V2 授权项目（产品线并行）。
- **系统不保证**同 `ProId` 只有一种产品；用户侧流程应避免双开。
- 若同 `ProId` 两套权威都满足「有绑定」，Catalog **允许**出现两行（各带自己的 `productCode`）——比「合并去重 + 互斥优先级」更简单，**少 BP 逻辑**。
- V1 淘汰靠用户停售/停续/停发，不靠系统废止另一产品。

**BasePlatform 复杂度约束（D20）**

| 做 | 不做 |
|----|------|
| V2 独立存储（子表）与 5001 单字段并存 | 开通/激活前查「是否已有另一 ProductCode」 |
| Catalog 过滤扩为 `∈ {5001,5002}`，按权威行出项 | 为同 ProId 合并成一行、选主产品、互斥优先级 |
| Activate / 签发只读写**本请求** ProductCode 的权威 | 「开 V2 清空 5001」或反向互踢 |
| 常量魔术 `5002` 单点替换 | 新互斥表、互斥 API、状态机 |

UM 侧建议（Architecture 落细；复杂推断尽量放消费方而非 BP）：

- 边界：`productCode ∈ {5001, 5002}` 才处理；其它仍跳过。
- 若同 ProId 拉到两行：按 `productCode` 分别处理或由运维清理脏数据；**不要**要求 BP 去重。
- F4 / 本地形态（D25）：以激活或本地可推断的产品类型分支；Catalog alone 不够支撑 F4。

### 与「按 ProId 取 latest」的旧坑

历史双机调研提到：若按 ProId 取「最新一条」且只带单码，会丢槽。  
**V2 子表**：同一 V2 权威下槽不展开成多条 catalog item（一 V2 授权一行）。  
**跨产品**：不要为「同 ProId 的 5001+V2」做 latest 合并；各产品权威各出一行更简单。

### 验收要点（Catalog 相关）

- 仅 V2、已占 ≥1 槽的授权出现在 `ListProjects`，且 `productCode=5002`。
- 仅 5001、有单码的授权仍出现，`productCode=5001`。
- 无绑定（5001 空码 / V2 四槽全空）不出现。
- UM pull：5002 不再被「非 5001」规则丢弃；5001 回归不变。
- 响应仍无机器码/槽数组（本期）。
- **不**验收「同 ProId 系统互斥」；脏双开靠用户侧避免。

## B. 跨仓边界（给 Architecture）

```
BasePlatform (权威)
  Product 注册 / 四槽存储 / 发码+Slot / Activate / JWT 签发 / Catalog
        ↓
UrbanManagement (消费+F4)
  GovProject 四槽同步 / F4 分支 / Refresh 传本机 claim / Pull 接纳 V2
        ↓
MaterialClient (本机)
  V2 ProductCode 激活 / 本地单码 / DeviceChanged / 5001 回归
```

**硬顺序**：BP → UM → Client。禁止只改后两仓。

**BP 增量边界（降复杂度）**：注册 V2 + 四槽子表 + 发码 Slot + 按码激活/签发 + Catalog 扩过滤；**不含** D20 互斥/交叉废止/同 ProId 合并。

## C. OpenSpec 衔接提示

- 建议 change 名：`add-urban-v2-four-machine-code`（或按 CE 切片拆分命名）
- `design.md` Decision 块对照调研 `03-openspec-decision-checklist.md`
- effort **只**写各 change 的 `.openspec.yaml`（合计 XL；拆分后可下调单 change）
- **禁止**在 BMAD 产出 `tasks.md` / Story 任务列表

## D. 调研索引

- `docs/2026-08-25-urban-v2-four-machine-code-binding/`（00–03 + archive）
