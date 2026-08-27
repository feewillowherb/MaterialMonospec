# 06 · GitHub Issue 衔接

指针协作：INT 为种子权威，Issue 为讨论/指派面。**不做**全文双向自动同步。

## 默认路径（仓库优先）

1. 登记 `docs/intake/<YYYY-MM>/INT-xxx.md`  
2. 可选创建 Issue：

```bash
gh issue create \
  --title "[INT-001] 萧山地磅称重结果上报" \
  --label "theme:xiaoshan-upload" \
  --label "park:xiaoshan-serve" \
  --label "kind:product" \
  --label "status:parked" \
  --body "Intake: docs/intake/2026-08/INT-001-xiaoshan-weighbridge-upload.md"
```

3. INT 表填 `github: #n`

## Label 约定

| Label | 用途 |
|-------|------|
| `theme:<theme>` | 与 INT `theme` 一致 |
| `park:<slug>` | 挂起项目桶 |
| `kind:product` / `tech-debt` / … | 与 INT `kind` 一致 |
| `status:parked` | 挂起月 Open Issue |
| `status:absorbed` | 已进 BMAD Epic |
| `status:proposed` | 已有 OpenSpec change |

## 状态对齐（关键节点）

| INT status | Issue |
|------------|-------|
| `open` / `triaged` | Open + `status:parked` |
| `absorbed` | Open + `status:absorbed`（comment 贴 Epic 路径） |
| `proposed` | Open + `status:proposed`（comment 贴 change 路径） |
| `closed` | Close；PR 用 `Fixes #n` |

## 跨仓

- 需求类 Issue 开在 **MaterialMonospec**  
- 子仓 PR 在 description 链回 Monospec Issue

## Issue 模板（可选后续）

可在 `.github/ISSUE_TEMPLATE/intake.yml` 增加字段：`theme`、`parked_until`、证据链接。
