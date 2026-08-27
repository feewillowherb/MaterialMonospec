## Why

萧山监管上报需要可在现场与平台两侧调整的上传配置，但当前配置分散在客户端本地设置与服务端 `GovProject`/部署项中，互不同步。本 change 建立**统一上传配置模型**与**双端编辑**能力，并以**服务端为权威**（D1），作为后续 version 同步、三模式映射与旧端兼容的底座。

## What Changes

- 新增跨端「萧山上报配置」领域模型（按项目/场地绑定；本 slice 不实现三模式字段全集，但模型须可扩展至 Weighbridge/Gate/Product）。
- UrbanManagement：服务端可查询与编辑权威配置；持久化配置实体；提供客户端拉取与回写 API。
- MaterialClient.Urban：客户端可查看/编辑本地副本；编辑后须回写服务端，且**仅在与服务端权威对齐后**视为生效（D1）。
- 明确本 slice **不做**：`configVersion` 冲突裁决与变更审计日志（INT-002）、三模式多选与字段映射 UI/规则（INT-003）、旧客户端协议降级矩阵（INT-004）。

## Capabilities

### New Capabilities

- `xiaoshan-upload-config`: 萧山上报配置的权威存储、双端编辑、客户端拉取/回写与服务端生效规则（服务端权威）。

### Modified Capabilities

- （无）本 slice 不修改既有称重上传流水或 GovSync worker 的需求语义；后续 slice 再接入配置驱动上报。

## Impact

- **Repos**: MaterialClient（`MaterialClient.Urban` 设置/配置 UI 与本地存储）、UrbanManagement（项目侧配置管理、AppService/API、持久化）。
- **集成分支**: `epic/xiaoshan-platform-upload`（阶段完工合入该分支，不合 `main`）。
- **追溯**: INT-001；Epic `_bmad-output/planning-artifacts/xiaoshan-platform-upload-epic/`。
- **依赖后续**: INT-002/003/004 依赖本能力落地。
