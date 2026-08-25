# 03 — OpenSpec 可能遇到的 Decision

开 `add-urban-v2-four-machine-code`（或同等命名）时，下列条目应进入 `design.md` 的 Decision Log（或明确标为 Out of Scope）。  
**D1–D7** 已在调研确认，可直接写入；**D8+** 为 propose/design 阶段高频分叉，需在写 tasks 前收口或采用「建议默认」。

> effort 只进 `.openspec.yaml`，不要写进 `proposal.md` / `design.md` 正文当工期表。

## A. 已确认（直接写入 design）

| ID | Decision | 结论 | 写入提示 |
|----|----------|------|----------|
| D1 | 目标场景 | 最多 4 台**同时在线**称重；非主备 | 与「仅换机体验」划清边界 |
| D2 | 槽位与发码 | 发码必选槽 **1…4**；激活写入对应槽 | Redis 载荷含 `Slot` |
| D3 | 换机策略 | 同槽覆盖；其它槽不动 | 验收：覆盖槽 N 不踢其它槽 |
| D4 | AccessCode / AuthEndTime | 项目级单值，四槽共享 | 不按槽拆有效期 |
| D5 | 解绑 / 清空 | **本期不做** UI/API；换机靠发码覆盖；**后期必做槽位解绑**；本期须**预留扩展空间**（见 D37） | Out of Scope 写「本期不交付」；design 写「后期能力 + 预留约束」 |
| D6 | 产品形态 | **新 ProductCode（Urban V2）**；5001 行为不变 | 禁止「顺手改 5001 成四槽」 |
| D7 | 绑定上限 | 每项目最多 **4** 机器码 / **4** 场地（槽 1:1） | 发码 UI 无第 5 槽 |

## B. 开 OpenSpec 前宜收口（阻塞 tasks 细化）

| ID | Decision | 选项 | 建议默认 | 若不定则会卡在 |
|----|----------|------|----------|----------------|
| D8 | V2 `ProductCode` **数值** | 如 `5002` / 其它空号 | **待与 BP `JC_Product` 锁定**（候选 `5002`） | 枚举、Catalog 过滤、Activate 校验、客户端 |
| D9 | 四槽**存储形态**（BP 权威） | (a) `MachineCode`…`MachineCode4` 列 (b) 子表/多行 (c) 复用 `Material_MachineCode`+隔离 | **(b) 子表/多行**（利后期按 Slot 解绑/清空；须与物料 AuthType 隔离若选 c） | 迁移、Activate SQL、Catalog 契约、**D37 预留** |
| D10 | **Catalog** 契约 | (a) 同端点扩展 `ProductCode ∈ {5001,V2}` (b) 新端点/参数 (c) 对外暴露四槽字段 vs 仅「有绑定即可」 | **(a)**；对外至少保证「任一槽非空可入目录」；四槽明细是否对外 **二期可定** | `GovProjectPullManager`、目录过滤丢项目 |
| D11 | 激活 API 形态 | (a) 扩展现有 `ActivateUrban` 支持 V2+Slot (b) 新 `ActivateUrbanV2` | **(a)** 若载荷可兼容；否则 (b) 避免污染 5001 | PublicApi / UM 代理 / 客户端 URL |

## C. design 阶段常见分叉（建议默认，可改）

### C1 BasePlatform / PublicApi

| ID | Decision | 选项 | 建议默认 |
|----|----------|------|----------|
| D12 | JWT `machineCode` claim | (a) 仍单值=请求机 (b) 数组多码 | **(a)** 单值=请求机；权威允许多槽在服务端 |
| D13 | JWT `aud` / 客户端标识 | (a) 仍 `MaterialClient.Urban` (b) 新 audience 给 V2 | **(a)** 除非要强制旧客户端无法吃 V2 令牌 |
| D14 | `RefreshJwt` / `LicenseFile` 入参 | (a) 必须带请求机且 ∈ 四槽 (b) 仍用权威「主槽」签发 | **(a)**；禁止 (b) |
| D15 | 发码 Redis 载荷 | 必含 `ProId` / `AuthEndTime` / `AccessCode` / **`Slot`** / `ProductCode` | 与 D2 一致；缺 Slot → 拒绝发码或拒绝激活 |
| D16 | 发码 UI 槽展示 | (a) 仅下拉 1–4 (b) 展示各槽当前码（遮掩） | **(b)** 降低发错槽风险 |
| D17 | 同机占两槽 | (a) 拒绝 (b) 允许 | **(a) 拒绝** |
| D18 | 同槽同机再激活 | (a) 幂等刷新 JWT (b) 当错误 | **(a)** |
| D19 | 空槽激活 | 允许写入空槽 | 是（占用名额） |
| D20 | 5001 与 V2 同项目并存 | (a) 允许同一 ProId 两行产品授权 (b) 互斥 | **建议 (b) 互斥或商务规则明确**；须在 design 写清，避免双权威 |

### C2 UrbanManagement

| ID | Decision | 选项 | 建议默认 |
|----|----------|------|----------|
| D21 | `GovProject` 四槽落库 | (a) 四列 (b) JSON/子集合 (c) 5001 仍单字段、V2 另表/另列组 | **与 D9 对齐**；5001 路径勿改语义 |
| D22 | F4 分支 | V2：`jwt ∈ 槽集合`；5001：仍 `==` | **必须按 ProductCode（或项目授权类型）分支** |
| D23 | `RefreshJwt` 传参来源 | (a) JWT claim 本机码 (b) `GovProject` 单字段 | **(a)** |
| D24 | 拉取同步对 V2 | 接受 catalog 中 V2；写入四槽 | 跳过非 `{5001,V2}` 保持现逻辑扩展 |
| D25 | 本地是否持久化 ProductCode | (a) `GovProject` 增字段 (b) 仍不持久、靠配置/授权行推断 | **倾向 (a) 或可推断的权威来源**，否则 F4 无法稳分支 |

### C3 MaterialClient

| ID | Decision | 选项 | 建议默认 |
|----|----------|------|----------|
| D26 | 客户端产品入口 | (a) 新 `ProductCode` + 可选新 `WeighingMode` (b) 仅 ProductCode，模式仍 UrbanMode | **(b)** 若业务 UI 与 5001 相同；仅授权码不同 |
| D27 | 本地 `LicenseInfo` | 仍只存本机码 + JWT | **不变**（不存四槽列表） |
| D28 | DeviceChanged 触发 | 仅本机所在槽被覆盖 | **不变语义、扩到四槽** |
| D29 | 项目信息 UI | (a) 仍显示本机一码 (b) 显示占用 n/4 | **(a) 本期；(b) 二期** |
| D30 | 离线授权文件 `.urban` | V2 是否支持同下载路径 | 与 BP「下载按钮」规则对齐；须在 specs 写清 |

### C4 范围 / 兼容 / 非目标

| ID | Decision | 选项 | 建议默认 |
|----|----------|------|----------|
| D31 | 5001→V2 数据迁移 | (a) 工具迁移单码→槽1 (b) 不迁移，商务重开 V2 | **(b)**（调研默认）；若要 (a) 单独立项 |
| D32 | 场地显示名 `SiteName` | 本期挂槽 vs 二期 | **二期** |
| D33 | 独立解绑/清空 API（**本期**） | 做 vs 不做 | **本期不做**（D5）；**禁止**在 design 写成「永不解绑」 |
| D34 | 逗号拼接单字段多码 | 做 vs 不做 | **不做** |
| D35 | 仅改 UM/Client | — | **禁止**；BP 为阻塞依赖 |
| D36 | tuple 多返回值 | — | **禁止**；跨仓 C# 用命名 `record`（AGENTS） |
| D37 | **后期解绑预留** | 本期是否预留可扩展点 | **必须预留**（见下方「预留清单」）；另开 change 实现解绑 |

## D37 预留清单（本期须满足，后期解绑另开 change）

本期**不**交付解绑按钮 / Unbind API / 清空权限流，但实现时须满足：

| 层 | 预留要求 | 避免 |
|----|----------|------|
| **数据模型** | 槽以稳定 `Slot`（1–4）寻址；机器码允许 **null/空 = 未绑定**；F4/签发只认**非空槽**集合 | 把「有行就必须有码」写死；无法表示空槽 |
| **存储选型（D9）** | 优先子表/多行或「可空列」；若四列，每列必须可单独置空 | 逗号拼接；解绑只能整行删授权 |
| **BP API 契约** | 激活/查询按 Slot；design 预留后期 `UnbindSlot(proId, slot)`（或等价）扩展点，**本期可不实现** | 对外只暴露「整项目一个 MachineCode」且无法演进 |
| **UM / Catalog** | 同步四槽时可空；目录「任一非空即可」与后期「解绑后槽空」兼容 | 假设四槽永远占满或永远非空 |
| **换机 vs 解绑** | 本期换机 = 同槽覆盖；后期解绑 = 槽置空且旧机 DeviceChanged | 用覆盖冒充解绑写进「最终语义」 |
| **OpenSpec** | `design` / `proposal` Out of Scope：**本期不交付解绑**；**Future work**：槽位解绑；specs 可加非规范性「后期」备注，或另开 `add-urban-v2-slot-unbind` | 把解绑写进本期 tasks 却不做；或写死永不做 |

后期解绑验收（预告，非本期）：指定槽清空后，该槽旧机吊销；其它槽仍可用；空槽可再次发码激活；Catalog/F4 与空槽一致。

## D. 写入 OpenSpec 时的建议结构

`design.md` 建议分块：

```text
## Decisions
### Product (D1–D7, D8, D20, D31)
### Storage & API (D9–D11, D15–D16, D37)
### Token & F4 (D12–D14, D22–D23)
### Client (D26–D30)
### Out of Scope / Future (D5, D33 本期不交付解绑; D32; D37 预留; 后期 add-*-slot-unbind)
```

`proposal.md` Impact 至少点名：

- `repos/FdSoft.BasePlatform`（+ PublicApi 若仓外）
- `repos/UrbanManagement`
- `repos/MaterialClient`
- Catalog / pull-sync specs（若改过滤）

`tasks.md` 按仓分列；**先 BP 四槽权威，再 UM F4，再 Client**。

## E. 收口检查清单（propose 前勾选）

- [ ] D8 ProductCode 数值已锁定并写入 design  
- [ ] D9 存储形态已选，并说明 5001 路径隔离  
- [ ] D10 Catalog 过滤与是否对外暴露四槽已定  
- [ ] D11 激活 API 扩展 vs 新建已定  
- [ ] D20 同项目 5001/V2 并存或互斥已定  
- [ ] D12–D14 签发/刷新用请求机 ∈ 四槽已写进 specs 场景  
- [ ] D5/D33：**本期不交付**解绑写进 Out of Scope；**D37 预留**写进 design（非「永不解绑」）  
- [ ] D9 选型已考虑后期按 Slot 置空  
- [ ] `.openspec.yaml` `effort.tier: XL`（或按拆分后的 change 调整）
