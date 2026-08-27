## Why

INT-001–003 已在服务端引入 `configVersion` 裁决、结构化三模式 envelope 与字段映射校验。现场仍有未及时升级的 Urban 客户端（缺 `expectedConfigVersion`、仍提交占位 `{}` modes、或仅理解 INT-001 级 Write 语义）。若服务端按新协议严格拒绝或整包覆盖，旧端将无法读写的配置或误抹掉新字段。本 change 落实 draft D6：定义兼容矩阵与服务端降级 Write，保证旧端仍可 Get、有限 Merge Write，不因新协议直接不可用。

## What Changes

- 定义客户端协议档位（v1 legacy / v2 versioned / v3 structured）与检测方式（Write DTO 可选 `clientProtocolVersion`）。
- 服务端 Legacy Write 路径：v1 客户端在权威行已存在时，**仅合并** DisplayName/Remark 等安全字段；对 `ModesJson`/`SettingsJson` 若客户端提交空/legacy `{}` 或未达 v3，**保留**服务端已有结构化 envelope，禁止 blind 覆盖。
- v1 Legacy Write **不要求** `expectedConfigVersion` 匹配（或视为 merge 语义）；仍递增 `configVersion` 并写变更日志（标注 legacy merge）。
- v2+ 保持 INT-002 乐观并发；v3 保持 INT-003 envelope 校验。
- Get 保持全量 DTO；旧端忽略未知 JSON 字段即可。
- 新客户端显式发送 `clientProtocolVersion`（MaterialClient 当前版本 = 3）。
- **不做**：GovSync HTTP 全量、旧安装包自动升级、非 Urban 模块兼容。

## Capabilities

### New Capabilities

- `xiaoshan-upload-legacy-compat`: 协议档位、Legacy Write 合并规则、变更日志标注、兼容矩阵与最低客户端档位文档化。

### Modified Capabilities

- `xiaoshan-upload-config`: Write 分流 legacy vs versioned/structured；Get 对旧端保持向后可读。

## Impact

- **Repos**: UrbanManagement（Write 合并策略、DTO、日志 summary）、MaterialClient.Urban（发送 `clientProtocolVersion`）。
- **依赖**: INT-001/002/003 已 apply 的 config API 与 envelope。
- **集成分支**: `epic/xiaoshan-platform-upload`。
- **追溯**: INT-004。
