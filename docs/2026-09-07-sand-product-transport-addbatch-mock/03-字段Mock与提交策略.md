# 03 · 字段 Mock 与提交策略

## 1. 字段生成规则

| 字段 | Mock 规则（已锁定） |
|------|-----------|
| `dataNo` | **Recycle 同构**：`fl-{outTime:yyyyMMddHHmmss}-{当日序号:D4}`（Sending / `Waybill.GenerateOrderNo`）；按日对车次排序后编号；重跑相同 → 平台幂等（Q7） |
| `dataStatus` | `0` |
| `pointNumber` | dryRun 可用占位；**真实 POST 前由用户输入**（Q3） |
| `carNo` | **Q9**：文一西路池 `PlateNumber`；与同条 `outPhotos` 绑定 |
| `carrierCompanyName` | 可选；可省略 |
| `productName` | 固定 **`沙加石`**（Q4） |
| `netWeight` | 19–23 t（Q5）；**不读池** `TotalWeight` |
| `tareWeight` | 13–14.5 t（Q5）；不读池 |
| `grossWeight` | `net+tare`，目标 33–37 t（Q5）；不读池 |
| `outTime` | 2026 任意日；主窗口 **06:00–17:30**，**允许**少量边界外（Q1/Q2）；**且** `dayPart` 须与所绑池图 `captureClock` 同档（Q9） |
| `outPhotos` | **Q9**：池内 `ResolvedPhotoPath` → Base64（无 Data URL 头）；禁止再用单一夹具图冒充全量 |
| `consignee` | 月表收货公司全名（Q8） |
| `consigneeAddress` / `receivingTime` / `receivingProof` / `saleContractNo` / `unitPrice` / `payAmount` | **不传**（Q6） |

**禁止**把月表「序号」当 `dataNo`；**禁止**使用 `sl-` 前缀（进场 Receiving）。  
**禁止**白天抓拍配夜晚 `outTime`（或相反）；**禁止**用池重量覆盖 Q5。

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

### 示例（单条，照片省略）

```json
{
  "dataNo": "fl-20260203061722-0042",
  "dataStatus": 0,
  "pointNumber": "<user-provided-after-dryRun>",
  "carNo": "浙A12B34",
  "productName": "沙加石",
  "netWeight": 21.30,
  "tareWeight": 14.20,
  "grossWeight": 35.50,
  "outTime": "2026-02-03 06:17:22",
  "outPhotos": "<base64>",
  "consignee": "杭州三野建材有限公司"
}
```

## 2. 配置与密钥

```yaml
# config.example.yaml
apiBaseUrl: https://{host}
path: /dataCenter/resourcePlace/productTransportRecord/v1/addBatch
pointNumber: ""          # Q3：dryRun 验收后由用户填写
productName: 沙加石       # Q4 强制
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
| 幂等 | `dataNo=fl-…` 与 Recycle OrderNo 同构；平台按 dataNo 去重，可安全重试（Q7） |
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
    reports/
      summary.json
      submit-log.jsonl
```

实现语言任选：PowerShell（与现 pipelines 一致）、Python、Node；**不强制**进 MaterialClient。

## 5. 验收清单

- [ ] 每收货公司每月 `Σ netWeight` 与 `_tmp/data.md` 差 ≤ 0.01
- [ ] `productName` 均为 `沙加石`；`consignee` 为月表收货公司名称；无收货完成字段
- [ ] `dataNo` 形如 `fl-yyyyMMddHHmmss-0001`；同日序号递增
- [ ] `outTime` 多数在 06:00–17:30，允许少量边界外；任意日历日
- [ ] **Q9**：抽查 `carNo`+图来自文一西路池；`dayPart(outTime)==dayPart(captureClock)`；净/皮/毛**未**抄池重量
- [ ] 净/皮/毛落在 Q5 区间且 `gross≈net+tare`
- [ ] `dryRun` 抽查 JSON；**pointNumber 由用户提供后再**试跑 POST
- [ ] 全量 `summary` 与 518065.31 对齐
