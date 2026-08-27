# 2026-08-27-urban-xiaoshan-upload-config

| 字段 | 值 |
|------|-----|
| status | scratch |
| created | 2026-08-27 |
| theme_guess | xiaoshan-upload（兼 urban-weighing） |
| park_guess | park/xiaoshan-serve |
| source | Agent 会话 /intake-draft |

## 碎片

1. **客户端上传配置 + 服务端可改 + 双向同步 / 一致性**
   - `MaterialClient.Urban` 需要「上传配置」能力。
   - `UrbanManagement` 要能改客户端配置。
   - 客户端配置也要能同步到服务端。
   - **待拆清**：如何判定两端配置一致（版本号？哈希？最后写入胜？冲突策略？权威端是谁？）。

2. **萧山三模式同步配置（可多选）**
   - Urban 支持设计稿三种同步/上报模式：Weighbridge / Gate / Product（见 `docs/2026-08-27-xiaoshan-weighbridge-gate-product-upload-design`）。
   - **可多选**；**默认选中 Weighbridge**。
   - 三种模式各自可配：`deviceID`、`siteType`、`inOutType`。
   - 其他字段：来自称重流水，或来自静态字段。
   - 非必填且无数据源：可丢弃并**标注**（日志/清单？待定）。
   - 上述配置：**服务端可改、客户端也可改**（与碎片 1 的同步/一致性强相关）。

## 续聊笔记

- 证据：`docs/2026-08-27-xiaoshan-weighbridge-gate-product-upload-design/01-设计稿.md`（三通道 Weighbridge/Gate/Product）。
- repos 预期：`MaterialClient`（Urban）、`UrbanManagement`。
- promote 时可能拆成：① 配置模型与双端编辑；② 同步/一致性协议；③ 三模式多选与字段映射（含丢弃标注）。
- 未决：一致性算法、冲突时以谁为准、标注落在哪一层（仅上报日志 vs UI 提示）。

## 晋升记录

| 字段 | 值 |
|------|-----|
| promoted_to | |
| promoted_on | |
| disposition | archive \| delete |
| archived_to | |
