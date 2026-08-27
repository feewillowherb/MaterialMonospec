## Context

Epic `xiaoshan-platform-upload` 已落地：双端编辑（INT-001）、`configVersion` + 变更日志（INT-002）、结构化三模式 + 字段映射（INT-003）。INT-002 将 Write 返回改为 `XiaoshanUploadConfigWriteResult` 并要求 `expectedConfigVersion`；INT-003 对 modes/settings 做 schema 校验。未升级客户端可能：不传 version、提交 `{}` 占位 JSON、或仅更新显示名/备注。D6 要求服务端降级，避免旧端不可用或抹掉新配置。

**约束**：命名 `record`/DTO；禁止 tuple；不改变 Get 资源路径；legacy 行为可观测（日志 + change log summary）。

## Goals / Non-Goals

**Goals:**

- 文档化协议档位 v1/v2/v3 与最低兼容含义
- Write 按档位分流：v1 merge、v2+ 乐观并发、v3 完整 envelope 校验
- v1 merge 保护结构化 modes/settings 不被 `{}` 覆盖
- v1 在权威行已存在时仍可成功 merge 安全字段并递增 version
- 新 MaterialClient 发送 `clientProtocolVersion: 3`
- 单元测试覆盖：legacy `{}` 不抹 modes、v2 冲突仍拒绝、v1 merge 递增 version

**Non-Goals:**

- 恢复 pre-INT-002 Write 返回 `XiaoshanUploadConfigDto` 的旧 HTTP 形状（旧 Refit 客户端需升级才能解析 WriteResult；本 change 聚焦 merge 语义而非双响应形态）
- 自动推送客户端升级
- INT-003 字段映射 / GovSync 行为变更

## Decisions

### D1：协议档位

| 档位 | 值 | 客户端能力 | 服务端 Write |
|------|-----|-----------|--------------|
| v1 legacy | 1 | INT-001 级；可无 expected；modes 可为 `{}` | Merge 路径 |
| v2 versioned | 2 | 带 `expectedConfigVersion` | INT-002 乐观并发 |
| v3 structured | 3 | 结构化 envelope + version | INT-002 + INT-003 校验 |

**检测**：`XiaoshanUploadConfigWriteDto.ClientProtocolVersion`（int，缺省 **1**）。MaterialClient 升级后固定 **3**。

### D2：Legacy merge 字段白名单

**决策**：v1 Write 仅允许合并 `DisplayName`、`Remark`。`ModesJson`/`SettingsJson` 仅当客户端档位 ≥3 **且** 通过 envelope 校验时才替换；否则保留服务端现有 JSON（读-改-写前从 entity 取当前值）。

**备选**：v1 完全拒绝 Write → 违反 D6「不能不可用」。

### D3：Legacy 与 version 裁决

**决策**：v1 且 `ConfigVersion > 0` 时 **跳过** `expectedConfigVersion` 相等检查，改为 merge 后 `ConfigVersion++`。仍写 change log，`Summary` 含 `legacy-merge/v1`。

v2/v3 维持 INT-002 冲突规则。

### D4：空 envelope 判定

**决策**：下列视为 legacy 占位、不得覆盖服务端 structured 内容：

- `ModesJson` 为 null/空白/`{}`
- 或解析后 `enabledModes` 为空且 `schemaVersion` 缺省（materialize 前原始 JSON 为 `{}`）

Settings 同理：`{}` 或无可识别 `schemaVersion` 字段。

v3 客户端必须发送 canonical structured JSON。

### D5：Get 向后兼容

**决策**：Get 不变；返回完整 `configVersion`、modes、settings。旧客户端 DTO 反序列化忽略未知属性即可。

### D6：最低兼容版本（文档）

**决策**：服务端兼容 **v1+** 客户端 Write（merge）；推荐现场 ≥ **v3** 以使用三模式 UI。v1 客户端应升级以支持 WriteResult 与 conflict 处理（INT-002 已部署服务端时）。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Legacy merge 仍可能覆盖 DisplayName | 可接受；modes/settings 受保护 |
| 恶意 v1 伪造 merge | 仍须有效 ProjectId + 既有 change log 审计 |
| 旧 Refit 无法解析 WriteResult | 文档 + 强制升级 INT-002 客户端；不在本 slice 双响应 |
| v1 与 v2 混用同机器 | 升级后发送 v3；merge 仅未升级端 |

## Migration Plan

1. UM：DTO 加 `ClientProtocolVersion`；Write 分流 + merge helper；测试
2. MC：Write 发送 `clientProtocolVersion: 3`
3. 联调：模拟 v1 `{}` write 不抹 modes；v3 正常校验

## Open Questions

- OQ-1：是否需在 Get DTO 增加 `serverProtocolVersion` 供客户端自适配？（默认暂不加，靠客户端常量）
- OQ-2：管理端 Write 固定 v3 还是 v2？（默认 v3，走完整校验）
