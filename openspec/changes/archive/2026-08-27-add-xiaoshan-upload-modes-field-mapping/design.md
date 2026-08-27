## Context

INT-001 在 `XiaoshanUploadConfig` 上预留 `ModesJson` / `SettingsJson` 列与双端 raw JSON 编辑；INT-002 叠加 `configVersion` 与变更日志。设计稿（Weighbridge / Gate / Product）与 draft D4 要求：三模式可多选（默认 Weighbridge）、各模式独立参数、字段来自称重流水或静态配置、非必填无源可跳过且须 UI/上报路径标注。

**约束**：命名 `record`/DTO；ViewModel → Service → Repository；Write `[UnitOfWork]`；禁止 tuple；仍用既有 Get/Write API 与 version 裁决；序列化继续落 `ModesJson`/`SettingsJson` 列以避免破坏性列迁移。

## Goals / Non-Goals

**Goals:**

- 定义并校验结构化 `ModesJson` / `SettingsJson` schema（版本化 envelope，如 `schemaVersion: 1`）
- 三模式多选 + 默认 `[Weighbridge]`；每模式 `deviceID`、`siteType`、`inOutType` 等可配
- 静态字段（`buildLicenseNo`、`areaCode`、`spaceName`、`dataSource` 等）与流水字段映射规则
- 字段解析 Service：给定模式 + 称重上下文 → 解析结果 + 跳过项列表（D4）
- `buildLicenseNo` 通道变换：Gate/Weighbridge 用原值 `L`，Product 用 `L + "-02"`（已带后缀不重复拼）
- 双端 UI 结构化编辑；raw JSON 高级折叠可选
- 上报路径调用映射层时记录 skip 日志（结构化，含 field/mode/reason）

**Non-Goals:**

- 三通道 HTTP Client 全量实现或 GovSync Worker 大改（可接映射层输出，不在本 slice 定 HTTP 细节）
- 地磅心跳
- INT-004 旧客户端降级（Write 仍要求 `expectedConfigVersion`；旧端矩阵另开）
- 变更 version/日志机制本身（INT-002）

## Decisions

### D1：继续用 `ModesJson` / `SettingsJson` 列，内容为 versioned JSON

**决策**：不新增 DB 列；引入 `XiaoshanUploadModesEnvelope` / `XiaoshanUploadSettingsEnvelope`（C# record + JSON 序列化）。空或 `{}` 读时 materialize 为默认 envelope（仅 Weighbridge enabled）。

**备选**：拆子表 per mode → 过度规范化；本阶段 JSON + 强类型 DTO 足够。

### D2：模式标识与默认

**决策**：枚举字符串 `Weighbridge` | `Gate` | `Product`。`enabledModes` 为集合；缺省或空 → `["Weighbridge"]`。至少保留一个启用模式（校验失败则 Write 拒绝）。

**备选**：单选模式 → 违反设计稿多选。

### D3：每模式 settings record

**决策**：`XiaoshanUploadModeSettings` record 含：

- `DeviceId`（卡口/成品 `01`/`02` 语义；地磅可映射到 `inOutType` 的展示配置）
- `SiteType`（`1`/`2`）
- `InOutType`（地磅 `0`/`1`）
- 可选 mode-specific 覆盖项

各模式独立一条；未启用模式可存草稿但不参与映射。

### D4：字段映射与跳过（D4）

**决策**：`IXiaoshanUploadFieldMappingService`（或等价）输入：`enabledMode`、静态 envelope、称重流水 DTO（plate、weight、images、时间等）。输出：`XiaoshanFieldMappingResult` record：

- `ResolvedFields`（字段名 → 值，仅已解析项）
- `SkippedFields`（`XiaoshanSkippedField` record：field、mode、reason、sourceAttempted）

规则：SyncDoc 非必填且无流水/静态来源 → 加入 `SkippedFields`，**不**抛阻断异常。必填缺失 → 返回 validation 结果供上报层决定拒发（本 change 定义「可跳过」子集，必填清单按设计稿摘录）。

配置 UI：对已知无源静态项显示「无数据源，跳过」；上报路径对 skip 写 Information 级日志。

### D5：`buildLicenseNo` 变换集中 helper

**决策**：静态类或 record 方法（设计稿 `XiaoshanBuildLicenseNo`）：

```csharp
public static string ForGate(string licenseNo) => licenseNo;
public static string ForProduct(string licenseNo) =>
    licenseNo.EndsWith("-02", StringComparison.Ordinal) ? licenseNo : licenseNo + "-02";
public static string ForWeighbridge(string licenseNo) => licenseNo;
```

映射层按目标 mode 选用；配置存原值 `L`。

### D6：Write 校验与 version

**决策**：AppService Write 在乐观并发之前/之后解析 JSON → 校验 envelope；非法 schema 拒绝 Write（UserFriendlyException 或 WriteResult 失败）。合法则序列化规范化 JSON 再持久化，`configVersion` 仍由 INT-002 逻辑递增。

客户端/管理端提交结构化 DTO，服务端 canonicalize JSON。

### D7：UI 范围

**决策**：替换 raw textarea 为主体编辑；保留「高级 / JSON」只读或折叠编辑供排障。ASCII 布局见下。

```
┌─ 萧山上报配置 ─────────────────────────────┐
│ Version: 3    [Weighbridge][Gate][Product] │  ← 多选 chip
├────────────────────────────────────────────┤
│ ▼ Weighbridge (enabled)                    │
│   inOutType [0/1]  dataSource [____]       │
│ ▼ Gate                                     │
│   deviceID [01/02]  siteType [1/2]         │
│ ▼ Product                                  │
│   (同 Gate 字段集)                          │
├────────────────────────────────────────────┤
│ 静态: buildLicenseNo  areaCode  spaceName   │
│ ⚠ goodsWeight — 无数据源，跳过              │
└────────────────────────────────────────────┘
```

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 既有 `{}` 占位 JSON | 读路径默认 materialize；首次 Write 规范化 |
| raw JSON 高级编辑破坏 schema | 校验失败拒绝；UI 优先结构化 |
| 映射层与 GovSync 未接线 | 本 slice 交付 Service + 单测；GovSync 接入留 tasks 明确边界 |
| `dataSource` 联调取值未定（Q1） | settings 可配置，默认 `WEIGHBRIDGE_XIAOSHAN`，文档标注 OQ |
| 范围滑向 INT-004 | proposal Non-Goals；不写旧端降级 |

## Migration Plan

1. UM：定义 envelope record + JSON 校验；扩展 AppService Write；管理端 UI
2. MC：DTO 映射 + 配置窗口 UI + 本地缓存序列化
3. MC：字段映射 Service + 上报路径日志钩子（UrbanServerUpload 或等价调用点）
4. 回滚：恢复 raw JSON UI；解析失败时读默认 envelope

## Open Questions

- OQ-1：上报路径首个接入点是 `UrbanServerUploadService` 还是 GovSync pipeline？（默认 MC UrbanServerUpload 打 skip 日志 stub）
- OQ-2：`dataSource` 默认值现场联调前是否固定为 `WEIGHBRIDGE_XIAOSHAN`？（默认可配置，默认该值）
- OQ-3：管理端是否需预览「解析结果 / skip 列表」？（默认客户端配置窗 + 日志即可，管理端可选只读预览）
