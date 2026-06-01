---
name: openspec-verify-agents
description: Verify OpenSpec implementation compliance with AGENTS.md after apply. Use when the user wants an AGENTS gate before archive or asks to verify agents compliance.
license: MIT
compatibility: Requires openspec CLI and scripts/validate-agents-implementation.ps1.
metadata:
  author: materialmonospec
  version: "1.0"
---

Verify that implementation for an OpenSpec change complies with monorepo and sub-repo `AGENTS.md`.

**Input**: Optional change name. If omitted, infer from context or prompt via `openspec list --json`.

**Steps**

Follow `.cursor/commands/opsx-verify-agents.md` exactly:

1. Select change and announce it.
2. Load `openspec status`, `proposal.md`, `tasks.md`, `design.md`.
3. Task gate for incomplete checkboxes.
4. Build diff-scoped file list; write `.cursor/.opsx-verify-<name>-files.txt`.
5. Read `AGENTS.md` and affected `repos/*/AGENTS.md`.
6. Run `scripts/validate-agents-implementation.ps1`.
7. Perform semantic AGENTS review on scoped files only.
8. Emit the compliance report template; recommend `/opsx-archive` only on full pass.

**Guardrails**

- Read-only unless the user explicitly requests fixes.
- Cite `docs/agents-compliance-checklist.md` rule IDs in findings.
- Stricter rule wins when monorepo vs sub-repo AGENTS differ.
