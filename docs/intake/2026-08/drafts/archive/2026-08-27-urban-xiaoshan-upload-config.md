# 2026-08-27-urban-xiaoshan-upload-config

| 字段 | 值 |
|------|-----|
| status | promoted |
| created | 2026-08-27 |
| theme_guess | xiaoshan-upload（兼 urban-weighing） |
| park_guess | park/xiaoshan-serve |
| source | Agent 会话 /intake-draft |

## 碎片

1. **客户端上传配置 + 服务端可改 + 双向同步 / 一致性**
   - `MaterialClient.Urban` 需要「上传配置」能力。
   - `UrbanManagement` 要能改客户端配置。
   - 客户端配置也要能同步到服务端。
   - 一致性与权威见下方 **已确认决策**。

2. **萧山三模式同步配置（可多选）**
   - Urban 支持设计稿三种同步/上报模式：Weighbridge / Gate / Product（见 `docs/2026-08-27-xiaoshan-weighbridge-gate-product-upload-design`）。
   - **可多选**；**默认选中 Weighbridge**。
   - 三种模式各自可配：`deviceID`、`siteType`、`inOutType`。
   - 其他字段：来自称重流水，或来自静态字段。
   - 非必填且无数据源：可丢弃并**标注**（见 D4）。
   - 上述配置：**服务端可改、客户端也可改**（与碎片 1 强相关）。

3. **配置变更需要日志**（新增）
   - 配置每次变更须留修改日志（谁 / 哪端 / 何时 / 改了什么 / 关联 version）。
   - 用途：审计、排障、人工回放；**不替代** D1/D2 的运行时裁决（裁决仍靠服务端权威 + `configVersion`）。

4. **旧客户端兼容**（新增）
   - 现场并非所有客户端都能及时升级。
   - 服务端 / 协议须兼容旧客户端：缺字段、不懂新模式、不上报 version 等行为要有降级路径，不能因新配置协议直接不可用。
   - 待 promote 时拆清：最低兼容版本、旧客户端读到新配置时的默认行为、是否禁止旧端回写覆盖新字段。

## 续聊笔记

- 证据：`docs/2026-08-27-xiaoshan-weighbridge-gate-product-upload-design/01-设计稿.md`（三通道 Weighbridge/Gate/Product）。
- repos 预期：`MaterialClient`（Urban）、`UrbanManagement`。
- promote 时可能拆成：① 配置模型与双端编辑；② 同步/一致性（version）+ 变更日志；③ 三模式多选与字段映射；④ 旧客户端兼容矩阵。

### 已确认决策（2026-08-27）

| # | 项 | 结论 | 备注 |
|---|-----|------|------|
| D1 | 配置权威端 | **服务端为权威** | 客户端可改，须回写/对齐服务端后才算生效 |
| D2 | 一致性判定 | **仅 `configVersion`（单调递增）即可** | 不做强制 payload hash |
| D3 | 冲突策略 | **采纳**：高 version 胜；同 version 可比时间戳；客户端落后 → 拉取服务端覆盖本地 | |
| D4 | 非必填丢弃标注 | **采纳**：上报路径日志/可观测标明跳过；配置 UI 标「无数据源，跳过」 | 不阻断主流程 |
| D5 | 配置变更日志 | **需要** | 审计用；与 version 并存 |
| D6 | 旧客户端兼容 | **必须兼容**未及时升级的客户端 | 协议/服务端降级；细节 promote 前再拆 |

- 下一步：`/intake-promote`（建议 archive）拆 INT。

## 晋升记录

| 字段 | 值 |
|------|-----|
| promoted_to | INT-001, INT-002, INT-003, INT-004 |
| promoted_on | 2026-08-27 |
| disposition | archive |
| archived_to | docs/intake/2026-08/drafts/archive/2026-08-27-urban-xiaoshan-upload-config.md |
