## Why

政府平台 `PostWeightAsync` 联调（见 `docs/gov-sync-postweight-analysis.md`）表明：在 payload 格式正确时平台返回 `code: 200`，但 UrbanManagement 当前实现存在 **成功判定字段不匹配**（读取不存在的 `success` 而非 `code`），导致平台已成功时仍把记录标为同步失败并反复重试。同时，出站 payload 曾将 `snapImages` 序列化为空字符串、`carType` 使用英文 `Large`/`Small`，触发政府平台 `JSON parse error`。这些问题使政府同步在生产环境实质上不可用，需尽快修复并对齐已验证的政府 API 契约。

## What Changes

- 将政府同步成功判定改为基于政府 API 响应 `code == 200`（或约定的业务成功码），不再依赖 `GovResponseBase.Success` 默认值
- 确保 `BuildGovPayload` 出站字段与政府平台契约一致：
  - `snapImages` 为 Base64 字符串数组（无图时 `[]`）
  - `carType` 为中文 `"大车"` / `"小车"`（按 `TotalWeight > 4500` kg）
  - 附件 Base64 从 `ReadAttachmentFilesAsync` 写入 payload
- 引入 Core 层强类型出站 DTO（或复用契约 record），替换匿名 `object` payload，降低字段类型漂移风险
- 为 `IGovSyncHttpClient` Refit 客户端配置与联调一致的 `System.Text.Json` 序列化选项
- 对齐 `urban-weighing-api` spec 中政府 `carType` 描述，消除与 `gov-sync-worker` 的英文/中文漂移
- 补充单元测试：政府响应仅含 `code`/`msg`/`data` 时的成功/失败判定，以及 payload 字段类型

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `gov-sync-worker`: 明确政府 API 响应成功判定基于 `code`；强化 payload 中 `snapImages` 数组类型与 `carType` 中文枚举的 MUST 要求
- `urban-weighing-api`: 将政府同步 `carType` 阈值场景从 `Large`/`Small` 改为与政府平台一致的 `"大车"`/`"小车"`

## Impact

- **子仓库**：`repos/UrbanManagement`
  - `UrbanManagement.Core/Services/GovSyncManager.cs`
  - `UrbanManagement.Core/Api/IGovSyncHttpClient.cs`
  - `UrbanManagement.App/UrbanManagementAppModule.cs`（Refit JSON 配置）
  - 新增 Core 层出站 DTO / 测试项目用例
- **规范**：`openspec/specs/gov-sync-worker/spec.md`、`openspec/specs/urban-weighing-api/spec.md`（经 delta 合并）
- **参考文档**：`docs/gov-sync-postweight-analysis.md`（联调证据，不修改）
- **无破坏性 API 变更**：仅修正出站政府同步行为；旧版 `POST /Api/Post` 契约不变
