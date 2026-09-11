# 03 — 落地影响与 effort

## 影响面

| 仓 | 影响 |
|----|------|
| `UrbanManagement` | 新增 OSS 配置与 STS/预签名签发；`AttachmentFile` 增 `OssObjectKey`（或等价）；`FileService` 读路径支持 OSS；政务同步/审批读图；可选废弃或并存 multipart |
| `MaterialClient.Urban` | `UrbanAttachmentSyncService` 改为 ticket → PutObject → complete；移除对长期 `AliyunOss` secret 的依赖 |
| `MaterialClient.Common` | 可选：`OssUploadService` 支持 SecurityToken / 凭据提供者，供 Urban 与后续 Material 共用 |
| `FdSoft.BasePlatform` | 非必须；仅运维对照或远期统一签发 |
| OpenSpec | 新 change（建议 `add-urban-oss-direct-upload`）；delta：`urban-client-attachment-sync`、`attachment-file-storage` |

## 兼容与迁移

- **存量** UM `Uploads/` 文件：读路径需 `LocalPath` 与 `OssObjectKey` 双轨一段时间。  
- **旧客户端**：仍走 multipart 时，UM 可继续落盘；新客户端走 OSS。用协议版本或 feature flag 区分（先例：`clientProtocolVersion`）。  
- **Material 主程序**：可本阶段不动，但应计划去掉客户端长期 Key（安全债）。

## 风险

| 风险 | 缓解 |
|------|------|
| STS 限流 | ticket 短时缓存，批量图共用一枚凭证 |
| 客户端滥用前缀 | session policy 锁死 `urban/{AccessCode}/...`；complete 时 HeadObject 校验 |
| 政务同步失败（只登记 key 未上传成功） | complete 前强制服务端校验对象存在；Receive 仍要求有效 Attachment Guid |
| CORS | 桌面 SDK 直连通常无浏览器 CORS；若未来 Web 上传再配 Bucket CORS |
| Bucket 公私有 | 私有桶 + 服务端 Get / 预签名 GET；勿依赖客户端拼的「永久公网 URL」当鉴权 |

## 落地规模（effort-token-estimate）

| 项 | 值 |
|----|-----|
| **档位** | **L** |
| **token 量级** | 约 40万–100万 |
| **驱动因素** | 跨 `MaterialClient.Urban` + `UrbanManagement`；鉴权/STS；实体与读图主路径；政务同步联调 |
| **建议拆会话** | ① UM ticket + 实体 ② 客户端直传替换 sync ③ 读图/政务 ④（可选）Material STS 收敛 |

S/M 不够：单改客户端继续写 secret 会违反目标约束。

开 OpenSpec 后：effort **只**写入该 change 的 `.openspec.yaml`，勿写入 `proposal.md`。

## 建议下一步

1. 确认持钥与 AssumeRole 落在 **UM** 还是独立签发服务 / BasePlatform。  
2. 确认 Bucket 是否与 Material `findong-materialsys` 共用，或 Urban 独立 Bucket/前缀。  
3. `/opsx:propose`（名称示例 `add-urban-oss-direct-upload`），本夹作 project_knowledge 链接。  
4. 明确是否同期清 Material 客户端长期 Key（可拆 change）。
