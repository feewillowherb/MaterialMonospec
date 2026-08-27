# Intake themes（项目绑定）

> **业务敏感**：本文件属于 MaterialMonospec 项目绑定，**不是** `traits/intake-parking-trait.md` 的一部分。  
> 迁移 trait 到其他仓库时：**不要复制本表**；在目标仓新建空表后填本地 theme。  
> 机制规则见 trait；登记 INT 时 **优先选用** 下表。

| theme | 说明 | 关联 park | 预期 Epic（消化时参考） | 主要 repos |
|-------|------|-----------|-------------------------|------------|
| `xiaoshan-upload` | 萧山渣土监管上报（地磅/卡口/成品） | `park/xiaoshan-serve` | `xiaoshan-platform-upload-epic` | UrbanManagement |
| `urban-weighing` | Urban 称重桌面与上报链路 | — | `materialclient-urban-epic` | MaterialClient, UrbanManagement |
| `gov-sync` | 政务同步相关碎片 | — | `gov-sync-*-epic` | UrbanManagement |
| `baseplatform-labor` | BasePlatform 劳务域 | — | 按域开 epic | FdSoft.BasePlatform |
| `observability` | 日志/指标/可观测性 | — | 分散或 `refactor-*-observability` | 视条目 |
| `security` | 安全债 | — | 通常单条或小 epic | 视条目 |

## 规则

1. 格式：kebab-case，字母开头，≤ 48 字符。  
2. 同一挂起项目共用 theme；细分用 INT `slug`。  
3. 新增 theme：先改本表，再在 `README.md` 索引开节。  
4. theme ≠ OpenSpec change 名。  
5. GitHub label：`theme:<theme>`。
