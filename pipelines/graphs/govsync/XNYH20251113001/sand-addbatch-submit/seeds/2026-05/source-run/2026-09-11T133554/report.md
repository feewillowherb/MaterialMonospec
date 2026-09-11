# sand-addbatch-2026-05 report

- submitEnabled: **false** (no POST)
- month: 2026-05
- pointNumber: XNYH20251113001
- dataNo: `fl-xnyh20251113001-{yyyyMMddHHmmss}-{seq:D4}`
- trips: 2127
- ledger: 2127 rows
- monthSum: 104087.05 / target 104087.05
- pool: 3402 (day=2582, night=820)
- dayPart aligned: 2127/2127
- Q11 quietWeekends: [{"day":31,"mode":"zero"},{"day":16,"mode":"zero"}]
- Q11 rateDistinct=true activeSpreadOk=true quietZeroOk=true
- output: json/ + ledgers/dataNo-ledger.jsonl + submit-meta.json

## Per consignee

- 杭州临平腾满建筑材料商行（个体工商户）: sum=46318.5 target=46318.5 delta=0 trips=933 activeDays=12/31 rate=0.4 ok=true products={"再生细骨料":467,"再生粉料":466}
- 杭州三野建材有限公司: sum=15962.7 target=15962.7 delta=0 trips=331 activeDays=23/31 rate=0.78 ok=true products={"再生细骨料":166,"再生粉料":165}
- 杭州永武建材有限公司: sum=13815.71 target=13815.71 delta=0 trips=286 activeDays=19/31 rate=0.65 ok=true products={"再生细骨料":143,"再生粉料":143}
- 安吉起陆建材有限公司: sum=14321.93 target=14321.93 delta=0 trips=292 activeDays=15/31 rate=0.52 ok=true products={"再生细骨料":146,"再生粉料":146}
- 浙江锦秋建材有限公司: sum=13668.21 target=13668.21 delta=0 trips=285 activeDays=26/31 rate=0.9 ok=true products={"再生细骨料":143,"再生粉料":142}

## Levels

- L0: pass
- L1: pass
- L2: pass
- L3: pending-user-params-review

等待用户验收待 POST JSON 参数，尚未通过。本图禁止 POST。
