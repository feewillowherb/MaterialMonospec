# 据 V1.0 推测的交互逻辑 + Mock 闭环

知识状态：INFERRED（接口文档推断）/ MOCK（进程内模拟，不外呼市平台）。

依据：[`杭州市资源化利用厂数据接入接口V1.0.md`](../SyncDoc/杭州市资源化利用厂数据接入接口V1.0.md)、[`06-第二跳市接口缺口.md`](06-第二跳市接口缺口.md)。

## 从接口推测的交互（第二跳）

```text
准备腿（可并行）
  车辆  →（可选）§2.6 建档；本地皮重始终服务净重
  合同  → 有 PDF 则先 §2.7 得 filePath → §2.4
  日产量 → §2.5

履约腿（§2.2 两段）
  ① 工控过磅：车牌+毛重+出货照
  ② 平台：命中车辆池 → 净重=毛−皮 → 清单「待补全」
  ③ Web 补：合同号、产品（必填出厂）、可选收货方/地址
  ④ 出厂上报 §2.2：必填 dataNo/pointNumber/carNo/productName/netWeight/outTime/outPhotos
  ⑤ 收货后：补 receivingTime/receivingProof/consignee/consigneeAddress → 同 dataNo 再调 §2.2
  ⑥ 清单「已闭环」
```

状态机（运输清单 `loopPhase`）：

| 阶段 | 含义 | 下一动作 |
|------|------|----------|
| 待补全 | 已有毛皮净与出货照，缺产品或合同 | Web 补全 |
| 待出厂上报 | 出厂最小集齐 | 模拟 §2.2 出厂 |
| 已出厂上报 | 市平台出厂已模拟成功 | 可补收货 |
| 待收货上报 | 收货时间/凭证/收货方齐 | 模拟 §2.2 收货补传 |
| 已闭环 | 出厂+收货均已模拟 | 结束 |

合同 / 日产量：`未上报|已上报`；上报前校验必填；合同附件模拟 §2.7 路径。  
车辆：模拟 §2.6 时用厂级默认补 `companyName`/`approvedLoad`/`vehicleModel`（方案 B），并提示缺口。

## Mock 已实现的操作

| API | 模拟什么 |
|-----|----------|
| `POST /api/loop/simulate-weigh` | 工控过磅：车牌+毛重 → 查皮重 → 建清单（待补全） |
| `PUT /api/transports/{id}` | Web 补全合同/产品/收货方等 |
| `POST /api/transports/report-out` | §2.2 出厂（校验最小集；写 mock filePath） |
| `POST /api/transports/report-receive` | §2.2 收货二次调用 |
| `POST /api/contracts/batch-report` | §2.7 占位 + §2.4 |
| `POST /api/productions/batch-report` | §2.5 |
| `POST /api/vehicles/batch-report` | §2.6（配置默认补缺） |

均 **不** HTTP 调用真实市平台；只改进程内存状态与 `lastMockMessage`。

## 人在页面上怎么走通一条闭环

1. 车辆池确认目标车牌启用且有皮重。  
2. 合同已上报（或先批量上报合同）。  
3. 运输清单：「模拟过磅」输入车牌+毛重 → 出现待补全行。  
4. 编辑补全合同号与产品 → 待出厂上报。  
5. 勾选 →「出厂上报」→ 已出厂上报。  
6. 编辑补收货时间/凭证/收货方 →「收货上报」→ 已闭环。
