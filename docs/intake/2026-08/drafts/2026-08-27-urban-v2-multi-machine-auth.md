# 2026-08-27-urban-v2-multi-machine-auth

| 字段 | 值 |
|------|-----|
| status | scratch |
| created | 2026-08-27 |
| theme_guess | urban-weighing |
| park_guess | |
| source | Agent 会话 /intake-draft |

## 碎片

- **Urban V2**：一个项目支持 **多个机器授权**（调研已定：最多 **4** 台同时在线称重）。
- 证据夹：`docs/2026-08-25-urban-v2-four-machine-code-binding/`（四槽绑定 / 新 ProductCode V2；不改写 5001）。
- 要点摘录（仍属草稿，非正式 INT）：
  - 新增 Urban V2 ProductCode（数值待定，候选 5002）
  - 项目级设备槽 1…4；发码选槽；同槽再激活覆盖；AccessCode / AuthEndTime 项目级共享
  - 本期无解绑 UI/API（D37 预留后期）
  - 5001 保持单机，不迁移到 V2

## 续聊笔记

- 调研已较完整（含 Decision Log / OpenSpec checklist）；promote 时可能直接收成 1 条 INT 或按 Client / UrbanManagement / 发码 API 拆条。
- 与 `2026-08-27-urban-xiaoshan-upload-config` 草稿不同主题：本条是**授权/多机**，彼条是**萧山上报配置同步**。

## 晋升记录

| 字段 | 值 |
|------|-----|
| promoted_to | |
| promoted_on | |
| disposition | archive \| delete |
| archived_to | |
