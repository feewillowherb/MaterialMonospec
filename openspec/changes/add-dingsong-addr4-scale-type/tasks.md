## 1. Enum and settings surface

- [ ] 1.1 在 `ScaleType` 新增 `[Description("顶松Addr4")] DingSongAddr4 = 4`，确认既有枚举值不变
- [ ] 1.2 检查设置页秤类型数据源：依赖 `Enum`/`GetDescription` 则无需改；若有硬编码列表则加入 `DingSongAddr4`

## 2. TruckScaleWeightService — DingSongAddr4 解析

- [ ] 2.1 HEX 路由：`ScaleType.DingSongAddr4` → 新接收方法（如 `ReceiveHexDingSongAddr4`），与 `DingSong` / Default / PortableXPSY 并列
- [ ] 2.2 实现帧扫描：定长 17，`02 2A … 0D`；载荷前 6 位 ASCII → kg 整数；非法帧丢弃
- [ ] 2.3 解析成功后走现有 `ConvertWeight` 与 `_weightSubject` 推送

## 3. Tests

- [ ] 3.1 H610 单帧：`DingSongAddr4` 解析得 610（kg）
- [ ] 3.2 H1320 单帧：`DingSongAddr4` 解析得 1330（kg）
- [ ] 3.3 确认 `DingSongScaleRejectTests` 仍通过（顶松拒绝同帧）
- [ ] 3.4 （可选）双帧粘包缓冲仍能解析出重量

## 4. Validate

- [ ] 4.1 `openspec validate add-dingsong-addr4-scale-type --strict`
