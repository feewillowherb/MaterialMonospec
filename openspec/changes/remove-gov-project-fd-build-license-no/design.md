## Context

- 调研 P1：[04-改进建议与优先级.md §P1](../../docs/2026-09-02-urbanmanagement-entity-semantic-analysis/04-改进建议与优先级.md)（D3 移除 `FdBuildLicenseNo`）。
- 前置：`UrbanWeighingRecord.FdBuildLicenseNo` 已删除；P0 Legacy WIP 501 已落地；initiative 基线 `dev-urban-entity-semantic`。
- 现状：`GovProject` 仍含 `FdBuildLicenseNo` 列与索引；Pull/JWT/Blazor/ValidateAccessCode 均引用；MaterialClient `LicenseInfoDto` 仍保留属性。
- 约束：禁止 tuple；`BuildLicenseNo` 改名挂起（INT-005）；BasePlatform API 形状不变。

## Goals / Non-Goals

**Goals:**

- `GovProject` 与所有 UrbanManagement 消费方仅使用 `BuildLicenseNo` 作为对接码。
- EF migration 删除列与 `IX_GovProjects_FdBuildLicenseNo` 索引。
- JWT 新签与反篡改路径不再产生/依赖 `fdBuildLicenseNo`。
- MaterialClient 本地授权缓存与 JWT 解析对齐。

**Non-Goals:**

- `BuildLicenseNo` → `AccessCode` 重命名（INT-005）。
- 修改 BasePlatform `ProjectCatalog` 响应。
- 恢复 Legacy 落库或双码校验业务逻辑。
- 将历史 `FdBuildLicenseNo` 值 ETL 合并进 `BuildLicenseNo`（需运维人工核对冲突项目）。

## Decisions

### 1. 删列策略

- **选择**：EF migration `DropColumn` + `DropIndex`；不尝试自动合并两码。
- **理由**：D3 明确移除；凡东码与萧山码语义不同，自动合并有风险。
- **备选**：rename 列 — 拒绝，INT-005 挂起且非本 change 范围。

### 2. Pull 同步边界

- **选择**：`IBasePlatformProjectHttpClient` DTO **保留** `FdBuildLicenseNo` 反序列化字段；`GovProjectPullManager` **不再**映射到实体。
- **理由**：BasePlatform API 不变；忽略未知字段符合边界适配。

### 3. JWT claim 兼容

- **选择**：新签 JWT **不含** `fdBuildLicenseNo`；`JwtLicenseChecker` 对缺失 claim **不失败**（`FdBuildLicenseNo` 留 null/不写入 LicenseInfo）。
- **理由**：客户端不消费该字段；旧 token 在过期前仍可用。

### 4. Legacy 入站

- **选择**：`LegacyApiController` / DTO 可保留 JSON 键解析占位；**不**查询 `GovProject.FdBuildLicenseNo`；WIP 501 行为不变。
- **理由**：与 P0 Legacy WIP + D13 一致。

### 5. AccessCode 校验

- **选择**：`ValidateAccessCodeAsync` 简化为仅 `BuildLicenseNo` 查询；删除 `fdBuildLicenseNo` 参数或忽略该参数。
- **理由**：实体列删除后无双码路径。

### 6. MaterialClient 范围

- **选择**：删除 `LicenseInfo` / `LicenseInfoDto` / `LicenseCheckResult` 的 `FdBuildLicenseNo`；JWT 解析跳过该 claim。
- **理由**：与 UM 签发对齐；grep 显示无其他业务读取路径。

## Risks / Trade-offs

- **[Risk] 凡东码-only 项目无法再通过 Legacy 双码路径识别** → Legacy 已 WIP；Modern 路径仅用 `BuildLicenseNo`；运维迁移凡东码到萧山码（若存在）。
- **[Risk] 旧 JWT 含 fdBuildLicenseNo 但客户端仍显示** → MaterialClient 删除字段后 UI 不再展示；无功能依赖。
- **[Risk] Pull 丢弃 fdBuildLicenseNo 后信息丢失** → 接受；D3 决策；BasePlatform 仍保留源数据。

## Migration Plan

1. 部署前：导出 `GovProject` 中 `FdBuildLicenseNo` 非空且与 `BuildLicenseNo` 不同的行供运维核对。
2. 应用 EF migration（UrbanManagement）。
3. MaterialClient 与 UM 同 initiative 分支联调：新 JWT 签发 → 客户端启动 → SignalR 反篡改。
4. 回滚：恢复 migration 前备份（SQLite）；JWT 旧 claim 可临时兼容只读。

## Open Questions

- 无阻塞项。凡东码数据迁移由运维在 deploy 前人工处理。
