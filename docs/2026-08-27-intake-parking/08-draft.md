# 08 · Intake Draft（草稿纸）

与 Agent **边聊边碎**、尚未够格写成正式 INT 时，先落 **draft**，**不占**全局 `INT-00N` 序号。

> **机制权威**：`traits/intake-parking-trait.md`。本文为设计夹补充说明。

## 定位

```text
Agent 碎聊 / 半句需求 / theme 未定
        │
        ▼
  docs/intake/<YYYY-MM>/drafts/          ← 活跃 scratch
        │ promote（可 1→N）
        ├──────────────┬───────────────┐
        ▼              ▼               ▼
  INT-00N         drafts/archive/    删除源 draft
（正式种子）      （可选留痕）       （可选不留痕）
```

| | Draft（活跃） | Draft（已归档） | INT |
|--|---------------|-----------------|-----|
| 路径 | `drafts/<YYYY-MM-DD>-<slug>.md` | `drafts/archive/<…>.md`（可选） | `INT-00N-<slug>.md` |
| 序号 | **无** | **无** | 全局 Next ID |
| 进消化清单 | **否** | **否** | **是** |

## 命名

```text
docs/intake/<YYYY-MM>/drafts/2026-08-27-xiaoshan-chat.md
docs/intake/<YYYY-MM>/drafts/archive/2026-08-27-xiaoshan-chat.md   ← 若选择归档
```

- 前缀：登记日 `YYYY-MM-DD`  
- 后缀：短 kebab slug  
- **禁止**使用 `DRAFT-001` 全局编号  

## 状态

| status | 含义 | 位置 |
|--------|------|------|
| `scratch` | 草稿纸，默认可续写 | `drafts/` 根下 |
| `promoted` | 已拆出 INT | **archive** 或 **删除**（二选一） |
| `discarded` | 否决 / 无用 | archive 或删除 |

## 晋升（promote）

1. 用户说「落成 INT / 收件 / 拆成种子」或确认已够 1–3 句种子  
2. 从 draft **拆出 1–N 条** INT（一对多常见）  
3. 占 Next ID；更新根 README / 月 README  
4. 处理源 draft（**二选一**，默认问用户；未指定时默认 **archive**）：  
   - **archive**：填 `promoted_to` / `promoted_on` → 移入 `drafts/archive/`  
   - **delete**：确认 INT 已写好后 **删除** 源 draft 文件（可不留痕）  
5. 从 `drafts/README.md` 活跃表移除  
6. 源 draft（无论归档或删除）**不进** theme 消化清单  

## Agent 路由

| 用户意图 | 落点 |
|----------|------|
| 「先记一下 / 还没想清楚 / 帮我理理 / 碎片聊」 | **draft**（`drafts/` 根下） |
| 「收件 / 落成 INT」且已够种子 | **INT** + 源 draft → **archive 或 delete** |
| 「晋升后删掉草稿」 | promote + **delete** |
| 「晋升后归档」 | promote + **archive** |
| 够清楚且要消化 | BMAD / OpenSpec（非 draft） |

**禁止**：半截聊天直接占用 `INT-00N`；`promoted` 草稿继续留在 `drafts/` 根下。

## Cursor 命令

| 命令 | 用途 |
|------|------|
| `/intake-draft` | 活跃草稿纸 |
| `/intake-register` | 正式 INT |
| `/intake-promote` | 晋升；源 draft **archive** 或 **delete** |

---

## 维护

- 活跃 drafts 仅扫 `drafts/*.md`（不含 `archive/`）  
- `discarded` 同样可选 archive 或 delete  
- 证据摸底仍可进 `docs/YYYY-MM-DD-*`；draft 只存需求意图碎片
