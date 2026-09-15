# Tasks: refactor-truck-scale-transmission-format

**Mode B:** Apply 自 `dev-truck-scale-weight` 切出同名分支；验证后 squash 回 `dev-truck-scale-weight`（MaterialClient + MaterialMonospec）。**本 Phase 不实现耀华 tf1。**

## 1. Branch and scaffolding

- [x] 1.1 确认 MaterialClient / MaterialMonospec 在 `dev-truck-scale-weight`；自该基线创建并切换分支 `refactor-truck-scale-transmission-format`
- [x] 1.2 在 `MaterialClient.Common/Services/TruckScale/` 建立目录：`Facade/`、`Routing/`、`Protocols/{Yaohua,DingSong,DingSongAddr4,PortableXpsy,TestMode,Unsupported}/`

## 2. Enum and configuration

- [x] 2.1 新增枚举 `TransmissionFormatType`（`TransmissionFormatType0` / `TransmissionFormatType1` + Description `(tF0)` / `(tF1)`）
- [x] 2.2 `ScaleSettings`：删除 `CommunicationMethod`；新增 `TransmissionFormatType` 默认 Type0；更新 `IsValid()`
- [x] 2.3 全仓替换对 `CommunicationMethod` / `ScaleCommunicationMethod` 的读写与相等判断

## 3. Protocol contracts and router

- [x] 3.1 新增 `IScaleTransmissionProtocol`、`ScaleProtocolContext`（`record`，禁止 tuple）
- [x] 3.2 新增 `ITruckScaleProtocolRouter` + `TruckScaleProtocolRouter`：Type0 → 各设备协议；**任意 ScaleType × Type1 → Unsupported**（含 Yaohua）
- [x] 3.3 实现 `UnsupportedTransmissionFormatProtocol`：`EnsureSupported` / 启动路径抛不支持或未实现（元数据含 ScaleType + TransmissionFormatType）；禁止假重量

## 4. Migrate Type0 protocols and facade

- [x] 4.1 从巨石迁出并实现 `YaohuaTf0Protocol`、`DingSongTf0Protocol`、`DingSongAddr4Tf0Protocol`、`PortableXpsyTf0Protocol`、`TestModeTf0Protocol`
- [x] 4.2 将 `ITruckScaleWeightService` / `TruckScaleWeightService` 迁入 `TruckScale/Facade/`；门面经 Router 选协议；修 DI / using
- [x] 4.3 确认 `Services/Hardware/` 不再残留地磅协议平坦实现文件（Serial 等共用件可留）
- [x] 4.4 （可选）功能开关回退旧巨石路径 — **本 Phase 跳过**（默认新目录；靠 git 回退）

## 5. Settings UI

- [x] 5.1 Settings：通讯方式改为 `TransmissionFormatType` 选择项；删除 TextBox `ScaleCommunicationMethod`
- [x] 5.2 本 Phase **所有** ScaleType（含 Yaohua）不启用 `(tF1)`；默认选中 `(tF0)`

## 6. Tests and verify

- [x] 6.1 单测：Router Type0 矩阵；任意 Type1 → Unsupported 抛错；旧 JSON 无新字段 → Type0
- [x] 6.2 回归现有称重/地磅相关测试；构建 MaterialClient 通过
- [x] 6.3 勾选本 tasks；准备 squash 合入 `dev-truck-scale-weight`（勿直接 squash 进 trunk）
