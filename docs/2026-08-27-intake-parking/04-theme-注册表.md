# 04 · Theme 注册表

已批准的业务 `theme` 列表。登记 INT 时**优先从下表选用**；新 theme 须在本表追加一行后再用。

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
2. 同一挂起项目共用 theme；细分用 INT `slug`，不要为每句需求新造 theme。  
3. 新增 theme：在本表登记 + README 索引新开一节。  
4. theme ≠ OpenSpec change 名。

## GitHub Label 对应

Issue label：`theme:<theme>`，例 `theme:xiaoshan-upload`。
