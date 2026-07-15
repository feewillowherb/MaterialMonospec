## 1. Enum and settings UI (MaterialClient)

- [ ] 1.1 在 `repos/MaterialClient/src/MaterialClient.Common/Entities/Enums/ScaleType.cs` 新增 `PortableXPSY`，`Description("便携式XP-SY")`
- [ ] 1.2 在 `SettingsWindowViewModel.ScaleTypeOptions` 加入 `ScaleType.PortableXPSY`
- [ ] 1.3 确认 `ScaleTypeConverter` 通过 `GetDescription()` 显示「便携式XP-SY」；若有硬编码映射则补一项

## 2. TruckScaleWeightService protocol (MaterialClient)

- [ ] 2.1 `InitializeAsync`：当 `ScaleType == PortableXPSY` 时强制 `_receType = ReceType.String`、`_endChar = "="`（或启用 9 字节缓冲路径），即使 `CommunicationMethod == "TF0"` 也不走 HEX
- [ ] 2.2 `SerialPort_DataReceived`：对 PortableXPSY 走独立接收分支（勿与 DingSong HEX / 默认 HEX 混用）
- [ ] 2.3 实现帧同步：扫描合法 9 字节帧（`[0..7]` 为 `0-9`/`.`/`-`，`[8]=='='`），对齐旧端 `FindPortableXPSYFrameStart`
- [ ] 2.4 实现解析：反转 8 字符载荷，`InvariantCulture` 解析重量，再经 `ConvertWeight` 推送 `WeightUpdates`；禁止对该路径调用现有 `IsValidWeightFormat`
- [ ] 2.5 确认 Yaohua / DingSong / TestMode 分支无回归（仅 ScaleType 选中时走新路径）

## 3. Tests (MaterialClient)

- [ ] 3.1 在 `TruckScaleWeightServiceTests` 增加 PortableXPSY 用例：`51.07000=` → 70.15（转换前）
- [ ] 3.2 增加 `51.0700-=` → -70.15、`.0151000=` → 1510
- [ ] 3.3 增加连续帧 `51.07000=51.07000=` 双帧解析
- [ ] 3.4 增加回归：PortableXPSY + `CommunicationMethod=TF0` 初始化仍走 ASCII 路径（不按 HEX 解析）

## 4. Verification

- [ ] 4.1 编译并通过相关单元测试
- [ ] 4.2 （可选）真机/串口模拟器冒烟：设置选「便携式XP-SY」后称重 UI 重量更新正常
