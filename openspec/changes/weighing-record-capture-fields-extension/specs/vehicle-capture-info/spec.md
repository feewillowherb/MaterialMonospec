# Spec: 车辆抓拍信息持久化能力

## 能力概述

车辆抓拍信息持久化能力确保车牌识别设备返回的车辆详细信息（车身颜色、车型、车牌号颜色）能够被正确捕获、映射并持久化到称重记录中。

## 功能需求

### REQ-1: 车辆信息捕获

**优先级**: P0 (必须有)

系统必须能够从 LPR 设备抓拍结果中提取以下车辆信息：

| 字段名 | 数据类型 | 可空性 | 说明 |
|--------|---------|--------|------|
| VehicleColor | string? | 是 | 车身颜色 |
| VehicleType | string? | 是 | 车型分类 |
| PlateColor | string? | 是 | 车牌号颜色 |

**验收标准**:
- [ ] Vzvision 设备抓拍时提取 `nCarColor` 和 `nType`
- [ ] Hikvision 设备抓拍时提取 `byColor` 和 `byVehicleType`
- [ ] 所有字段均为可空，设备不支持时返回 null

### REQ-2: 枚举到字符串映射

**优先级**: P0 (必须有)

系统必须将设备返回的枚举值映射为人类可读的字符串。

**验收标准**:
- [ ] Vzvision 车辆颜色映射使用 `VzvisionVehicleColorType.Description`
- [ ] Vzvision 车型映射使用 `VzvisionVehicleType.Description`
- [ ] Hikvision 车辆颜色映射使用 `HikvisionVehicleColorType.Description`
- [ ] Hikvision 车型映射使用 `HikvisionVehicleType.Description`
- [ ] 车牌颜色映射使用各自 SDK 的颜色枚举 (VzvisionColorType / HikvisionPlateColorType)
- [ ] 未知枚举值返回 `null`

### REQ-3: 事件数据传输

**优先级**: P0 (必须有)

提取的车辆信息必须通过事件系统完整传输。

**验收标准**:
- [ ] `LicensePlateRecognizedEventData` 包含三个新字段
- [ ] `LicensePlateRecognizedMessage` 包含三个新字段
- [ ] `EventBusToMessageBusBridge` 正确桥接所有新字段
- [ ] 事件发布时机与现有车牌号事件一致

### REQ-4: 状态管理

**优先级**: P0 (必须有)

当前称重周期内的车辆信息必须临时存储，供记录创建时使用。

**验收标准**:
- [ ] `WeighingStateManager` 提供三个新字段的存储方法
- [ ] `SetCurrentCycleVehicleInfo` 更新缓存
- [ ] `GetCurrentCycleVehicleInfo` 读取缓存
- [ ] `ResetCycle` 清除车辆信息缓存
- [ ] 状态管理器线程安全

### REQ-5: 持久化

**优先级**: P0 (必须有)

车辆信息必须随称重记录一起持久化到数据库。

**验收标准**:
- [ ] `WeighingRecord` 实体包含三个新字段
- [ ] `WeighingRecordService.CreateWeighingRecordAsync` 设置车辆信息
- [ ] 数据库表包含三个新列 (nvarchar(50), nullable)
- [ ] EF Core 迁移正确添加新列

### REQ-6: 兼容性

**优先级**: P0 (必须有)

新增功能不得破坏现有功能。

**验收标准**:
- [ ] 现有称重记录正常读取 (新字段为 null)
- [ ] 不返回车辆信息的设备不影响称重流程
- [ ] 现有单元测试通过
- [ ] 无数据库迁移回滚问题

## 非功能需求

### NFR-1: 性能

车辆信息提取和映射不应显著增加 LPR 回调处理时间。

**指标**:
- 单次回调处理时间增加 < 5ms
- 事件发布延迟增加 < 1ms

### NFR-2: 可维护性

枚举定义应使用 `DescriptionAttribute`，便于未来扩展和本地化。

**要求**:
- 所有新枚举必须有 Description
- 未知值有明确的枚举项
- 枚举值与设备文档一致

### NFR-3: 数据完整性

存储的字符串值必须有长度限制。

**约束**:
- 数据库列长度: nvarchar(50)
- 代码中 maxLength: 50
- 过长字符串应截断或拒绝

## 技术约束

### TC-1: 枚举值范围

Vzvision 和 Hikvision 的枚举值范围可能不同，需独立定义。

### TC-2: Description 读取

使用反射读取 `DescriptionAttribute`，需考虑性能影响。

### TC-3: 状态生命周期

车辆信息缓存生命周期与称重周期一致，需确保及时清除。

## 测试需求

### 单元测试

- [ ] VzvisionLprService: `MapVehicleColor` 各枚举值
- [ ] VzvisionLprService: `MapVehicleType` 各枚举值
- [ ] HikvisionLprService: `MapVehicleColor` 各枚举值
- [ ] HikvisionLprService: `MapVehicleType` 各枚举值
- [ ] WeighingStateManager: 车辆信息存储/读取/清除
- [ ] WeighingRecordService: 记录创建时车辆信息写入

### 集成测试

- [ ] Vzvision 设备抓拍 → 数据库持久化全流程
- [ ] Hikvision 设备抓拍 → 数据库持久化全流程
- [ ] 不返回车辆信息的场景
- [ ] 部分字段缺失的场景

### 数据验证测试

- [ ] 数据库列长度约束
- [ ] 枚举值范围边界
- [ ] null 值处理
