## Why

需要在不改生产称重的前提下，用肉眼确认耀华 `tF=0` 连续帧只能提供一个当前显示重量，毛重、皮重、净重由上位机记下当前值再计算。该验证只服务 Demo 对照，不进入有人/无人值守业务。

## What Changes

- 在 `MaterialClient.Demo` 增加一个独立窗口，界面固定打出四项：**实时**、**毛重**、**皮重**、**净重**
- 窗口提供串口下拉（仅选端口）。其余线路参数固定为生产默认：9600、8 数据位、无校验、1 停止位，不可改
- 连上后按 `tF=0` 连续帧刷新实时。仍可用十六进制回放（`02` … `03`，12 字节）在不接仪表时对照。不改仪表 `tF`
- 实时取当前有效帧的显示重量（符号 + 6 位数据 + 小数位）
- 未记毛/皮时按方案一未去皮：皮重 = 0，毛重 = 实时，净重 = 毛重
- 提供「记毛重」「记皮重」冻结当前实时；两者都记下后净重 = 毛重 − 皮重（二次过磅）
- 不把第 10–11 字节当 `NET` 状态位；校验失败或残帧不更新实时
- **非 BREAKING**：不改 `TruckScaleWeightService`、生产界面、过磅记录

## Capabilities

### New Capabilities

- `demo-yaohua-tf0-weight-display`: Demo 窗口按 `tF=0` 连续帧回放显示实时重量，并用上位机记账显示毛重、皮重、净重，供肉眼验收

### Modified Capabilities

- （无）

## Impact

- **MaterialClient**（仅 `src/MaterialClient.Demo`）：新窗口与入口按钮；不新增 NuGet、不接生产 DI / Repository
- 不改 UrbanManagement、FdSoft.BasePlatform、生产称重服务或数据库
- 验收方式：运行 Demo，对照抓包帧与界面四个数字，由用户肉眼确认
