# 03 · 字段 Mock 与提交策略

## 1. 字段生成规则

| 字段 | Mock 规则（已锁定） |
|------|-----------|
| `dataNo` | `fl-{pointNumber.toLowerCase()}-{outTime:yyyyMMddHHmmss}-{当日序号:D4}`（例 `fl-xnyh20251113001-20260203061722-0042`）；按日对车次排序后编号；**必须持久化**（见下节 Q7）；重跑相同 → 平台幂等 / 可更新（Q7） |
| `dataStatus` | `0` |
| `pointNumber` | dryRun 可用占位；**真实 POST 前由用户输入**（Q3） |
| `carNo` | **Q9**：文一西路池 `PlateNumber`；与同条 `outPhotos` 绑定 |
| `carrierCompanyName` | 可选；可省略 |
| `productName` | **`再生细骨料`** / **`再生粉料`**，同 consignee×月车次 **1:1**（Q4） |
| `netWeight` | 19–23 t（Q5）；**不读池** `TotalWeight` |
| `tareWeight` | 13–14.5 t（Q5）；不读池 |
| `grossWeight` | `net+tare`，目标 33–37 t（Q5）；不读池 |
| `outTime` | 2026 任意日；主窗口 **06:00–17:30**，**允许**少量边界外（Q1/Q2）；**且** `dayPart` 须与所绑池图 `captureClock` 同档（Q9） |
| `outPhotos` | **Q9**：池内 `ResolvedPhotoPath` → Base64（无 Data URL 头）；禁止再用单一夹具图冒充全量 |
| `consignee` | 月表收货公司全名（Q8） |
| `consigneeAddress` | 查表 [06-收货方到货地址.md](./06-收货方到货地址.md)；首次可暂不传（Q6），**按 `dataNo` 补报/更新时必传** |
| `receivingTime` / `receivingProof` / `saleContractNo` / `unitPrice` / `payAmount` | 首次不传（Q6）；补报时再定 |

**禁止**把月表「序号」当 `dataNo`；**禁止**使用 `sl-` 前缀（进场 Receiving）。  
**禁止**省略 `pointNumber` 小写段（不得退回纯 `fl-{时间}-{序号}`）。  
**禁止**白天抓拍配夜晚 `outTime`（或相反）；**禁止**用池重量覆盖 Q5。  
**禁止**再使用 `沙加石` 作为 `productName`（已废止，见 Q4）。  
**禁止**对已落盘/已提交车次重新生成新的 `dataNo`（见 Q7 持久化）。

### Q7 · `dataNo` 持久化（硬约束）

平台以 `dataNo` 为车次主键：**幂等去重**，且后续可用同一 `dataNo` 再调 §2.2 `addBatch` **更新旧数据**（如补 `consigneeAddress` / 收货字段）。因此：

| 要求 | 说明 |
|------|------|
| 生成即落盘 | dryRun / cook 写出 JSON 的同时，必须写入**可复用台账**（如 `dataNo-ledger.jsonl` 或与 `json/*.json` 同 runs 包内可检索的清单） |
| 稳定重放 | 同一逻辑车次（同一 `seed` + 拆分结果）重跑：**复用已持久化的 `dataNo`**，不得另起新号 |
| 提交后冻结 | 一旦某 `dataNo` 进入「已提交 / 拟提交验收通过」状态，**禁止改号**；更新只带原 `dataNo` + 变更字段 |
| 台账最小列 | `dataNo`、`consignee`、`outTime`、`productName`、`netWeight`、`carNo`、可选 `submitStatus` / `runId` |
| 禁止 | 只写内存不落盘；覆盖旧 runs 导致台账丢失且无备份；用随机 UUID 替代已发布的 `fl-…` |

更新路径示意：

```text
读 dataNo 台账 → 按 consignee 查 06 地址表 → 组装同 dataNo 的 addBatch 元素
  （补 consigneeAddress / receiving*）→ POST → 平台按 dataNo 更新
```

### Q4 · 产品 1:1（实现约束）

```text
对每个 consignee × month 的车次列表（按 outTime 排序后）:
  偶数序 → productName = 再生细骨料
  奇数序 → productName = 再生粉料
  （或等价：交替赋值，使两种产品车次数差 ≤ 1）
守恒仍对「全部车次 Σ netWeight = 月表吨位」；
另验收：两种产品车次数近似 1:1，吨位差不超过约一车净重量级。
```

### 示例（单条，照片省略）

```json
{
  "dataNo": "fl-xnyh20251113001-20260203061722-0042",
  "dataStatus": 0,
  "pointNumber": "<user-provided-after-dryRun>",
  "carNo": "浙A12B34",
  "productName": "再生细骨料",
  "netWeight": 21.30,
  "tareWeight": 14.20,
  "grossWeight": 35.50,
  "outTime": "2026-02-03 06:17:22",
  "outPhotos": "<base64>",
  "consignee": "杭州三野建材有限公司"
}
```


### Q9 · 池抽样顺序（实现约束）

```text
load pool from recycle-wenyixilu-export CSV
  (join records↔attachments↔files; photoFound=true)
  → captureClock from filename or AddDate
  → dayPart ∈ {day:06:00–18:00, night:else}
for each trip after net/tare/gross + calendar day chosen:
  propose outTime (Q2 window / soft margin)
  sample pool where dayPart(captureClock)==dayPart(outTime)
       prefer |H_out−H_cap|≤2
  bind carNo=plate, outPhotos=file→base64
  if no candidate: resample outTime within same calendar day to other hour in needed dayPart
     or reuse same-dayPart pool entry (still plate+photo bound)
```

配置指针示例：

```yaml
platePhotoPool:
  csvDir: pipelines/graphs/materialclient/recycle-wenyixilu-export/out/latest/csv
  requirePhotoFound: true
  preferAttachTypes: [2, 5]   # ExitPhoto, Lpr
  dayPart:
    dayStart: "06:00"
    dayEnd: "18:00"
  hourProximityHours: 2
  ignorePoolWeight: true      # Q9：重量始终 Q5
```

## 2. 配置与密钥

```yaml
# config.example.yaml
apiBaseUrl: https://{host}
path: /dataCenter/resourcePlace/productTransportRecord/v1/addBatch
pointNumber: ""          # Q3：dryRun 验收后由用户填写
productNames: [再生细骨料, 再生粉料]  # Q4
productRatio: "1:1"      # 同 consignee×月车次交替
year: 2026
workCalendar: all-days
businessHours: ["06:00", "17:30"]  # 主窗口；允许少量越界
businessHoursSoftMarginMinutes: 30 # 可略早于 06:00 / 略晚于 17:30
outOfWindowRate: 0.08              # 约 8% 车次落在边界外（可调）
tripNetMin: 19
tripNetMax: 23
tareMin: 13
tareMax: 14.5
grossMin: 33
grossMax: 37
batchSize: 100
requestIntervalMs: 200
seed: 20260907
dryRun: true             # true 只写 out；pointNumber 齐后再 false
```

密钥仅放 `secrets.local.yaml`（gitignore）：`accessKey` / `secretKey`（或与现网 Recycle HMAC 配置同构）。

签名算法对齐文档附录 1 与现有 `RecycleHmacDelegatingHandler` / `_temp/resource-place-api-test`。

## 3. 提交策略

```text
expand 全部 Record
  → 按 outTime 排序
  → chunk(batchSize)
  → 对每个 chunk:
        if dryRun: 写文件
        else: POST Array + HMAC
        记录 batch 结果（code/msg/条数/起止 dataNo）
        sleep(requestIntervalMs)
```

| 策略 | 说明 |
|------|------|
| 分批 | `batchSize` 默认 100 |
| 限速 | 批间 sleep，防限流 |
| 失败 | 记录失败 chunk 索引；支持 `--from-chunk N` 续跑 |
| 幂等 | `dataNo=fl-{point小写}-…`；平台按 dataNo 去重，可安全重试（Q7） |
| 更新 | 同一 `dataNo` 再次 `addBatch` 可改收货等字段；**依赖台账持久化**（Q7） |
| 对账 | 本地 `summary.json`：`consignee×month → ΣnetWeight` vs 月表 |

## 4. 建议落盘结构（脚本产物，勿提交密钥）

```text
docs/2026-09-07-sand-product-transport-addbatch-mock/   # 本方案
_tools/sand-addbatch-mock/                              # 可选实现目录（另建）
  config.example.yaml
  secrets.local.yaml          # gitignore
  seeds/monthly-totals.yaml
  # 车牌/图池：指向 recycle-wenyixilu-export out/latest/csv（Q9）
  # 勿把现场 jpg 提交进 git；运行时读 ResolvedPhotoPath
  out/
    dry-run/
      2026-01-腾满.part000.json
      ...
    ledgers/
      dataNo-ledger.jsonl   # Q7：全量 dataNo 台账（持久化，供更新复用）
    reports/
      summary.json
      submit-log.jsonl
```

实现语言任选：PowerShell（与现 pipelines 一致）、Python、Node；**不强制**进 MaterialClient。

## 5. 验收清单

- [ ] 每收货公司每月 `Σ netWeight` 与 `_tmp/data.md` 差 ≤ 0.01
- [ ] `productName` 仅为 `再生细骨料` / `再生粉料`，同月车次近似 1:1；`consignee` 为月表收货公司名称；无收货完成字段
- [ ] `dataNo` 形如 `fl-{pointNumber小写}-yyyyMMddHHmmss-0001`（例 `fl-xnyh20251113001-…`）；同日序号递增
- [ ] **Q7**：存在持久化 `dataNo` 台账；重跑不改已落盘号；可按台账组装更新载荷
- [ ] 五家 `consignee` 均可在 [06](./06-收货方到货地址.md) 查到 `consigneeAddress`
- [ ] `outTime` 多数在 06:00–17:30，允许少量边界外；任意日历日
- [ ] **Q9**：抽查 `carNo`+图来自文一西路池；`dayPart(outTime)==dayPart(captureClock)`；净/皮/毛**未**抄池重量
- [ ] 净/皮/毛落在 Q5 区间且 `gross≈net+tare`
- [ ] `dryRun` 抽查 JSON；**pointNumber 由用户提供后再**试跑 POST
- [ ] 全量 `summary` 与 518065.31 对齐
