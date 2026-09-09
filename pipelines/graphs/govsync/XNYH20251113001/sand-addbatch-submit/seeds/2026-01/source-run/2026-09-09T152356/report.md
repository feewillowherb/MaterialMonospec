# sand-addbatch-2026-01 report

- submitEnabled: **false** (no POST)
- month: 2026-01
- pointNumber: XNYH20251113001
- dataNo: `fl-xnyh20251113001-{yyyyMMddHHmmss}-{seq:D4}`
- trips: 5879
- ledger: 5879 rows
- monthSum: 123344.32 / target 123344.32
- pool: 3402 (day=2582, night=820)
- dayPart aligned: 5879/5879
- Q11 quietWeekends: [{"day":10,"mode":"zero"},{"day":17,"mode":"low"}]
- Q11 rateDistinct=true activeSpreadOk=true quietZeroOk=true
- output: json/ + ledgers/dataNo-ledger.jsonl + submit-meta.json

## Per consignee

- 杭州临平腾满建筑材料商行（个体工商户）: sum=56331.1 target=56331.1 delta=0 trips=2675 activeDays=24/31 rate=0.78 ok=true products={"再生细骨料":1338,"再生粉料":1337}
- 杭州三野建材有限公司: sum=18109.28 target=18109.28 delta=0 trips=869 activeDays=27/31 rate=0.9 ok=true products={"再生细骨料":435,"再生粉料":434}
- 杭州永武建材有限公司: sum=15468.33 target=15468.33 delta=0 trips=743 activeDays=20/31 rate=0.65 ok=true products={"再生细骨料":372,"再生粉料":371}
- 安吉起陆建材有限公司: sum=15445.25 target=15445.25 delta=0 trips=738 activeDays=16/31 rate=0.52 ok=true products={"再生细骨料":369,"再生粉料":369}
- 浙江锦秋建材有限公司: sum=17990.36 target=17990.36 delta=0 trips=854 activeDays=13/31 rate=0.4 ok=true products={"再生细骨料":427,"再生粉料":427}

## Levels

- L0: pass
- L1: pass
- L2: pass
- L3: pending-user-params-review

等待用户验收待 POST JSON 参数，尚未通过。本图禁止 POST。
