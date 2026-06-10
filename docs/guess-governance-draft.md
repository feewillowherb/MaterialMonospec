# User-Defined Content and Guess Governance (Draft)

> **Status**: Draft  
> **Scope**: Product or software projects where requirements are incomplete and AI or teams assist with design and implementation  
> **Goal**: Balance delivery speed with controllable risk by making assumptions explicit and separating them from confirmed requirements.

---

## 1. Background and Goals

### 1.1 Typical Problem

Stakeholders often state outcomes (for example, “improve throughput” or “reduce wait time”) without complete rules. Implementers—including AI—fill gaps with defaults. If those defaults are not recorded, the result may:

- Diverge from real stakeholder intent  
- Over-engineer in a single release  
- Ship irreversible changes that are hard to roll back  

### 1.2 Three Principles

1. **Make guesses explicit**: Inferences are *working assumptions*, not silent truth.  
2. **MVP commits to closure, not perfection**: Prefer runnable, verifiable, reversible delivery.  
3. **Validate high-risk guesses before scale-up**: Pilot or limit scope before full rollout.

---

## 2. Classification of Undefined Content

| Level | Definition | Allowed in MVP implementation? | Handling |
|-------|------------|--------------------------------|----------|
| **L1 Low risk** | Copy, default sort order, non-critical hints, configurable UI details | Yes | Ship in MVP with feature flags or config |
| **L2 Medium risk** | Default business rules, boundary defaults, retry/timeout parameters | Conditional | May ship in MVP; must be validated in a follow-up change |
| **L3 High risk** | Billing, compliance, security, audit, irreversible data changes | No guessing | List under *Decisions Needed*; implement only after review |

**Rule of thumb**: **Irreversible + high impact + hard to roll back** → do not implement from guesswork alone.

---

## 3. Proposal Information Structure

Each change or proposal should separate three kinds of information (this can live alongside existing `proposal.md` / `design.md` conventions):

| Type | Meaning | Who confirms |
|------|---------|--------------|
| **Facts** | Stakeholder-stated, must-deliver content | Product / business |
| **Assumptions** | Team or AI default choices, replaceable | Team registers; business samples as needed |
| **Decisions Needed** | Must not be treated as agreed requirements until closed | Product / business sign-off |

> **Naming note**: *Decisions Needed* in this document means items **awaiting stakeholder confirmation**. It is **not** the same as *Design Decisions* in technical design docs (choices **already approved** for implementation).

---

## 4. MVP and Incremental Change Path (Four Steps)

Use this path at **program or epic** level. A single OpenSpec change usually maps to **one** step, not all four.

### 4.1 Change A — Core (MVP closure)

- **Scope**: Shortest end-to-end path; assumptions must be configurable or disableable.  
- **Out of scope**: Full exception coverage, full ops tooling, unvalidated automation.  
- **Acceptance examples**: Main flow demonstrable; key assumptions have off-switch and rollback.

### 4.2 Change B — Assumption validation (before Full)

- **Scope**: Validate assumptions from Change A; collect real corrections and failure samples.  
- **Output**: Per-assumption disposition — **keep / replace / remove**.  
- **Acceptance examples**: High-risk assumptions verified; correction rate measurable.

### 4.3 Change C — Full (incremental detail)

- **Scope**: Promote validated assumptions to rules; add exception paths; no new problem domain.  
- **Acceptance examples**: Major exceptions reproducible and handled; correction rate lower than MVP.

### 4.4 Change D — Quality and delivery

- **Scope**: Regression tests, performance baselines, canary/rollback/degrade drills and runbooks.  
- **Acceptance examples**: Critical-path regression passes; rollback and degrade documented and practiced.

### 4.5 Per-change label (recommended in each `proposal.md`)

Do not paste the full four-step text into every proposal. Use a short label:

```markdown
## Delivery tier

| Field | Value |
|-------|--------|
| **Tier** | `Core` \| `Assumption-Validation` \| `Full` \| `Quality-Delivery` \| `N/A` |
| **Role in path** | e.g. second change in epic X; depends on `add-foo-core` |
| **Out of scope (vs four steps)** | e.g. no full validation batch, no perf hardening |
```

---

## 5. Metrics (Organization-Calibrated)

These are **internal governance metrics**, not industry standards. Thresholds should be calibrated from retrospectives.

### 5.1 Definitions

| Metric | Definition | Use |
|--------|------------|-----|
| **Guess Count** | Number of items listed as Assumptions | Scale awareness |
| **Guess Ratio** | Guess Count ÷ total requirement items | Review gate (below) |
| **Guess Risk Score** | Per item: Impact (1–5) × Uncertainty (1–5) × Irreversibility (1–5) | Per-item MVP eligibility |
| **Validation Coverage** | Verified assumptions ÷ total assumptions | Before full rollout |
| **User Correction Rate** | Stakeholder corrections ÷ adopted suggestions | Assumption quality review |
| **Rollback Readiness** | Flags, backups, rollback steps, drill evidence | Pre-release check |

### 5.2 Suggested thresholds (example only)

| Condition | Suggested action |
|-----------|------------------|
| Guess Ratio ≤ 20% | May proceed with assumption register attached |
| 20% < Guess Ratio ≤ 35% | Warning: add validation plan or split Change B |
| Guess Ratio > 35% | Avoid full implementation; clarify requirements or run Change B first |
| Any Guess Risk ≥ 40 without degrade path | Review fails |
| Non-reversible change without rollback | Do not release |

---

## 6. Degradation and Capability Levels

### 6.1 Four levels (recommended)

| Level | Mode | Description |
|-------|------|-------------|
| 0 | Manual | Fully human; business continues |
| 1 | Rules | Fixed rules + configuration; no autonomous AI decisions |
| 2 | Suggest (default) | System proposes; human confirms before effect |
| 3 | Auto (controlled) | Autonomous only when high confidence, low risk, reversible |

Default to Level 2; always allow fallback to Level 1 or 0.

### 6.2 Degrade triggers (examples)

Consider degrading when any of the following persist above threshold:

- Critical-path misclassification rate  
- User Correction Rate  
- Latency or error-rate regression  
- Alert frequency anomaly  

### 6.3 Anti–over-engineering constraints

1. Do not build full architecture for unvalidated assumptions.  
2. Do not add “might need later” full capabilities in MVP.  
3. Every new assumption-driven capability needs an off-switch or alternative path.

---

## 7. Document Templates

### 7.1 Change / proposal header

```text
Change name:
Delivery tier: Core | Assumption-Validation | Full | Quality-Delivery | N/A
Verifiable outcome:
Explicit non-goals:

Facts:
Assumptions:
Decisions Needed:

Guess Count:
Guess Ratio:
High-risk assumptions (Risk ≥ 40):
Validation plan and deadline:
Degrade plan:
Rollback plan:
```

### 7.2 Assumption register

| ID | Description | Risk | Validation | Due | Result | Disposition |
|----|-------------|------|------------|-----|--------|-------------|
| A-01 | Example: default timeout 30s | 12 | Integration test + monitoring | YYYY-MM-DD | Pending | keep / replace / remove |

### 7.3 Split vs existing design sections

| Section | Content |
|---------|---------|
| Facts / Assumptions / Decisions Needed | Requirement-side triage (this draft) |
| Design Decisions (existing practice) | **Approved** technical choices; tag source `[Fact]` or `[A-01]` |
| Open Questions | Align with Decisions Needed; move to Design Decisions when closed |

---

## 8. Review Checklist (Guess Governance)

Confirm before full implementation:

1. Facts, Assumptions, and Decisions Needed are separated.  
2. No L3 or high-risk assumption is scheduled for full rollout without confirmation.  
3. Each assumption has a validation plan and deadline (where required by tier).  
4. Degrade and rollback paths are actionable.  
5. Guess Ratio, Risk, and Validation Coverage meet organizational thresholds.  
6. If key assumptions fail validation, delivery can still continue via degrade paths.

If any item is **no**, do not proceed to full rollout.

---

## 9. Rollout Recommendations

- Link this draft into: change proposal templates, design review checklists, and pre-archive gates.  
- Pilot thresholds on two or three completed changes before fixing numbers as policy.  
- Retrospect each iteration: assumption hit rate, User Correction Rate, rollback/degrade triggers.  
- Promote to v1.0 after product, engineering, and quality joint review.

---

## 10. Version History

| Version | Date | Notes |
|---------|------|-------|
| draft-0.1 | 2026-06-01 | Generic draft; no product-specific examples |

---

## Appendix: Terminology

| Term in this draft | Often confused with |
|--------------------|---------------------|
| Decisions Needed | Pending business confirmation |
| Design Decisions | Approved technical/architecture choices |
| Assumption | Working hypothesis (not a Fact) |
| Guess Ratio | Internal ratio metric (not an industry standard) |
| Delivery tier | Which of the four incremental steps **this change** belongs to |
