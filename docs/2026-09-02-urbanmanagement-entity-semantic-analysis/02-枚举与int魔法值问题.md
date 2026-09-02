# 02 · 枚举与 int 魔法值问题

## 1. 已有枚举清单

路径：`repos/UrbanManagement/src/UrbanManagement.Core/Entities/Enums/`

| 枚举 | 值域 | 持久化 Entity 使用 |
|------|------|-------------------|
| `SyncStatus` | `Pending=0, Success=1, Failed=2` | `UrbanWeighingRecord.SyncType` / `ClientSyncType`（**nullable enum**） |
| `PassageSource` | `Checkpoint=0, FinishedProduct=1` | `UrbanPassageRecord.PassageSource` ✅ |
| `UrbanInOutType` | `Enter=0, Exit=1` | `UrbanPassageRecord.UrbanInOutType` ✅ |
| `UrbanSiteType` | `Construction=0, Disposal=1` | `UrbanPassageRecord.UrbanSiteType` ✅ |
| `AttachType` : `short` | 0–6（含 Lpr、UrbanPhoto） | `AttachmentFile.AttachType` ✅ |
| `ProductCode` | 5000/5001/5010 | **未持久化**（仅同步边界校验） |

## 2. 核心问题：`SyncStatus` 分裂为三种写法

同一语义「政府同步状态」在代码库中存在 **三种表达**：

| 写法 | 使用位置 | 示例 |
|------|----------|------|
| `SyncStatus?` enum | `UrbanWeighingRecord`, DTO, `GovSyncManager` | `record.SyncType = SyncStatus.Pending` |
| `int?` 裸类型 | `UrbanPassageRecord`, `GovSyncData`, DTO | `record.SyncType = 0` |
| 字面量比较 | Sync Manager、AppService | `r.SyncType != 1`, `is not (1 or 2)` |

### 2.1 Entity 层对比

**已 enum 化（但仍 nullable）：**

```csharp
// UrbanWeighingRecord.cs
public SyncStatus? SyncType { get; set; }
public SyncStatus? ClientSyncType { get; set; }
```

**仍为 int?：**

```csharp
// UrbanPassageRecord.cs
public int? SyncType { get; set; }

// GovSyncData.cs
public int? SyncType { get; set; }
public int? SyncNumber { get; set; }
```

### 2.2 Entity 方法中的魔法值

`UrbanPassageRecord` 工厂/更新方法直接写 `0`：

```csharp
// UrbanPassageRecord.cs — ApplyDuplicateReceive / ResetGovSync / FromReceive
SyncType = 0;
RetryCount = 0;
```

对称地，`UrbanWeighingRecordAppService` 使用 `SyncStatus.Pending`——**同一概念，不同实体不同表达**。

### 2.3 Service 层硬编码（高风险维护点）

**GovProductSyncManager / GovCheckpointSyncManager**（通行记录同步）：

```csharp
.Where(r => ... && r.SyncType != 1 ...)
// ...
record.SyncType = 1;  // Success
record.SyncType = 2;  // Failed
```

**UrbanCheckpointPassageAppService / UrbanFinishedProductPassageAppService**：

```csharp
// TEMP: 下个版本恢复为 record.SyncType != 2
if (record.SyncType is not (1 or 2))
```

**LegacyGovSyncAppService**（遗留路径）：

```csharp
SyncType = SyncStatus.Pending,   // → UrbanWeighingRecord（enum）
// ...
SyncType = 0, SyncNumber = 0      // → GovSyncData（int）
```

**GovSyncManager**（称重同步，规范写法）：

```csharp
.Where(r => r.SyncType != SyncStatus.Success ...)
record.SyncType = SyncStatus.Success;
```

### 2.4 影响

1. **可读性**：`SyncType != 1` 需查表才知是「未成功」
2. **重构安全**：改 enum 成员顺序/值域时，`int` 路径无编译保护
3. **nullable 叠加**：`int?` 使 `RetryCount < maxRetryCount` 等比较需 `?? 0` 兜底
4. **TEMP 注释**：AppService 已标注临时逻辑，说明团队知晓不一致但未收敛

## 3. 应用层 DTO 继承问题

| DTO | SyncType 类型 |
|-----|---------------|
| `UrbanWeighingRecordDto` / `*OutputDto` | `SyncStatus?` |
| `UrbanPassageRecordOutputDto`（`UrbanPassageDtos.cs`） | `int?` |

API 消费者看到 **同一产品概念两种 JSON 形状**（数字 vs 命名 enum 序列化行为取决于配置）。

## 4. EF Core 存储

`UrbanManagementDbContext` 对 `SyncStatus?` **未**显式 `HasConversion`；SQLite 存为 `INTEGER`，nullable。

`AttachType` 是唯一显式配置枚举转换的字段：

```csharp
b.Property(e => e.AttachType).IsRequired().HasConversion<short>();
```

`UrbanPassageRecord` 的 `PassageSource` / `UrbanInOutType` / `UrbanSiteType` 依赖 EF 默认 int 枚举映射（non-nullable ✅）。

## 5. 应 enum 化但仍为 string 的字段

| 字段 | 当前类型 | 已知值域 / 来源 | 参照 |
|------|----------|-----------------|------|
| `SiteType` | `string?` | 萧山接口 `1`/`2` 或中文 | `UrbanSiteType` 已在通行侧使用 |
| `VehicleType` | `string?` | 「大车」/「小车」 | MaterialClient / 接口默认 |
| `PlateColor` | `string?` | 车牌颜色文案 | 接口 `carNoColor` |
| `DeviceType` | `string` | Scale/Camera/LPR/Sound | 注释列举，无 enum |
| `Status` | `string` | Online/Offline | 注释列举，无 enum |

这些字段 nullable/string 组合使 **UI 筛选、同步映射、校验** 只能字符串比较，无法 exhaustiveness check。

## 6. 小结

| 类别 | 状态 | 建议方向 |
|------|------|----------|
| 通行/成品同步状态 | ❌ `int?` + 魔法值 | 统一为 `SyncStatus`，默认 `Pending` |
| 称重同步状态 | ⚠️ `SyncStatus?` | 改为 non-nullable，创建时必填 |
| 遗留 GovSyncData | ❌ 全弱类型 | 隔离/只读；新写入走 UrbanWeighingRecord |
| 进出/场地/来源 | ✅ 已 enum | 作为全项目标准 |
| 附件类型 | ✅ `AttachType` | 作为 EF enum 转换范例 |
| 车辆/站点/设备 | ❌ string | 逐步引入 enum 或 Value Object |
