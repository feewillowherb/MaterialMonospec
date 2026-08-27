# intake-parking

Trait: park fragmented requirements **before** formal planning (PRD / Epic) and **before** implementation changes (OpenSpec / equivalent). Defines Draft vs INT seeds, monthly folders, global IDs, promote disposition, and how **project-specific** themes/parks/repos stay outside this trait so it can be copied to other repos.

## Purpose (non-negotiable)

- Intake is a **seed inbox**, not a second PRD and not a substitute for OpenSpec (or your repo’s change workflow).
- **Draft** = scratch while chatting with an agent (no global ID).
- **INT** = formal seed (global `INT-00N`) ready to be absorbed into an Epic / change later.
- Digest by **theme** (cross-month). Physical layout by **calendar month** of `created`.

## When this trait applies

- User says: 先记下 / pending / 挂起 / 还没想清楚 / 帮我理理 / 收件 / 落成 INT / promote draft.
- Commands: `/intake-draft`, `/intake-register`, `/intake-promote` (if installed).
- Apply/research finds work **out of current change scope** → register INT (or Draft then promote), do **not** expand the current change.

Do **not** use Intake to open half-finished Epics or “bookkeeping” OpenSpec changes during a parked month.

## Portable layout (defaults)

Override only via project binding (see below). Defaults:

```text
{intake_root}/                      # default: docs/intake/
├── README.md                      # Next ID + theme index + month index
├── _template.md                   # INT template
├── _draft-template.md             # Draft template
├── themes.md                      # PROJECT BINDING (not in this trait)
├── parks.md                       # PROJECT BINDING (optional)
└── YYYY-MM/                       # from created date
    ├── README.md
    ├── drafts/
    │   ├── YYYY-MM-DD-<slug>.md   # active scratch
    │   └── archive/               # optional keep after promote/discard
    └── INT-00N-<slug>.md
```

| Item | Rule |
|------|------|
| Month folder | `YYYY-MM` from `created` |
| INT id | **Global** ascending `INT-001`…; **never** reset per month; track **Next ID** only in root `README.md` |
| Draft name | `YYYY-MM-DD-<slug>.md` — **no** global `DRAFT-00N` |
| Digest unit | **theme**, not month |
| Promote disposition | **archive** (move under `drafts/archive/`) **or** **delete**; default **archive** if unspecified |

## Draft vs INT

| | Draft | INT |
|--|-------|-----|
| When | Unclear theme; half-sentences; multi-turn chat | 1–3 sentence seed + theme |
| Next ID | **Do not** touch | Consume Next ID |
| Digest list | **No** | **Yes** |
| Status | `scratch` → `promoted` \| `discarded` | `open` → `triaged` → `absorbed` → `proposed` → `closed` |

### Promote

1. Split draft into **1–N** INT seeds.
2. Write INT files; bump Next ID; update indexes.
3. Disposition: **archive** (fill `promoted_to`, move to `drafts/archive/`) or **delete**.
4. **Forbidden**: leave `promoted` files in active `drafts/` root.

### INT required fields

`id`, `slug`, `title`, `status`, `kind`, `theme`, `intake_month`, `summary`, `source`, `created`  
Strongly recommended: `parked_until`, `repos`, `evidence`, `priority`, `depends_on`, `github`  
After digest: `absorbed_into`, `change`

`kind`: `product` | `tech-debt` | `security` | `ops` | `docs`  
`priority`: `P0`–`P3`

**Forbidden in INT/Draft:** full PRD, tasks lists, secrets, large pasted API specs.

## Project binding (business-sensitive — NOT in this trait)

This trait must stay **domain-agnostic**. Load project facts from files under `{intake_root}/`:

| File | Contents |
|------|----------|
| `themes.md` | Approved `theme` slugs, descriptions, optional epic hints, primary repos |
| `parks.md` | Active `park/<slug>` rows: description, `parked_until`, main themes |
| `README.md` | Next ID, live indexes (may embed park table) |

**Agents MUST:**

1. Read this trait for **mechanism**.
2. Read `{intake_root}/themes.md` (and `parks.md` if present) for **allowed themes / parks / repos**.
3. Prefer existing themes; new themes → append to `themes.md` first (with user OK).

**Agents MUST NOT** bake product names, customer sites, or repo lists into copies of this trait file when migrating.

### Theme rules (generic)

- Format: kebab-case, letter-start, ≤ 48 chars: `<domain>[-<facet>]`
- One INT → one primary theme (no multi-theme per row)
- `theme` ≠ OpenSpec change name

### Optional GitHub (generic)

- Title: `[INT-00N] …`
- Body line: `Intake: {path}`
- Labels: `theme:<theme>`, `park:<slug>`, `kind:<kind>`, `status:parked|absorbed|proposed`
- Pointer sync only — no full-text bidirectional sync

## Behavior guardrails

- Never consume INT id for half-formed chat → Draft first.
- Never self-promote Draft → INT unless user asks to 收件 / 落成 INT / promote (or confirms seed-ready).
- Never self-raise INT to `absorbed` / `proposed` unless user asks to digest / open a change.
- Parked window: only `open` / `triaged`; no placeholder Epics; no bookkeeping proposes.
- Do not use Intake as BMAD sprint / OpenSpec apply substitute.

## Prompt

You operate under intake-parking. Follow this for fragmented requirements and parked work.

### 1. Route

| Signal | Action |
|--------|--------|
| Unclear / 理理 / 碎片 | Write/update **Draft** under `{intake_root}/YYYY-MM/drafts/` |
| Seed-ready / 收件 | Write **INT**; bump Next ID; update README indexes |
| Promote | INT(s) then **archive** or **delete** source draft |
| Digest theme | Planning Epic then change workflow — not this trait’s implement path |

### 2. Load binding

Read `{intake_root}/themes.md` and `{intake_root}/parks.md` before assigning `theme` / `park`.

### 3. Paths

- INT: `{intake_root}/YYYY-MM/INT-<NextID>-<slug>.md`
- Draft: `{intake_root}/YYYY-MM/drafts/YYYY-MM-DD-<slug>.md`

### 4. After write

Update root README (and month README). For promote: update drafts README; archive or delete per disposition.

## Migrating this trait to another project

**Copy (portable):**

1. `traits/intake-parking-trait.md` (this file)
2. Optional: `.cursor/commands/intake-draft.md`, `intake-register.md`, `intake-promote.md` (retarget `{intake_root}` if needed)
3. Scaffold empty `{intake_root}/` with `_template.md`, `_draft-template.md`, `README.md` (Next ID `INT-001`)

**Create per project (do not copy from MaterialMonospec business data):**

1. `{intake_root}/themes.md` — empty table + rules, then fill local themes
2. `{intake_root}/parks.md` — local parked projects only
3. Require in that repo’s `AGENTS.md` (or docs AGENTS):

```markdown
| intake-parking | `traits/intake-parking-trait.md` | pending / 挂起碎片 / `/intake-*` |
```

**Do not migrate:**

- Customer/site-specific INT seeds (e.g. Xiaoshan upload items)
- Design research folders with local product narrative
- Theme/park rows naming other companies’ products
- Hard-coded repo names inside the trait file

**Optional:** keep a local `docs/YYYY-MM-DD-intake-parking/` only as decision history; runtime authority is this trait + `{intake_root}` binding.
