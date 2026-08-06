# effort-token-estimate

Trait: how to estimate delivery effort for research and OpenSpec changes using **AI Agent token / context scale**, not human person-days. Defines purpose, tiers, where the estimate may live, and what must never appear in `proposal.md`.

## Purpose (non-negotiable)

- Effort exists **only as a workload reference** when judging feasibility, session splitting, and whether to open a change.
- It is **not** process accounting, billing, or a mandatory archive metric.
- Do **not** invent or demand “actual tokens consumed” unless the user explicitly asks to record them.

## When this trait applies

- Writing or updating research notes under `docs/<YYYY-MM-DD>-*/`.
- Creating or editing an OpenSpec change’s `.openspec.yaml`.
- User asks for 工作量 / effort / 落地评估 / 可落地 / 要不要拆会话.

Do **not** apply this trait to rewrite historical archived proposals that already use person-days unless the user asks.

## Estimate with tokens, not person-days

**Forbidden as the primary metric:** 人天、人周、working days、story points used as effort.

**Required primary metric:** S/M/L/XL token / context tiers (rough Agent cost for read + implement + verify dialogue; not exact billing).

| Tier | Approx. token band | Typical meaning |
|------|--------------------|-----------------|
| S | ~5万–15万 | Single repo, local change, one session |
| M | ~15万–40万 | Multi-file or cross-module; may need split |
| L | ~40万–100万 | Cross-repo or auth/data-model main path; multi-session |
| XL | ~100万+ | Multi-repo + integration; split by repo/phase |

Optional helpers (secondary only): files touched, critical paths, cross-repo list. Never lead with person-days.

Example phrasing:

```text
落地规模：L（跨 BasePlatform / UrbanManagement / MaterialClient，约 40万–100万 token 量级）
```

## Where effort may be written

| Location | Allowed? | Notes |
|----------|----------|-------|
| Research docs (`docs/...`) | Yes | Primary place during 调研 |
| Change `.openspec.yaml` | Yes | **Only** OpenSpec artifact that may carry effort |
| `proposal.md` | **No** | Keep Why / What / Capabilities / Impact only |
| `design.md` / `specs/` / `tasks.md` | **No** | Do not duplicate effort tables there |

### `.openspec.yaml` shape

Keep existing fields; add an `effort` block when estimating:

```yaml
schema: spec-driven
created: YYYY-MM-DD
effort:
  tier: S   # S | M | L | XL
  tokens_estimate: "5万-15万"   # optional
  # tokens_actual:             # optional; only if user asks to record
  # notes: "跨仓分会话"         # optional
```

- Propose time: set `tier` (and optional `tokens_estimate`) from research or scope.
- Archive time: do **not** require `tokens_actual`.
- Small / trivial changes: `tier: S` alone is enough.

## Behavior guardrails

- Prefer token tiers whenever the user asks for 评估 / 工作量 / effort.
- If tempted to write 人天, rewrite as tier + token band first.
- Never add an “工期估算” / “Estimated Effort: N days” section to `proposal.md`.
- Never put effort prose in Impact as a substitute for yaml—Impact stays product/tech impact.
- Cross-repo work: say which repos drive the tier and recommend session splits when L/XL.

## Prompt

You operate under effort-token-estimate. Follow this for research评估 and OpenSpec metadata.

### 1. Choose tier

From scope (repos, auth/schema risk, test/联调 need), pick exactly one of `S` | `M` | `L` | `XL`. Give a short token band. List cross-repo factors if any.

### 2. Write to the right place

- Still researching → put the estimate in the research folder (`00` / `02` or equivalent).
- Opening or updating a change → put effort **only** in that change’s `.openspec.yaml` under `effort:`.
- **Never** write effort into `proposal.md`.

### 3. Refuse person-day defaults

If a template or habit suggests person-days, replace with token tier. Do not apologize at length—just use the correct metric.

### 4. Keep actuals optional

Do not ask the user to fill actual token usage unless they want a retrospective. Do not block archive on missing `tokens_actual`.

### 5. When blocked

If scope is too fuzzy to tier, say so, list what is missing (repos? dual-write? BP?), and give a provisional tier range (e.g. `L～XL`) rather than inventing person-days.
