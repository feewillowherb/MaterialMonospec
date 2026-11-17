# 内存模拟闭环 + FEV headless + 人测页面

知识状态：本机 API FEV 已有证据（见 `evidence/fev-mock-loop/`）；138 复跑仍 PENDING。  
**单元测试对本方案无意义、不做、不作证据。**

## 范围（已确认）

| 包含 | 排除 |
|------|------|
| **UrbanManagement.Recycle**（我方平台 Web；工程现状 `UrbanManagement.XiaoShanResource`，ProductCode **5041**） | **`MaterialClient.Recycle`**（桌面 5020）及任何工控窗体 / 串口 / 客户端上传 |
| 进程内 Mock 状态机 + 四页 Web 交互 | 工控 → 平台第一跳；客户端改造（见 [`02`](02-recycle客户端重构.md)，**本方案不碰**） |

只验证 **据 V1.0 推断的交互状态机**能否在 **UrbanManagement.Recycle Web Mock** 中跑通。  
「模拟过磅」在本方案中是 **Web/API 替身**（`POST /api/loop/simulate-weigh`），**不是** MaterialClient 称重流程。

**不**调用杭州市资源化利用厂接口；**不**声称产品交付（ICD）；**不**启动或依赖 `repos/MaterialClient`。

依据：[`07-市接口交互逻辑与mock闭环.md`](07-市接口交互逻辑与mock闭环.md)、[`traits/fev-trait.md`](../../traits/fev-trait.md)、[`03-urbanmanagement-recycle实现.md`](03-urbanmanagement-recycle实现.md)。

## 可行性问题（FEV）

> 仅在 UrbanManagement.Recycle（XiaoShanResource）内：在不外呼市平台、不涉及 MaterialClient.Recycle 的前提下，进程内 Mock 能否稳定编码「准备腿 + §2.2 出厂/收货两段」的状态迁移，并作为后续 Web 人测的同一套逻辑？

| Verdict 候选 | 何时可写 |
|--------------|----------|
| `FEASIBLE` | headless 场景脚本全绿，且与 `07` 状态表一致 |
| `INFEASIBLE` | 状态机无法表达文档推断的迁移，或 API/UI 无法绑定同一 Store |
| `INCONCLUSIVE` | 宿主/鉴权挡住实验，或场景未覆盖闭环关键边 |

## FEV 怎么跑（已确认）

| 项 | 约定 |
|----|------|
| **主路径** | 对**已启动进程**打 HTTP API 跑通 S1–S8；网页同一内存 Store 可见 |
| **非路径** | **单元测试 / xUnit / `Mvc.Testing`** — 不测、不建、不记入 Verdict |
| **数据** | 进程内 `ResourceMockStore` 内存；与网页同一份状态；重启即回种子 |
| **执行目标** | **正式目标 138**（`:5334`）；**当前阶段先本机** Testing 宿主 |
| **人可见** | API 改的是同一 Store → 打开 Web 运输清单等页能看到阶段变化 |
| **不做** | MaterialClient；真市接口；真库表 |

```text
本机（当前）或 138（下一阶段）
  已启动 XiaoShanResource（内存 Mock）
       │
       ├─ FEV headless：脚本 HTTP 调 /api/*（S1–S8）
       │
       └─ 人测：同一进程上打开网页，看闭环结果
```

| 阶段 | 宿主 | 鉴权 |
|------|------|------|
| 当前 | 本机 `http://127.0.0.1:5341`，`ASPNETCORE_ENVIRONMENT=Testing` | Testing **整站旁路 SSO**（仅实验；138 Production 仍登录） |
| 下一 | `http://192.168.3.138:5334` | 5041 SSO Cookie；脚本带会话或先登录再测 |

## 场景 S1–S8（API，与 `07` 对齐）

| ID | HTTP | 期望 |
|----|------|------|
| S1 | `POST /api/loop/simulate-weigh` | 新建清单；净重=毛−皮；`loopPhase=待补全` |
| S2 | 同上，未知车牌 | `ok=false` |
| S3 | `PUT /api/transports/{id}` 补合同/产品 | `待出厂上报` |
| S4 | `POST /api/transports/report-out` | `已出厂上报` |
| S5 | 补收货 → `POST .../report-receive` | `已闭环` |
| S6 | 未出厂就收货 | `ok=false` |
| S7 | 缺产品出厂 | `ok=false` |
| S8 | 合同/生产/车辆 `batch-report` | 各自已上报；消息含 § 章 |

## Experiment（当前：本机）

1. `Testing` + 占位 `AdminSso__BaseUrl` 启动 XiaoShanResource（内存 Store）。
2. 脚本按 S1→S5 调 API；`GET /api/transports` 核对 `loopPhase`；再跑 S6–S8。
3. 浏览器打开本机站点运输清单，确认人能看到同一条闭环数据。
4. 证据写入 `evidence/fev-mock-loop/<utc>/`；**禁止**对市平台出站。
5. 本机 `FEASIBLE` 后，再把同一脚本指向 **138**（带 SSO）复跑。

### Verdict

- S1–S8 API 全绿、网页能看到对应阶段、无市出站 → **`FEASIBLE`**（仅「内存闭环可演示」）。
- 鉴权/宿主挡死 → **`INCONCLUSIVE`**。
- 状态机与 `07` 冲突 → **`INFEASIBLE`** 或先改 Mock/文档。

`FEASIBLE` ≠ 真第二跳；≠ ICD PASS；≠ 已在 138 验收（138 另记一次证据）。

## 人测勾选（本机或 138）

- [ ] 运输清单能看到 FEV 脚本造出的车次与 `loopPhase`
- [ ] 可继续用页面按钮补全/上报（与 API 同一内存状态）
- [ ] 合同/生产/车辆上报提示可见
- [ ] 故意缺字段有拒绝提示

## 明确不做

- **任何单元测试**（含直调 Store 的 xUnit）：与 API 模拟闭环无关，**不建设、不维护、不引用为 FEV 证据**
- MaterialClient；真市 HTTP；真库表；`Mvc.Testing`
- 把本 FEV 写成产品通过

## 落地顺序

1. **本机 Testing + HTTP API S1–S8** → 网页可见 → `evidence/fev-mock-loop/`（**已做**：`2026-11-16T094422`，本机 Verdict=`FEASIBLE`）。  
2. **同一脚本打 138**（SSO）→ 另记证据。  
3. 人测勾选；失败则修 Mock/文案，不跳真市接口。
