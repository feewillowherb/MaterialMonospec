# Tasks: WeighingRecord 抓拍信息字段扩展

## Phase 1: 基础设施层变更

### 1.1 创建枚举类型和工具类

- [x] **创建 VzvisionVehicleColorType 枚举**
  - 文件: `src/MaterialClient.Common/Services/Vzvision/VzvisionVehicleColorType.cs`
  - 定义车身颜色枚举 (Unknown, White, Silver, Gray, Black, Red, Blue, Yellow, Green, Brown, Purple, Other)
  - 添加 `DescriptionAttribute` 到每个枚举值

- [x] **创建 VzvisionVehicleType 枚举**
  - 文件: `src/MaterialClient.Common/Services/Vzvision/VzvisionVehicleType.cs`
  - 定义车型枚举 (Unknown, Small, Medium, Large, ExtraLarge, Truck, Bus, Sedan, SUV, MPV, Other)
  - 添加 `DescriptionAttribute` 到每个枚举值

- [x] **创建 HikvisionVehicleType 枚举**
  - 文件: `src/MaterialClient.Common/Services/Hikvision/HikvisionVehicleType.cs`
  - 根据海康 SDK 文档定义车型枚举
  - 添加 `DescriptionAttribute` 到每个枚举值

- [x] **创建 HikvisionVehicleColorType 枚举**
  - 文件: `src/MaterialClient.Common/Services/Hikvision/HikvisionVehicleColorType.cs`
  - 根据海康 SDK 文档定义车身颜色枚举
  - 添加 `DescriptionAttribute` 到每个枚举值

- [x] **创建 HikvisionPlateColorType 枚举**
  - 文件: `src/MaterialClient.Common/Services/Hikvision/HikvisionPlateColorType.cs`
  - 根据海康 SDK 文档定义车牌颜色枚举
  - 添加 `DescriptionAttribute` 到每个枚举值

- [x] **创建 EnumDescriptionHelper 工具类** (已废弃 - 使用现有的 EnumExtensions)
  - 文件: `src/MaterialClient.Common/Utils/EnumDescriptionHelper.cs`
  - 实现 `GetDescription<T>(T value) where T : Enum` 方法
  - 使用反射读取 `DescriptionAttribute`

## Phase 2: 实体层和事件层变更

### 2.1 扩展 WeighingRecord 实体

- [x] **在 WeighingRecord.cs 中新增三个字段**
  - 文件: `src/MaterialClient.Common/Entities/WeighingRecord.cs`
  - 添加: `public string? VehicleColor { get; set; }`
  - 添加: `public string? VehicleType { get; set; }`
  - 添加: `public string? PlateColor { get; set; }`

### 2.2 扩展事件数据结构

- [x] **扩展 LicensePlateRecognizedEventData**
  - 文件: `src/MaterialClient.Common/Events/LicensePlateRecognizedEventData.cs`
  - 添加: `public string? VehicleColor { get; set; }`
  - 添加: `public string? VehicleType { get; set; }`
  - 添加: `public string? PlateColor { get; set; }`

- [x] **扩展 LicensePlateRecognizedMessage**
  - 文件: `src/MaterialClient.Common/Events/LicensePlateRecognizedMessage.cs`
  - 添加: `public string? VehicleColor { get; set; }`
  - 添加: `public string? VehicleType { get; set; }`
  - 添加: `public string? PlateColor { get; set; }`

- [x] **更新 EventBusToMessageBusBridge**
  - 文件: `src/MaterialClient/Events/EventBusToMessageBusBridge.cs`
  - 在 `LicensePlateRecognizedEventToMessageBusBridge.HandleEventAsync` 中桥接三个新字段

## Phase 3: LPR 服务适配

### 3.1 VzvisionLprService 适配

- [x] **在 VzvisionLprService.cs 中新增映射方法**
  - 文件: `src/MaterialClient.Common/Services/Vzvision/VzvisionLprService.cs`
  - 实现 `static string? MapVehicleColor(byte nCarColor)`
  - 实现 `static string? MapVehicleType(int nType)`
  - 使用 `EnumDescriptionHelper.GetDescription` 读取 Description

- [x] **更新 OnPlateInfo 回调**
  - 文件: `src/MaterialClient.Common/Services/Vzvision/VzvisionLprService.cs`
  - 从 `TH_PlateResult` 提取 `nCarColor` 和 `nType`
  - 调用映射方法获取字符串值
  - 在发布 `LicensePlateRecognizedEventData` 时设置三个新字段
  - 车牌颜色继续使用现有的 `MapColor` 方法

### 3.2 HikvisionLprService 适配

- [x] **在 HikvisionLprService.cs 中新增映射方法**
  - 文件: `src/MaterialClient.Common/Services/Hikvision/HikvisionLprService.cs`
  - 实现 `static string? MapVehicleColor(int byColor)`
  - 实现 `static string? MapVehicleType(int byVehicleType)`
  - 实现 `static string? MapPlateColor(NET_DVR_PLATE_INFO_EX plateInfoEx)` (提取 `byColor`)
  - 使用 `EnumDescriptionHelper.GetDescription` 读取 Description

- [x] **更新 HandlePlateResult 方法**
  - 文件: `src/MaterialClient.Common/Services/Hikvision/HikvisionLprService.cs`
  - 从 `NET_DVR_PLATE_RESULT` 提取 `byColor` 和 `byVehicleType`
  - 从 `NET_DVR_PLATE_INFO_EX` 提取 `byColor` (车牌颜色)
  - 在发布 `LicensePlateRecognizedEventData` 时设置三个新字段

- [x] **更新 HandleItsPlateResult 方法**
  - 文件: `src/MaterialClient.Common/Services/Hikvision/HikvisionLprService.cs`
  - 从 `NET_ITS_PLATE_INFO` 提取 `byColor` 和 `byVehicleType`
  - 从 `NET_DVR_PLATE_INFO_EX` 提取 `byColor` (车牌颜色)
  - 在发布 `LicensePlateRecognizedEventData` 时设置三个新字段

## Phase 4: 状态管理适配

### 4.1 WeighingStateManager 扩展

- [x] **在 WeighingStateManager.cs 中新增私有字段**
  - 文件: `src/MaterialClient.Common/Services/AttendedWeighing/WeighingStateManager.cs`
  - 添加: `private string? _currentCycleVehicleColor;`
  - 添加: `private string? _currentCycleVehicleType;`
  - 添加: `private string? _currentCyclePlateColor;`

- [x] **新增 SetCurrentCycleVehicleInfo 方法**
  - 文件: `src/MaterialClient.Common/Services/AttendedWeighing/WeighingStateManager.cs`
  - 方法签名: `public void SetCurrentCycleVehicleInfo(string? vehicleColor, string? vehicleType, string? plateColor)`
  - 更新三个私有字段
  - 添加日志记录

- [x] **新增 GetCurrentCycleVehicleInfo 方法**
  - 文件: `src/MaterialClient.Common/Services/AttendedWeighing/WeighingStateManager.cs`
  - 方法签名: `public (string? vehicleColor, string? vehicleType, string? plateColor) GetCurrentCycleVehicleInfo()`
  - 返回三个字段的值元组

- [x] **更新 ResetCycle 方法**
  - 文件: `src/MaterialClient.Common/Services/AttendedWeighing/WeighingStateManager.cs`
  - 在清除记录 ID 和 LRP 路径时，同时清除三个车辆信息字段

### 4.2 AttendedWeighingService 适配

- [x] **更新 ILocalEventBus 订阅逻辑**
  - 文件: `src/MaterialClient.Common/Services/AttendedWeighing/AttendedWeighingService.cs`
  - 在 `SubscribeToLicensePlateRecognizedEvent` 中
  - 调用 `_stateManager.SetCurrentCycleVehicleInfo` 传递三个新字段

## Phase 5: 业务逻辑适配

### 5.1 WeighingRecordService 适配

- [x] **更新 CreateWeighingRecordAsync 方法**
  - 文件: `src/MaterialClient.Common/Services/AttendedWeighing/WeighingRecordService.cs`
  - 在创建 `WeighingRecord` 后，获取车辆信息
  - 调用 `_stateManager.GetCurrentCycleVehicleInfo()`
  - 设置 `weighingRecord.VehicleColor`, `VehicleType`, `PlateColor`
  - 在日志中记录车辆信息

## Phase 6: 单元测试

### 6.1 VzvisionLprService 测试

- [ ] **测试 MapVehicleColor 方法**
  - 文件: `tests/MaterialClient.Common.Tests/Tests/VzvisionLprServiceTests.cs`
  - 测试所有枚举值的映射
  - 测试未知值返回 null
  - 测试边界值

- [ ] **测试 MapVehicleType 方法**
  - 文件: `tests/MaterialClient.Common.Tests/Tests/VzvisionLprServiceTests.cs`
  - 测试所有枚举值的映射
  - 测试未知值返回 null
  - 测试边界值

### 6.2 HikvisionLprService 测试

- [ ] **测试 MapVehicleColor 方法**
  - 文件: `tests/MaterialClient.Common.Tests/Tests/HikvisionLprServiceTests.cs`
  - 测试所有枚举值的映射
  - 测试未知值返回 null
  - 测试边界值

- [ ] **测试 MapVehicleType 方法**
  - 文件: `tests/MaterialClient.Common.Tests/Tests/HikvisionLprServiceTests.cs`
  - 测试所有枚举值的映射
  - 测试未知值返回 null
  - 测试边界值

### 6.3 WeighingStateManager 测试

- [ ] **测试车辆信息存储和读取**
  - 文件: `tests/MaterialClient.Common.Tests/Tests/WeighingStateManagerTests.cs`
  - 测试 `SetCurrentCycleVehicleInfo` 存储值
  - 测试 `GetCurrentCycleVehicleInfo` 读取正确值
  - 测试 `ResetCycle` 清除值

### 6.4 WeighingRecordService 测试

- [ ] **测试记录创建时车辆信息写入**
  - 文件: `tests/MaterialClient.Common.Tests/Tests/WeighingRecordServiceTests.cs`
  - 模拟 `WeighingStateManager` 返回车辆信息
  - 验证 `WeighingRecord` 的三个字段被正确设置
  - 测试车辆信息为 null 的场景

## Phase 7: 集成测试和验证

### 7.1 端到端测试

- [ ] **测试 Vzvision 设备抓拍全流程**
  - 启动 Vzvision LPR 服务
  - 模拟设备抓拍回调
  - 验证事件发布包含车辆信息
  - 创建称重记录
  - 验证数据库记录包含正确的车辆信息

- [ ] **测试 Hikvision 设备抓拍全流程**
  - 启动 Hikvision LPR 服务
  - 模拟设备抓拍回调
  - 验证事件发布包含车辆信息
  - 创建称重记录
  - 验证数据库记录包含正确的车辆信息

- [ ] **测试设备不返回车辆信息的场景**
  - 模拟回调不包含车辆信息
  - 验证系统正常工作
  - 验证数据库记录车辆信息字段为 null

### 7.2 数据库验证

> **注意**: EF Core 迁移的创建和应用由用户负责。用户需要在完成代码变更后，自行创建迁移文件并应用到数据库。

- [ ] **验证表结构（用户执行迁移后）**
  - 检查 `WeighingRecords` 表包含三个新列
  - 验证列类型为 `nvarchar(50)`
  - 验证列可为 null

- [ ] **验证数据完整性**
  - 查询包含车辆信息的记录
  - 验证字符串长度不超过 50
  - 验证枚举映射正确

## Phase 8: 代码审查和文档更新

### 8.1 代码审查准备

- [ ] **验证代码符合项目规范**
  - 检查所有新代码遵循 AGENTS.md 规范
  - 验证命名约定 (英文字符，无中文)
  - 验证 Record 替代 Tuple (如适用)
  - 验证接口与实现文件组织约定

- [ ] **验证单一职责原则**
  - 检查每个类/方法职责明确
  - 验证职责边界清晰

### 8.2 文档更新

- [ ] **更新相关文档**
  - 如有相关文档需要更新，同步更新

## Phase 9: 发布准备

### 9.1 最终验证

- [ ] **运行所有单元测试**
  - 确保所有测试通过
  - 测试覆盖率不降低

- [ ] **运行集成测试**
  - 端到端流程测试通过
  - 数据库操作验证通过

- [ ] **性能验证**
  - 验证 LPR 回调处理时间增加 < 5ms
  - 验证事件发布延迟增加 < 1ms

### 9.2 合并准备

- [ ] **准备 PR 描述**
  - 总结变更内容
  - 列出影响的文件和模块
  - 提供测试验证结果
  - **说明**: EF Core 数据库迁移由用户负责，不在本变更范围内

- [ ] **提供数据库迁移指导（供用户参考）**
  - 建议迁移命令: `dotnet ef migrations add AddVehicleCaptureInfoToWeighingRecord --project src/MaterialClient.Common`
  - 说明需要添加的列: VehicleColor, VehicleType, PlateColor (nvarchar(50), nullable)
  - 提醒用户在适当环境应用迁移
