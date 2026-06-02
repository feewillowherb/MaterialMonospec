## Context

`MaterialClient.Urban` 已具备 ABP + Avalonia 的运行形态，并已配置 UrbanManagement Refit 客户端，但缺少一个“最小可执行”的 WebHost 测试服务来验证服务端地址、路由可达性与响应可用性。当前问题通常在完整称重流程中才暴露，调试成本较高。  
本变更仅针对 Urban 客户端增加测试能力，且根据需求采用复制现有 `MinimalWebHostService.cs` 能力的方式实现，不引入共享抽象。

## Goals / Non-Goals

**Goals:**
- 在 `MaterialClient.Urban` 增加 `MinimalWebHostService.cs` 测试功能，支持独立触发并输出明确结果。
- 测试流程与 `UrbanManagement:BaseUrl` 配置协同，快速验证目标服务可达性与接口可用性。
- 明确实现策略为“直接复制功能”，避免为一次性测试能力引入复用复杂度。

**Non-Goals:**
- 不将该服务抽取到 `MaterialClient.Common` 或建立跨项目通用库。
- 不重构现有称重业务流程与上传服务主路径。
- 不在本次变更中扩展完整集成测试框架或端到端自动化体系。

## Decisions

### Decision 1: 在 Urban 项目内新增独立 `MinimalWebHostService`
- **Choice**: 在 `MaterialClient.Urban` 内新增服务类并按现有依赖注入方式注册/解析。
- **Rationale**: 用户明确要求“不复用，直接复制功能”；同时可最小化对既有架构影响。
- **Alternative considered**: 抽到 `MaterialClient.Common` 做共享服务。该方案在当前阶段收益低、迁移范围大，暂不采用。

### Decision 2: 测试目标固定读取 `UrbanManagement:BaseUrl`
- **Choice**: 测试服务统一通过配置读取 UrbanManagement 服务地址，不硬编码端点。
- **Rationale**: 保证与运行时上传链路使用同一地址来源，减少“测试通过但运行失败”的偏差。
- **Alternative considered**: 测试入口传入临时 URL。该方案灵活但容易与正式配置脱节，不作为默认路径。

### Decision 3: 输出结构化测试结果（成功/失败/错误消息）
- **Choice**: 服务返回可序列化的结果对象，至少包含状态、消息、可选错误详情。
- **Rationale**: 便于 UI 或日志系统直接消费，降低定位成本。
- **Alternative considered**: 仅记录日志。该方式对调用方不友好，无法形成稳定验收接口。

## Risks / Trade-offs

- **[复制实现带来后续漂移风险]** → 通过在 tasks 中要求保留来源注释与差异说明，后续若上游能力变化可人工对齐。
- **[测试接口与生产接口不一致风险]** → 复用同一 Refit 客户端与配置键，并在场景中约束请求路径与契约一致。
- **[误把测试能力当正式能力使用]** → 在命名与文档中明确该服务为测试辅助能力，且不改变主业务入口。

## Migration Plan

1. 在 `MaterialClient.Urban` 添加 `MinimalWebHostService.cs` 与必要 DTO/结果模型。
2. 接入依赖注入并在可见入口（调试命令/按钮/调用点）提供触发能力。
3. 验证在本地通过 `UrbanManagement:BaseUrl` 可完成最小请求并返回结构化结果。
4. 回归检查：不影响现有称重与上传主流程。
5. 如需回滚，仅删除新增服务与触发入口，不影响数据库与核心业务模型。

## Open Questions

- 测试触发入口最终挂载在 UI 显式按钮，还是仅保留给开发/诊断命令？
- 最小测试请求是否只验证 `GET` 健康接口，还是同时验证一条轻量业务接口调用？
