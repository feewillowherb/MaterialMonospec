## 0. Branch（Mode B）

- [x] 0.1 确认各仓位于或自 `dev-recycle-resource-alignment` 切出 `refactor-recycle-urban-host-auth`（MaterialMonospec、FdSoft.BasePlatform.PublicApi、FdSoft.BasePlatform、UrbanManagement、MaterialClient；无改动的仓不建）
- [ ] 0.2 合入目标：squash → `dev-recycle-resource-alignment`

## 1. BasePlatform PublicApi — 5020 在线激活

- [x] 1.1 `ActivateUrban`（或等价）放行 ProductCode **5020**；仍要求非空 MachineCode；Redis 消费与回写同 5001
- [x] 1.2 `LicenseFile` / `RefreshJwt` / `LicenseFileAppService` 签发放行 5020
- [ ] 1.3 联调：5020 激活码 + 机器码 → JWT；非 5001/5020 仍拒绝

## 2. BasePlatform 发码（UI 不改）

- [x] 2.1 `SendAuthLicense`：5020 载荷与 5001 同形含 `AccessCode`
- [ ] 2.2 确认产品库存在 5020（缺则补数据，不改管理端页面）

## 3. UrbanManagement Admin — 并存授权

- [x] 3.1 Core `ProductCode` 枚举增加 Recycle=5020；拉取规范化接受 5001 与 5020
- [x] 3.2 `GovProject`（或等价）持久化产品区分，保证同项目双授权不互盖；迁移与唯一约束
- [x] 3.3 Admin 项目管理展示产品；Recycle 行不导航城管称重落点
- [x] 3.4 如需：Recycle 激活代理（对齐 Urban Ingest activate，产品码 5020）

## 4. MaterialClient.Recycle — Urban 同构宿主

- [x] 4.1 撤销/停用 AttendedWeighing 主窗 + Material 登录启动链
- [x] 4.2 新增 Recycle 激活窗（只填激活码，自动机器码）与启动门禁
- [x] 4.3 新增 Recycle 称重主窗（WeighingWindowBase 壳，对齐 UrbanAttendedWeighing；无退出登录/Material 同步）；采集经 Attended 管线落 WeighingRecord(Recycle)；上传事件已接，我方 receive 实现见 5.3
- [x] 4.4 模块注册与配置：在线激活客户端、平台 BaseUrl；诊断 MinimalWebHost 保持

## 5. 验证

- [ ] 5.1 冷启动：仅激活码 → 主界面；机器码已绑定
- [ ] 5.2 Admin 同时可见 5001 与 5020 授权行
- [ ] 5.3 称重诊断注入后可上传至 Recycle Web（承接既有 receive）
- [ ] 5.4 `openspec validate refactor-recycle-urban-host-auth --strict`
