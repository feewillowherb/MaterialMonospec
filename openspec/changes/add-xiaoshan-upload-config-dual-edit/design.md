## Context

萧山监管上报配置目前分散：客户端用 `SettingsEntity` / `appsettings` / `LicenseInfo`；服务端用 `GovProject` 与部署级 `StorageOptions`。互不共享，无法在平台改现场上报参数。本 Epic 集成分支为 `epic/xiaoshan-platform-upload`；本 change 仅落地 INT-001（配置模型 + 双端编辑 + 服务端权威）。

**约束**

- ViewModel → Service → Repository；写入方法 `[UnitOfWork]`
- 禁止 tuple 作 API/字段类型；多值用命名 `record`
- 本 slice 不改 GovSync 实际上报载荷组装（留给 INT-003）
- `configVersion` 裁决与变更日志留给 INT-002（可预留字段，但不实现冲突协议）

## Goals / Non-Goals

**Goals:**

- UrbanManagement 持久化项目级「萧山上报配置」权威副本
- 管理端 UI/API 可编辑权威配置
- MaterialClient.Urban 可拉取、本地展示/编辑，并回写服务端
- 客户端编辑仅在服务端接受并对齐后视为生效（D1）

**Non-Goals:**

- `configVersion` 单调裁决、冲突覆盖策略实现、配置变更审计日志（INT-002）
- Weighbridge/Gate/Product 多选与字段映射规则/UI（INT-003）
- 旧客户端协议降级矩阵（INT-004）
- 地磅/卡口/成品政府接口实际上报改造

## Decisions

### D1：权威配置落在 UrbanManagement，按 ProId（项目）绑定

**决策**：新增服务端实体（建议名 `XiaoshanUploadConfig` 或等价），以 `ProId`（或与 `GovProject` 1:1）为键存储权威配置 JSON/结构化列。

**备选**：挂在 `GovProject` 扩展列 → 短期省表，但字段膨胀且难演进三模式；拒绝作为首选。  
**备选**：仅客户端本地配置 → 违反 D1 服务端权威。

### D2：双端编辑 API — Get + Put（客户端回写）

**决策**：提供至少：

- `GET` 按项目取权威配置（客户端启动/进入设置时拉取）
- `PUT`/`POST` 客户端或管理端提交整份或补丁配置；服务端校验后持久化为权威

管理端可复用同一 AppService，或 Blazor 页直接调 AppService。

**备选**：仅服务端可写、客户端只读 → 不满足「双端可改」。

### D3：生效语义 — 服务端接受后客户端再刷新本地

**决策**：客户端本地编辑先作为草稿；调用回写成功后，必须以服务端返回体覆盖本地缓存，该次编辑才算生效。回写失败则本地保持草稿态并提示，不得假装已与权威一致。

**备选**：本地立即生效再异步上传 → 与 D1 冲突，易造成双权威。

### D4：本 slice 配置载荷最小集 + 可扩展 envelope

**决策**：本 slice 定义 envelope：`proId`、可选占位 `modes`/`settings` 结构（可为空或默认），保证后续 INT-003 可填充三模式字段，而不强迫本 slice 实现映射 UI。具体列级可在 apply 时定稿，但须用命名 DTO/`record`，禁止 tuple。

**备选**：本 slice 直接做满三模式字段 → 范围膨胀，并入 INT-003。

### D5：客户端本地缓存位置

**决策**：本地缓存优先独立实体或 `SettingsEntity` 下明确命名的 Urban/萧山配置节；勿与硬件 `SystemSettings` 混写无版本语义字段。INT-002 再引入 `configVersion`。

### D6：分支与合入

**决策**：实现与 OpenSpec 工件落在 `epic/xiaoshan-platform-upload`；子仓同策略。阶段完成合入 Epic 分支，不合 `main`。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 无 version 时短暂双写竞态 | INT-001 文档约定「后写覆盖」临时行为；INT-002 引入 `configVersion` |
| 客户端离线无法回写 | 明确草稿态；联网后再 Put；UI 标明未与服务端对齐 |
| 与 `GovProject` 身份字段重复 | 配置实体引用 `ProId`，不复制 AccessCode 授权语义 |
| 范围滑向三模式/GovSync | proposal/tasks 明确 Non-Goals；发现需求记 INT 不塞本 change |

## Migration Plan

1. UrbanManagement：迁移加表/列 → AppService + API → 管理端最小编辑页（或挂 ProjectManagement）
2. MaterialClient：DTO + API 客户端 + Service + 设置入口
3. 联调：服务端改 → 客户端拉取覆盖；客户端改 → 回写 → 再拉验证
4. 回滚：功能开关或忽略新 API；旧路径不依赖本配置即可继续称重上传

## Open Questions

- OQ-1：配置主键是否严格 1:1 `GovProject`，还是允许同项目多场地多行？（默认 1:1 ProId，多场地留给后续）
- OQ-2：管理端编辑入口挂 `ProjectManagement` 还是独立页？（apply 时按现有 Blazor 习惯选定）
