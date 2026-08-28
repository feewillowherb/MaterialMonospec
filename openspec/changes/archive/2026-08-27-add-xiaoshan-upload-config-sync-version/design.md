## Context

`add-xiaoshan-upload-config-dual-edit`（INT-001）已提供按 `ProjectId` 的权威配置、Get/Write API、管理端弹窗与客户端对齐缓存。当前 Write 为后写覆盖，无 version，无审计行。本 change 在同一集成分支 `epic/xiaoshan-platform-upload` 上叠加 D2/D3/D5。

**约束**：命名 `record`/DTO；ViewModel → Service；写入 `[UnitOfWork]`；不引入 payload hash。

## Goals / Non-Goals

**Goals:**

- 权威配置与本地缓存携带 `configVersion`（long，从 1 起或 0 表示空配置）
- 服务端 Write 成功则 version++；客户端回写须带 `expectedConfigVersion`
- 版本不匹配 → 拒绝写入并返回权威快照，客户端覆盖本地对齐缓存
- 每次权威变更追加变更日志（actor、source Client|Server、timestamp、summary、configVersion）
- UI 展示 version；管理端可查最近日志（最小列表即可）

**Non-Goals:**

- 三模式 / 字段映射（INT-003）
- 旧客户端兼容矩阵（INT-004）— 可容忍「新字段缺省」但不在本 change 定矩阵
- 用变更日志做运行时回放/自动 rewind

## Decisions

### D1：`configVersion` 为 long，仅服务端递增

**决策**：服务端权威行持有 `ConfigVersion`；空配置 Get 返回 `0`；首次成功 Write → `1`，之后每次 +1。客户端缓存镜像该值。不做 hash。

**备选**：用时间戳当 version → 时钟偏移；拒绝。

### D2：乐观并发 — Write 带 `expectedConfigVersion`

**决策**：`XiaoshanUploadConfigWriteDto` 增加 `ExpectedConfigVersion`。服务端若 `expected != current`（空配置时 expected 必须为 0）则返回冲突（业务错误 + 当前 DTO），不落库。客户端收到冲突后刷新对齐缓存，不得标为已生效。

**备选**：服务端静默覆盖高 version — 违反 D3。

### D3：变更日志独立表

**决策**：`XiaoshanUploadConfigChangeLog`（或等价）按 `ProjectId` 存追加行：`ConfigVersion`、`Source`（Client/Server/Unknown）、`Actor`（用户名或 client machine 标识字符串）、`Summary`（短文本或 JSON diff 摘要）、`CreationTime`。Write 成功后同 UoW 插入一行。

**备选**：只打应用日志 → 不满足可查询审计。

### D4：客户端对齐语义升级

**决策**：`IsAlignedWithServer` 为真当且仅当本地 `ConfigVersion` 等于最近一次成功 Get/Write 返回的 version。保存前若已知落后，先 Refresh。

### D5：API 形状

**决策**：扩展既有 Get/Write；新增 `GetChangeLogsAsync(projectId, maxCount)`（或分页 DTO）。不新开第二套配置资源路径。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| INT-001 已部署库无列 | EF 迁移加列默认 0；首次 Write 升为 1 |
| 客户端未升级仍 Write 无 expected | INT-004 处理；本 change 可暂要求字段必填或默认 expected=0 仅允许空→首写 |
| 日志表膨胀 | 先按项目保留最近 N 条查询；全量保留不做清理（后续 ops） |
| 与未完成联调的 INT-001 叠加 | 在同一 epic 分支顺序 apply；联调清单含 version 场景 |

## Migration Plan

1. UM：加 `ConfigVersion` 列 + ChangeLog 表/迁移
2. 扩展 AppService Write/Get + ChangeLog 查询；管理端展示 version 与日志
3. MC：缓存列 + DTO + Service 冲突处理 + UI
4. 回滚：忽略新列/表；旧 Write 行为不再保证（应整包回滚 epic）

## Open Questions

- OQ-1：冲突 HTTP 形态用 ABP `UserFriendlyException` + 额外 Get，还是专用 `WriteResult` record（Success / Conflict + Config）？（默认专用 result record，避免异常控制流）
- OQ-2：Actor 在无登录管理端时用固定 `"server-ui"`，客户端用 `MachineCode`？（默认如此）
