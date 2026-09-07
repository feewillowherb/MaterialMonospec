# 03 · 字段 Mock 与提交策略

## 1. 字段生成规则

| 字段 | Mock 规则（已锁定） |
|------|-----------|
| `dataNo` | **Recycle 同构**：`fl-{outTime:yyyyMMddHHmmss}-{当日序号:D4}`（Sending / `Waybill.GenerateOrderNo`）；按日对车次排序后编号；重跑相同 → 平台幂等（Q7） |
| `dataStatus` | `0` |
| `pointNumber` | dryRun 可用占位；**真实 POST 前由用户输入**（Q3） |
| `carNo` | 车牌池循环/哈希 |
| `carrierCompanyName` | 可选；可省略 |
| `productName` | 固定 **`沙加石`**（Q4） |
| `netWeight` | 19–23 t（Q5） |
| `tareWeight` | 13–14.5 t（Q5） |
| `grossWeight` | `net+tare`，目标 33–37 t（Q5） |
| `outTime` | 2026 任意日；主窗口 **06:00–17:30**，**允许**少量边界外（Q1/Q2） |
| `outPhotos` | 夹具 Base64（无 Data URL 头） |
| `consignee` | 月表收货公司全名（Q8） |
| `consigneeAddress` / `receivingTime` / `receivingProof` / `saleContractNo` / `unitPrice` / `payAmount` | **不传**（Q6） |

**禁止**把月表「序号」当 `dataNo`；**禁止**使用 `sl-` 前缀（进场 Receiving）。

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
  fixtures/truck.jpg
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
- [ ] 净/皮/毛落在 Q5 区间且 `gross≈net+tare`
- [ ] `dryRun` 抽查 JSON；**pointNumber 由用户提供后再**试跑 POST
- [ ] 全量 `summary` 与 518065.31 对齐
