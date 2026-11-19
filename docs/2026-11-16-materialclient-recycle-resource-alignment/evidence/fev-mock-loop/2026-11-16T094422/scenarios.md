# FEV mock loop scenarios (local)

baseUrl: `http://127.0.0.1:5341`
verdict: **FEASIBLE** (pass=15 fail=0)

- **health**: PASS — health/live=200
- **S1**: PASS — phase=待补全 net=51.7
- **S2**: PASS — status=400 msg=未命中启用车辆池：浙Z99999
- **S3**: PASS — phase=待出厂上报
- **S4**: PASS — msg=已模拟 §2.2 出厂 1 条（未外呼）
- **S4-phase**: PASS — phase=已出厂上报
- **S6**: PASS — msg=车次 浙DQ04158 须先完成出厂上报，当前 待补全
- **S7**: PASS — msg=车次 浙DQ04158 未齐 §2.2 出厂最小集（产品/净重/出货时间/出货凭证）
- **S5-enrich**: PASS — phase=待收货上报
- **S5**: PASS — msg=已模拟 §2.2 收货补传 1 条（未外呼）
- **S5-phase**: PASS — phase=已闭环 id=21
- **S8-contract**: PASS — msg=已模拟合同上报 1 条（未外呼）
- **S8-prod**: PASS — msg=已模拟 §2.5 上报 1 条（未外呼）
- **S8-vehicle**: PASS — msg=已模拟 §2.6 上报 1 辆（未外呼市平台）
- **web-same-store**: PASS — id=21 已闭环 — open http://127.0.0.1:5341 运输清单

浏览器查看：`http://127.0.0.1:5341` → 运输清单（Testing 旁路 SSO），找 id **21**，阶段 **已闭环**。
下一阶段：同一脚本打 138 `:5334`。
