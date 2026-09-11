# sand-addbatch-2026-04 report

- submitEnabled: **false** (no POST)
- month: 2026-04
- pointNumber: XNYH20251113001
- dataNo: `fl-xnyh20251113001-{yyyyMMddHHmmss}-{seq:D4}`
- trips: 2205
- ledger: 2205 rows
- monthSum: 108126.07 / target 108126.07
- pool: 3402 (day=2582, night=820)
- dayPart aligned: 2205/2205
- Q11 quietWeekends: [{"day":19,"mode":"zero"},{"day":12,"mode":"low"}]
- Q11 rateDistinct=true activeSpreadOk=true quietZeroOk=true
- output: json/ + ledgers/dataNo-ledger.jsonl + submit-meta.json

## Per consignee

- 杭州临平腾满建筑材料商行（个体工商户）: sum=48973.2 target=48973.2 delta=0 trips=993 activeDays=26/30 rate=0.9 ok=true products={"再生细骨料":497,"再生粉料":496}
- 杭州三野建材有限公司: sum=15149.74 target=15149.74 delta=0 trips=312 activeDays=23/30 rate=0.78 ok=true products={"再生细骨料":156,"再生粉料":156}
- 杭州永武建材有限公司: sum=13852.38 target=13852.38 delta=0 trips=287 activeDays=19/30 rate=0.65 ok=true products={"再生细骨料":144,"再生粉料":143}
- 安吉起陆建材有限公司: sum=14647.81 target=14647.81 delta=0 trips=297 activeDays=12/30 rate=0.4 ok=true products={"再生细骨料":149,"再生粉料":148}
- 浙江锦秋建材有限公司: sum=15502.94 target=15502.94 delta=0 trips=316 activeDays=16/30 rate=0.52 ok=true products={"再生细骨料":158,"再生粉料":158}

## Levels

- L0: pass
- L1: pass
- L2: pass
- L3: pending-user-params-review

等待用户验收待 POST JSON 参数，尚未通过。本图禁止 POST。
