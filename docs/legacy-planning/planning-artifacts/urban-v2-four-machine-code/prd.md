---
title: Urban V2 四机器码绑定
created: 2026-08-26
updated: 2026-08-26
status: draft
epic_id: urban-v2-four-machine-code
branch: feat/urban-v2-four-machine-code-binding
---

# PRD：Urban V2 四机器码绑定

**Epic ID**: `urban-v2-four-machine-code`  
**版本**: 0.1（draft）  
**状态**: Draft — Fast path，基于调研定稿；待审阅后转 Architecture  
**创建日期**: 2026-08-26  
**影响范围**: FdSoft.BasePlatform（含 PublicApi）+ UrbanManagement + MaterialClient  
**上游调研**: `docs/2026-08-25-urban-v2-four-machine-code-binding/`  
**工作分支**: `feat/urban-v2-four-machine-code-binding`（全程；完成后再合 `main`）

> 本 PRD 供 PM / 架构 / OpenSpec 衔接使用。机制细节与 Decision 分叉见同目录 `addendum.md`；审计轨迹见 `.decision-log.md`。  
> **BMAD Phase 4（sprint / story / dev-story）本仓库禁用**；实施任务仅由 OpenSpec `tasks.md` 产出。

---

## 0. Document Purpose

定义城管地磅授权 **Urban V2** 的产品能力与验收边界：在**不改变存量 5001（V1）单机覆盖语义**的前提下，让同一项目最多 **4** 台机器 / **4** 个场地同时合法在线称重。下游先走 BMAD Architecture + Epic 切片，再导入主仓库 OpenSpec change；本文件不写实现步骤或 tasks。

## 1. Vision

城管场景常有多场地、多地磅并行作业。现行 ProductCode **5001** 把「一项目一机器码」做成防窜用硬约束：后激活覆盖前机，无法多机并存——这是设计，不是缺陷。

Urban V2 以**新产品码**引入「项目级设备槽 1…4」：发码时选槽、激活写入对应槽、验签改为「本机码 ∈ 非空槽集合」。V1 与 V2 **产品线并行、路径隔离**；系统**不做**产品互斥校验（少代码）；**用户侧**人工只开一种并手动淘汰 V1。多场地客户开通 V2 后即可四机并存。本期不交付解绑 UI，但模型必须允许空槽，以便后期槽位解绑 change。

## 2. Target User

### 2.1 Primary Persona

- **运营/商务（BasePlatform 发码侧）**：为城管项目开通授权、生成激活码；需明确选「设备槽 1–4」，避免发错槽覆盖错机。
- **现场称重员 / 站长（MaterialClient.Urban）**：在指定场地的地磅机上激活并称重；期望本机稳定在线，不被其它场地换机误踢。
- **城管项目同步侧（UrbanManagement）**：继续拉取项目、防篡改验签；须正确区分 V1 相等校验与 V2 成员校验。

### 2.2 Jobs To Be Done

- 同一 ProId 下最多 4 台机器同时合法上传/称重。
- 换某一场地的机器时，只影响该槽，其它场地不停机。
- 存量 5001 项目继续「后激活覆盖」，无需迁移；V1 由用户侧手动淘汰。
- 后期能按槽清空绑定（本期只预留，不交付）。
- 系统不因「互斥」增加 BasePlatform 交叉校验。

### 2.3 Non-Users (v1)

- 不把 5001 客户「静默」升级成四槽。
- 不面向「仅改客户端绕过服务端」的捷径方案。
- 本期不面向「解绑/清空」操作员流程（后期另开 Epic/change）。

### 2.4 Key User Journeys

- **UJ-1. 开通 V2 并激活四场地**  
  运营为项目开通 Urban V2 → 先后为槽 1…4 发激活码（每码带 Slot）→ 四台地磅机各自激活 → 四机均可上传。**Climax**: 四机防篡改均通过。

- **UJ-2. 单场地换机**  
  槽 2 机器损坏 → 运营对槽 2 再发码 → 新机激活 → 旧槽 2 机 DeviceChanged；槽 1/3/4 仍可用。

- **UJ-3. 5001 回归**  
  存量 5001 项目第二台机激活 → 仍覆盖第一台（与今日一致）；V2 逻辑不得污染该路径。

- **UJ-4. 发错槽可感知** *[ASSUMPTION: 发码页展示各槽当前码（遮掩）为默认]*  
  运营发码前看到槽占用状态，降低误覆盖。

## 3. Glossary

| 术语 | 定义 |
|------|------|
| **Urban V1 / 5001** | 现有城管 ProductCode；一项目一机器码；后激活覆盖；F4 严格相等 |
| **Urban V2** | 新增 ProductCode（数值待锁定，见 Open Items）；一项目最多四槽 |
| **Slot / 设备槽** | 项目级槽位 1…4；与场地 1:1；可空（未绑定） |
| **成员校验** | V2：JWT `machineCode` ∈ {非空槽机器码集合} |
| **发码选槽** | 生成激活码时必须指定 Slot；Redis 载荷含 Slot |
| **同槽覆盖** | 槽已占用时用新码激活 = 覆盖该槽；其它槽不动 |
| **DeviceChanged** | 本机所在槽被覆盖或不再属于非空集合时的吊销/重激活信号 |
| **AccessCode / AuthEndTime** | 项目级共享；四槽共用，不按槽拆 |
| **权威源** | BasePlatform `JC_ProductAuthority`（及签发路径）；UM/Client 为消费与同步 |

## 4. Features & Requirements

### 4.1 F1 — 新产品码 Urban V2

- **FR-1** 系统 MUST 提供独立于 5001 的 Urban V2 `ProductCode`，并在 BP / UM / Client 枚举与校验中一致使用。实现期使用魔术占位值 **`5002`**（见 D8）；完工后由用户改值为正式号并全仓对齐确认。
- **FR-2** 5001 路径 MUST 保持单机覆盖与严格相等语义；MUST NOT 被 V2 四槽逻辑改写。
- **FR-3**（D20：**系统 B + 用户侧互斥**）V1（5001）与 V2 MUST 作为独立产品线并行，路径按 `ProductCode` 隔离、互不改写。系统 MUST NOT 实现「同 ProId 已有另一种产品则拒绝开通/激活」等互斥校验（避免 BasePlatform 额外复杂度）。同 ProId 若数据上同时存在两套权威，系统可不拦；**用户侧**（商务/运维发码与开通流程）负责只开一种并手动淘汰 V1。跨产品写库时 MUST 只更新本请求 `ProductCode` 对应权威（隔离 ≠ 互斥）。

### 4.2 F2 — 四槽绑定与发码

- **FR-4** 每个 V2 项目 MUST 支持设备槽 1…4；每槽最多一个机器码；空槽表示未绑定。
- **FR-5** 生成 V2 激活码时 MUST 选择 Slot（1–4）；载荷 MUST 含 `ProId`、`AuthEndTime`、`AccessCode`、`Slot`、`ProductCode`。
- **FR-6** 激活 MUST 写入对应槽；槽已占用则覆盖该槽；MUST NOT 改写其它槽。
- **FR-7** *[ASSUMPTION: D17]* 同一机器码 MUST NOT 同时占用两个槽。
- **FR-8** *[ASSUMPTION: D18]* 同槽同机再次激活 MUST 幂等成功（可刷新 JWT）。
- **FR-9** 发码 UI SHOULD 展示各槽当前机器码（遮掩），降低发错槽风险。

### 4.3 F3 — 签发、验签与刷新

- **FR-10** 每台机 JWT 的 `machineCode` claim MUST 仍为**请求机本机码**（单值），不得改为多码数组。
- **FR-11** V2 服务端防篡改（F4）MUST 对非空槽做成员包含校验；5001 仍相等。
- **FR-12** `LicenseFile` / `RefreshJwt` MUST 使用请求机码，且该码 MUST ∈ 非空四槽；MUST NOT 用「主槽」替其它机签发。
- **FR-13** 客户端 `StaticLicenseChecker` MUST 继续要求 JWT claim 等于本机码。

### 4.4 F4 — 同步与目录

- **FR-14** 项目目录 / Catalog MUST 接纳 V2：至少一个非空槽即可入目录（与后期解绑后槽空兼容）。
- **FR-15** UrbanManagement 拉取与激活代理 MUST 同步四槽且禁止无脑覆盖其它槽。
- **FR-16** AccessCode 与 AuthEndTime MUST 项目级单值，四槽共享。

### 4.5 F5 — 客户端体验

- **FR-17** MaterialClient MUST 能以 V2 ProductCode 激活；本地仍只持久化本机码 + JWT。
- **FR-18** DeviceChanged MUST 仅在本机所在槽被覆盖（或本机不再属于非空集合）时触发。
- **FR-19** *[ASSUMPTION: D29]* 本期项目信息 UI 仍展示本机一码；「已占用 n/4」可二期。

### 4.6 F6 — 解绑预留（本期不交付能力）

- **FR-20** 本期 MUST NOT 交付解绑 UI/API。
- **FR-21** 数据模型与契约 MUST 允许槽为空、按 Slot 寻址，并预留后期 `UnbindSlot`（或等价）扩展点（D37）。
- **FR-22** MUST NOT 将「永不解绑」或「槽永不可空」写进最终语义。

## 5. Non-Functional

- **NFR-1 兼容 / 并行**：存量 5001 激活、覆盖、目录过滤、客户端门闩回归通过；V2 上线后 5001 仍可独立运行直至用户手动淘汰。
- **NFR-1b BasePlatform 复杂度**：V2 增量优先「新产品码分支 + 四槽子表 + Catalog 过滤扩码」；**禁止**为 D20 增加互斥表、互斥 API、开通前交叉查询或「废止另一产品」逻辑。
- **NFR-2 安全**：防窜用强度不因 V2 下降；成员校验仅认非空槽。
- **NFR-3 可演进**：存储与 API 选型须支持后期按槽置空（见 addendum D9/D37）。
- **NFR-4 跨仓一致**：ProductCode 数值、Slot、激活/目录契约在三仓同日锁定后实现。
- **NFR-5 编码约定**：跨仓 C# 多值组合用命名 `record`，禁止 tuple（AGENTS）。

## 6. Success Metrics

| 指标 | 目标 |
|------|------|
| V2 最多四机并存上传 | 4/4 机防篡改 Pass |
| 单槽覆盖隔离 | 覆盖槽 N 不导致其它槽 DeviceChanged |
| 5001 回归 | 后激活仍踢前机 |
| 本期无解绑入口 | 无 UI/API；模型可空槽 |
| 第 5 槽 | 发码仅允许 1–4 |

**Counter-metric**：不得以「改 5001 成四槽」或「仅改 Client」达成上述指标。

## 7. Out of Scope（本期）

- 系统侧 V1/V2 互斥校验、开通前交叉检查、自动废止另一产品
- 解绑 / 清空 UI 与 API（后期 `add-urban-v2-slot-unbind` 或同等）
- 场地显示名 `SiteName` 挂槽（二期）
- 5001→V2 自动数据迁移工具
- 逗号拼接多码进单字段
- 改写 5001 全局行为
- UX 专项设计（发码页增量即可，不单独立项 UX 文档）
- BMAD sprint / story 实施清单

## 8. Open Items / Locked Defaults

| ID | 项 | 结论 | 状态 |
|----|----|------|------|
| D8 | V2 ProductCode 数值 | 魔术占位 **`5002`**（全仓暂用）；**完工后由用户改正式值并确认**（`JC_Product` / 枚举 / Catalog / Activate 一次性替换） | **已占位（非最终商务锁定）** |
| D9 | 四槽存储形态 | **子表/多行（可空）** | **已锁定默认** |
| D10 | Catalog 契约 | 同端点扩展 `ProductCode ∈ {5001, 5002}`；入目录=有绑定；本期不暴露四槽明细；同 ProId 双产品可两行（不做 BP 合并） | **已锁定默认** |
| D11 | 激活 API | **扩展现有 `ActivateUrban`**（载荷兼容 V2+Slot）；仅当无法兼容时再考虑 `ActivateUrbanV2` | **已锁定默认** |
| D20 | V1/V2 关系 | **系统 B + 用户侧互斥**：不做代码互斥；用户侧只开一种并手动淘汰 V1；BP 不增互斥复杂度 | **已锁定** |

完整分叉表见调研 `03-openspec-decision-checklist.md` 与本目录 `addendum.md`。

## 9. Delivery Shape（规划侧，非 tasks）

建议下游拆为可独立 OpenSpec 的切片（Architecture / CE 阶段定稿）：

1. **BP 权威**：V2 产品注册 + 四槽存储 + 发码选槽 + 激活/签发/Catalog  
2. **UM 消费**：四槽同步 + F4 成员分支 + 拉取接纳 V2  
3. **Client**：V2 ProductCode 激活 + DeviceChanged 语义 + 回归  

实现顺序硬约束：**BP → UM → Client**。联调与 5001 回归可挂在末切片或独立验收切片。

## 10. References

- `docs/2026-08-25-urban-v2-four-machine-code-binding/00-调研总览.md`
- `docs/2026-08-25-urban-v2-four-machine-code-binding/01-现状与链路分析.md`
- `docs/2026-08-25-urban-v2-four-machine-code-binding/02-改动范围与落地评估.md`
- `docs/2026-08-25-urban-v2-four-machine-code-binding/03-openspec-decision-checklist.md`
- 仓库方法论：`docs/operation-manual.md`（BMAD Phase 1–3 → OpenSpec）
