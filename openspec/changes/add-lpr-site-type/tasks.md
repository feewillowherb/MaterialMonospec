## 1. Baseline model and JSON

- [x] 1.1 在 Common 增加站点类型枚举（地磅 / 卡口 / 成品）及中文展示转换（与现有 `LprDeviceType` 同类，不注册 DI）
- [x] 1.2 `LicensePlateRecognitionConfig`（及设置 VM 映射）增加该字段；缺省与 JSON 缺字段为地磅
- [x] 1.3 确认 DeviceManager、识别、道闸、匹配代码未读取该字段

## 2. Settings UI

- [x] 2.1 `AddLprDialog` 增加/编辑展示站点类型；Urban 可改三种，非 Urban 锁定地磅
- [x] 2.2 设置页 LPR 表格展示站点类型列
- [x] 2.3 非 Urban 保存路径将所有 LPR 行规范为地磅
- [x] 2.4 沿用现有 Urban 宿主判定，不新造产品探测

## 3. Verify

- [x] 3.1 编译 MaterialClient（含 Urban 与非 Urban 宿主）
- [ ] 3.2 手工 Urban：增加一行卡口、编辑改成品，保存再打开仍在
- [ ] 3.3 手工非 Urban：无法改成卡口/成品；保存后 JSON 为地磅
