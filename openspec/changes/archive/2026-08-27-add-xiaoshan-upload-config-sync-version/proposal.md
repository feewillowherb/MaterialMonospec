## Why

INT-001 已落地双端编辑与服务端权威，但仍缺少运行时一致性键与审计：并发回写可能互相覆盖且无法追溯。本 change 引入单调递增的 `configVersion` 裁决（D2/D3）与配置变更日志（D5），在不替代服务端权威的前提下保证可同步、可排障。

## What Changes

- 在权威配置与客户端对齐缓存上增加 `configVersion`（单调递增；不做强制 payload hash）。
- 写路径：服务端每次成功写入递增 version；客户端携带期望 version（或落后则拒绝/强制拉齐）。
- 冲突策略：高 version 胜；客户端落后时必须拉取服务端覆盖本地对齐缓存后再允许回写（D3）。
- 每次配置变更写入审计日志（谁/哪端/何时/改了什么摘要/关联 version）；日志不替代 version 裁决。
- 管理端与客户端 UI 展示当前 version 与对齐状态；可选查看最近变更日志。
- **不做**：三模式多选与字段映射（INT-003）、旧客户端协议降级矩阵（INT-004）。

## Capabilities

### New Capabilities

- `xiaoshan-upload-config-change-log`: 配置变更审计日志的持久化、查询与写入时机（与每次权威 Write 关联）。

### Modified Capabilities

- `xiaoshan-upload-config`: 增加 `configVersion` 字段与 Get/Write 同步/冲突行为；客户端对齐语义绑定 version。

## Impact

- **Repos**: UrbanManagement（实体列、Write 递增、变更日志表/AppService）、MaterialClient.Urban（缓存 version、回写携带 version、UI 展示）。
- **依赖**: 基于已 apply 的 `add-xiaoshan-upload-config-dual-edit`（INT-001）。
- **集成分支**: `epic/xiaoshan-platform-upload`。
- **追溯**: INT-002。
