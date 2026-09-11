# sand-addbatch-2026-03 report

- submitEnabled: **false** (no POST)
- month: 2026-03
- pointNumber: XNYH20251113001
- dataNo: `fl-xnyh20251113001-{yyyyMMddHHmmss}-{seq:D4}`
- trips: 2258
- ledger: 2258 rows
- monthSum: 110805.06 / target 110805.06
- pool: 3402 (day=2582, night=820)
- dayPart aligned: 2258/2258
- Q11 quietWeekends: [{"day":14,"mode":"low"},{"day":29,"mode":"zero"}]
- Q11 rateDistinct=true activeSpreadOk=true quietZeroOk=true
- output: json/ + ledgers/dataNo-ledger.jsonl + submit-meta.json

## Per consignee

- 杭州临平腾满建筑材料商行（个体工商户）: sum=53794.45 target=53794.45 delta=0 trips=1085 activeDays=27/31 rate=0.9 ok=true products={"再生细骨料":543,"再生粉料":542}
- 杭州三野建材有限公司: sum=16139.43 target=16139.43 delta=0 trips=332 activeDays=20/31 rate=0.65 ok=true products={"再生细骨料":166,"再生粉料":166}
- 杭州永武建材有限公司: sum=13468.36 target=13468.36 delta=0 trips=276 activeDays=16/31 rate=0.52 ok=true products={"再生细骨料":138,"再生粉料":138}
- 安吉起陆建材有限公司: sum=12445.17 target=12445.17 delta=0 trips=260 activeDays=24/31 rate=0.78 ok=true products={"再生细骨料":130,"再生粉料":130}
- 浙江锦秋建材有限公司: sum=14957.65 target=14957.65 delta=0 trips=305 activeDays=13/31 rate=0.4 ok=true products={"再生细骨料":153,"再生粉料":152}

## Levels

- L0: pass
- L1: pass
- L2: pass
- L3: pending-user-params-review

等待用户验收待 POST JSON 参数，尚未通过。本图禁止 POST。
