# sand-addbatch-2026-02 report

- submitEnabled: **false** (no POST)
- month: 2026-02
- pointNumber: XNYH20251113001
- dataNo: `fl-xnyh20251113001-{yyyyMMddHHmmss}-{seq:D4}`
- trips: 1472
- ledger: 1472 rows
- monthSum: 71702.81 / target 71702.81
- pool: 3402 (day=2582, night=820)
- dayPart aligned: 1472/1472
- Q11 quietWeekends: [{"day":14,"mode":"low"},{"day":22,"mode":"low"}]
- Q11 rateDistinct=true activeSpreadOk=true quietZeroOk=true
- output: json/ + ledgers/dataNo-ledger.jsonl + submit-meta.json

## Per consignee

- 杭州临平腾满建筑材料商行（个体工商户）: sum=29538.61 target=29538.61 delta=0 trips=597 activeDays=12/28 rate=0.4 ok=true products={"再生细骨料":299,"再生粉料":298}
- 杭州三野建材有限公司: sum=12483.37 target=12483.37 delta=0 trips=255 activeDays=16/28 rate=0.52 ok=true products={"再生细骨料":128,"再生粉料":127}
- 杭州永武建材有限公司: sum=9062.29 target=9062.29 delta=0 trips=189 activeDays=19/28 rate=0.65 ok=true products={"再生细骨料":95,"再生粉料":94}
- 安吉起陆建材有限公司: sum=9249.88 target=9249.88 delta=0 trips=195 activeDays=25/28 rate=0.9 ok=true products={"再生细骨料":98,"再生粉料":97}
- 浙江锦秋建材有限公司: sum=11368.66 target=11368.66 delta=0 trips=236 activeDays=22/28 rate=0.78 ok=true products={"再生细骨料":118,"再生粉料":118}

## Levels

- L0: pass
- L1: pass
- L2: pass
- L3: pending-user-params-review

等待用户验收待 POST JSON 参数，尚未通过。本图禁止 POST。
