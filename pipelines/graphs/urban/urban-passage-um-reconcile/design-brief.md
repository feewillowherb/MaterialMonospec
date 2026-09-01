# design-brief — urban-passage-um-reconcile

OpenSpec：`add-urbanmanagement-passage-xiaoshan-upload`

## 为什么需要 reconcile Graph

| 现有 Graph | 覆盖范围 | 缺口 |
|------------|----------|------|
| `urban-passage-probe` | 客户端本地 10 条 LPR → SQLite | 不触 UM |
| `govsync/xiaoshan-gate|product` | UM/Gov 报文 → 萧山 | 不经过客户端 → UM ingest |
| **本 Graph** | seed 用例 ↔ UM Receive/List | 联调「客户端语义 → 服务端落库」 |

## 三种联调模式

1. **Bridge**（当前默认）：PS 按 `passage-cases.json` + `lpr-devices.json` 组装 Receive DTO，直 POST UM。用于 UM 已就绪、MC tasks 7.x 未完成的阶段。
2. **ClientProbe + Bridge**：先 `urban-passage-probe` 证明客户端链路，再 Bridge 证明 UM 可接收同语义 payload。
3. **ClientUpload**（未来）：MC 实现 passage 上云后，本 Graph 改为对照客户端 sync 状态与 UM 列表，删除 Bridge POST。

## 对照键

- **主键**：`plateNumber` + `PassageSource`（卡口 5 / 成品 5）
- **不进 reconcile**：Gov payload、`buildLicenseNo` 后缀（属 govsync Graph）

## 风险

- Bridge 与真实客户端 DTO 漂移 → tasks 7.x 完成后增加 contract test 或共享 seed 单源
- UM 鉴权 → `secrets.local.yaml` 的 `authorization`
- 重复 cook 重复落库 → 联调库可清空 `UrbanPassageRecords` 或使用新 `proId`
