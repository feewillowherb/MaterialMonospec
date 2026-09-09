# sand-addbatch-2026-01 report

- submitEnabled: **false** (no POST)
- month: 2026-01
- pointNumber: XNYH20251113001
- dataNo: `fl-xnyh20251113001-{yyyyMMddHHmmss}-{seq:D4}`
- trips: 5900
- ledger: 5900 rows
- monthSum: 123344.32 / target 123344.32
- pool: 3402 (day=2582, night=820)
- dayPart aligned: 5900/5900
- output: json/ + ledgers/dataNo-ledger.jsonl + submit-meta.json

## Per consignee

- 杭州临平腾满建筑材料商行（个体工商户）: sum=56331.1 target=56331.1 delta=0 trips=2684 ok=true products={"再生细骨料":1342,"再生粉料":1342}
- 杭州三野建材有限公司: sum=18109.28 target=18109.28 delta=0 trips=865 ok=true products={"再生细骨料":433,"再生粉料":432}
- 杭州永武建材有限公司: sum=15468.33 target=15468.33 delta=0 trips=741 ok=true products={"再生细骨料":371,"再生粉料":370}
- 安吉起陆建材有限公司: sum=15445.25 target=15445.25 delta=0 trips=744 ok=true products={"再生细骨料":372,"再生粉料":372}
- 浙江锦秋建材有限公司: sum=17990.36 target=17990.36 delta=0 trips=866 ok=true products={"再生细骨料":433,"再生粉料":433}

## Levels

- L0: pass
- L1: pass
- L2: pass
- L3: pending-user-params-review

等待用户验收待 POST JSON 参数，尚未通过。本图禁止 POST。
