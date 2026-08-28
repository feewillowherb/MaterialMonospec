## Why

INT-001/002 已提供按项目的权威配置、双端编辑与 `configVersion` 裁决，但 `ModesJson` / `SettingsJson` 仍为占位 JSON，无法表达设计稿中的 Weighbridge / Gate / Product 三通道多选、各模式参数与字段来源规则。现场无法按通道启用上报，也无法在配置与上报路径上标注「无数据源跳过」（D4）。本 change 在 Epic 集成分支上补齐三模式配置与字段映射语义，为后续实际上报改造提供可校验的配置面。

## What Changes

- 将 `ModesJson` 规范为结构化三模式配置：Weighbridge / Gate / Product **可多选**，默认仅启用 Weighbridge。
- 各启用模式可配置模式级参数（至少 `deviceID`、`siteType`、`inOutType` 及设计稿要求的静态项如 `buildLicenseNo`、`areaCode` 等）。
- 将 `SettingsJson` 规范为静态字段与字段来源映射 envelope；区分「来自称重流水」与「来自静态配置」。
- 实现字段解析/映射层：对非必填且无数据源的字段 **跳过**（不阻断主流程），并在上报路径写可观测日志、在配置 UI 标注「无数据源，跳过」。
- 成品通道 `buildLicenseNo` 后缀 `-02` 规则纳入映射层（不二次拼接）。
- 管理端与客户端配置 UI：由 raw JSON 编辑升级为结构化三模式多选与字段映射编辑；仍走既有 Get/Write + `configVersion` 路径。
- **不做**：旧客户端缺字段降级矩阵（INT-004）、GovSync 三通道 HTTP Client 全量落地、地磅心跳、INT-002 已有 version/变更日志行为变更。

## Capabilities

### New Capabilities

- `xiaoshan-upload-modes`: 三上报模式（Weighbridge/Gate/Product）多选、默认与每模式参数的配置模型、校验与双端 UI。
- `xiaoshan-upload-field-mapping`: 静态 vs 流水字段来源、非必填无源跳过（D4）、`buildLicenseNo` 通道变换与上报路径可观测标注。

### Modified Capabilities

- `xiaoshan-upload-config`: 配置 envelope 从占位 JSON 升级为结构化 modes/settings；Get/Write 校验与 UI 绑定结构化编辑（仍序列化至 `ModesJson`/`SettingsJson` 列）。

## Impact

- **Repos**: UrbanManagement（DTO 校验、映射解析 Service、管理端弹窗 UI）、MaterialClient.Urban（本地缓存对齐、配置窗口 UI、字段映射/跳过标注供上报路径调用）。
- **依赖**: `add-xiaoshan-upload-config-dual-edit`（INT-001）、`add-xiaoshan-upload-config-sync-version`（INT-002）。
- **集成分支**: `epic/xiaoshan-platform-upload`。
- **追溯**: INT-003；设计参考 `docs/2026-08-27-xiaoshan-weighbridge-gate-product-upload-design/01-设计稿.md`。
