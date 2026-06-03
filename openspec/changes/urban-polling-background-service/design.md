## Context

- **主程序**：`MaterialClient/Backgrounds/PollingBackgroundService.cs` 基于 `AsyncPeriodicBackgroundWorkerBase`，周期约 10 分钟，处理物料/运单/OSS 等；由 `MaterialClientModule` 在 `BackgroundServices:Polling` 下注册。
- **Urban**：`MaterialClientUrbanModule` 按 `urban-abp-module` **不得**注册主程序 Worker；当前也 **未**注册 Urban 自有 Worker。`IUrbanWeighingExtensionService.GetPendingForUploadAsync` 已实现；`UrbanServerUploadService.SubmitRecordAsync` 已实现（含 LicenseInfo 填充）。
- **缺口**：无 Worker 调用 Pending 扫描；`ApproveRecordAsync` 可能在审批后立即 HTTP 上传。
- **约束**：Urban MUST NOT 依赖 `MaterialClientModule`；SQLite + ABP UOW；`urban-weighing-api` 要求 Worker 跳过 `IsAnomaly` 记录。

## Goals / Non-Goals

**Goals:**

- Urban 在配置启用时自动启动周期性 Worker，在独立 UOW 内上传 Pending 称重记录。
- 审批后仅复位 `SyncStatus` 为 `Pending`，由 Worker 异步重传。
- 与主程序轮询 **技术形态一致**（ABP Periodic Worker + `WithUow`），**代码与 DI 注册隔离**（Urban 命名空间下的类）。

**Non-Goals:**

- 不将主程序 `PollingBackgroundService` 的物料/运单/附件同步逻辑迁入 Urban。
- 不实现 Urban 的 `SessionRefreshRequiredEto` 订阅（主程序 token 刷新场景不适用 Urban 无平台 API）。
- 不修改 `UrbanManagement` 服务端或 `GovSyncBackgroundWorker`（服务端政府同步管线）。
- 不在本 change 内新增手动「立即同步」UI 按钮（可另开 change）。

## Decisions

### D1: 类名与位置 — `MaterialClient.Urban.Backgrounds.PollingBackgroundService`

**选择**：Urban 工程内新建同名类，命名空间 `MaterialClient.Urban.Backgrounds`，与主程序类 **全名不同**（程序集隔离）。

**理由**：与 epic、`project-context` 表述一致（「与 PollingBackgroundService 相同机制」）；避免跨程序集引用主程序 Backgrounds。

**备选**：`UrbanWeighingUploadBackgroundWorker` — 语义更窄，但与文档/口头约定「PollingBackgroundService 模式」不一致；若团队更偏好可重命名，本 change 采用 **PollingBackgroundService** 以对齐主程序心智模型。

### D2: 模块依赖 — `AbpBackgroundWorkersModule`

**选择**：`MaterialClientUrbanModule` 增加 `[DependsOn(typeof(AbpBackgroundWorkersModule))]`；在 `OnApplicationInitializationAsync`（或 `ConfigureServices` 中 `AddBackgroundWorkerAsync`）注册 Worker。

**理由**：ABP 官方 Worker 生命周期与主程序一致。

### D3: 注册条件 — `BackgroundServices:Polling`

**选择**：仅当 `IConfiguration` 读取 `BackgroundServices:Polling == true` 时 `AddBackgroundWorkerAsync<PollingBackgroundService>()`。

**理由**：与主程序开关一致；本地/测试可关闭轮询。

### D4: 周期与批量 — 配置驱动

**选择**：

| 键 | 默认 | 说明 |
|----|------|------|
| `BackgroundServices:Polling` | `true`（Urban appsettings） | 总开关 |
| `Urban:UploadPollingPeriodMs` | `600000`（10 分钟） | `Timer.Period`，与主程序默认同量级 |
| `Urban:UploadBatchSize` | `50` | 单次 `DoWorkAsync` 最多处理条数 |

**理由**：Urban 上传频率可与主程序物料同步解耦；避免一次加载过多 Pending 阻塞 UI 线程（Worker 在后台线程）。

**备选**：硬编码 10 分钟 — 不利于联调缩短周期。

### D5: `DoWorkAsync` 流程

**选择**：

```
DoWorkAsync
  └─ WithUow(async =>
       pending = await GetPendingForUploadAsync(take: batchSize)
       foreach item in pending
         if item.IsAnomaly → continue
         try await SubmitRecordAsync(item.WeighingRecordId)
         catch → log, continue
     )
```

**理由**：对齐 `urban-weighing-extension` 后台查询场景与 `urban-weighing-api` 异常跳过；单条失败不影响其余记录。

**状态更新**：由 `UrbanServerUploadService.SubmitRecordAsync` 内部（或现有上传服务）更新 `SyncStatus` / `RetryCount`；Worker 不重复实现 HTTP 细节。

### D6: 审批路径 — 移除 UI 即时上传

**选择**：`ApproveRecordAsync` 在 `UpdateWeighingRecordAsync` 成功后 **不** 调用 `IUrbanServerUploadService`。

**理由**：`weighing-record-approval` 已要求复位 Pending 供「background sync worker」重传；即时上传造成双路径与 UI 阻塞。

### D7: `urban-abp-module` 规范措辞

**选择**：MODIFIED 主程序 Worker 禁止条款为「不得注册 `MaterialClient.Backgrounds.PollingBackgroundService`」；ADDED 允许 Urban 自有 Worker 在开关启用时注册。

**理由**：消除与历史 spec 的字面冲突，保留模块边界。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 审批后最多等待一个轮询周期才上云 | 文档说明；联调可下调 `Urban:UploadPollingPeriodMs` |
| 与主程序类名相同导致混淆 | 命名空间/程序集区分；代码审查禁止 Urban 引用 MaterialClient.Backgrounds |
| Pending 堆积时单次 batch 不足 | 可增大 `UploadBatchSize`；后续可加「连续 drain」逻辑 |
| 网络长期失败 | 依赖现有 `RetryCount` / `LastErrorTime`；Worker 日志 + 列表展示 Failed |

## Migration Plan

1. 实现 Worker + 模块注册 + appsettings 默认值。
2. 移除 `ApproveRecordAsync` 即时上传。
3. 本地验证：创建/审批记录 → Pending → Worker 周期或缩短周期 → Synced；异常记录不上传。
4. 回滚：关闭 `BackgroundServices:Polling` 或还原 ViewModel 与模块注册。

## Open Questions

- 是否在 Worker 内对 `SubmitRecordAsync` 包裹 Polly 重试（与 epic design 提及一致）— **本 change 默认沿用 `UrbanServerUploadService` 内已有重试/错误处理**；若无则仅记录日志，Polly 可 follow-up。
- 首次称重完成（非审批）的 Pending 是否也由同一 Worker 上传 — **是**，与 slice 03 一致，Worker 扫描所有 Pending，不仅审批复位记录。
