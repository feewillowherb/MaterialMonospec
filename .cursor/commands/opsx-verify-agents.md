---
name: /opsx-verify-agents
id: opsx-verify-agents
category: Workflow
description: Verify OpenSpec implementation compliance with AGENTS.md (pre-archive gate)
---

Verify that code and artifacts introduced for an OpenSpec change comply with `AGENTS.md` (monorepo and affected sub-repos). Run after implementation, before archive.

**Input**: Optionally specify a change name (e.g., `/opsx-verify-agents add-auth`). If omitted, list active changes and use **AskUserQuestion** when ambiguous. Do not auto-guess when multiple changes exist.

**Steps**

1. **Select the change**

   If a name is provided, use it. Otherwise:
   - Infer from conversation context if the user mentioned a change
   - Auto-select only if exactly one active change exists
   - If ambiguous, run `openspec list --json` and let the user select

   Announce: `Using change: <name>` and how to override.

2. **Load OpenSpec context**

   ```bash
   openspec status --change "<name>" --json
   ```

   Read (at minimum):
   - `openspec/changes/<name>/proposal.md` — affected repos, capabilities, explicit tech-debt scope
   - `openspec/changes/<name>/tasks.md` — task completion
   - `openspec/changes/<name>/design.md` if present — API sketches, architecture

   From proposal/tasks, determine affected scope:
   - Monorepo OpenSpec only
   - `repos/MaterialClient`
   - `repos/UrbanManagement`

3. **Task gate**

   Count incomplete tasks (`- [ ]`) in `tasks.md`.

   - If any remain: show count, warn, and ask whether to continue verification anyway.
   - Do not mark tasks complete in this command.

4. **Build review file scope**

   Collect paths changed for this implementation. Prefer merge-base diff per repo:

   ```bash
   # Monorepo root (OpenSpec + scripts)
   git diff --name-only origin/main...HEAD -- openspec/ scripts/
   git diff --name-only
   git diff --cached --name-only

   # Per sub-repo (when in scope)
   git -C repos/MaterialClient diff --name-only origin/main...HEAD
   git -C repos/MaterialClient diff --name-only
   git -C repos/MaterialClient diff --cached --name-only
   ```

   If `origin/main` is unavailable, use working tree + staged diffs and note the limitation in the report.

   Write the union of paths to a temp file, e.g. `.cursor/.opsx-verify-<name>-files.txt` (create `.cursor` if needed). Exclude paths that do not exist on disk.

   If the file list is empty: warn that no implementation diff was found; ask whether to verify OpenSpec artifacts only.

5. **Read AGENTS sources**

   Always read `AGENTS.md` at the monorepo root.

   For each sub-repo in scope, read `repos/<Repo>/AGENTS.md`.

   When rules conflict, apply the **stricter** rule (per monorepo AGENTS).

6. **Mechanical validation**

   Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/validate-agents-implementation.ps1 `
     -ChangeName "<name>" `
     -FileListPath ".cursor/.opsx-verify-<name>-files.txt" `
     -Repos "<comma-separated: MaterialClient,UrbanManagement or subset>"
   ```

   Parse script output (rule IDs, files, messages). Non-zero exit code means mechanical failures.

   Reference: `docs/agents-compliance-checklist.md` for rule definitions.

7. **Semantic review (agent)**

   Review only files in the scope list plus change artifacts. Check items that scripts cannot reliably detect:

   **Scope (monorepo AGENTS — tech debt / blast radius)**
   - [ ] Changes stay within `proposal.md` What Changes / Capabilities
   - [ ] No unrelated refactors, renames, or drive-by cleanup
   - [ ] Completed tasks do not implement out-of-scope work

   **Architecture (monorepo AGENTS — layering)**
   - [ ] ViewModels do not access data via Repository (including concrete repository types)
   - [ ] Data access goes through Service layer
   - [ ] New/changed write paths in Services use `[UnitOfWork]` where required
   - [ ] Services register via ABP dependency interfaces where applicable

   **Sub-repo NON-NEGOTIABLE rules** (when that repo is in scope)
   - MaterialClient: ReactiveUI only (no CommunityToolkit.Mvvm), MessageBus for VM communication, record-not-tuple, etc.
   - UrbanManagement: record-not-tuple, interface/impl file layout, source generators, etc.

   **OpenSpec consistency**
   - [ ] No new/updated OpenSpec artifacts under `repos/*/openspec/`
   - [ ] `design.md` / `tasks.md` signatures align with implementation (records, not tuples)

   Every finding must cite an AGENTS section or checklist rule ID.

8. **Report**

   Use this template:

   ```markdown
   ## AGENTS Compliance Report — <change-name>

   **Mechanical checks**: PASS | FAIL (N violations)
   **Semantic review**: PASS | WARN (M items) | FAIL (K violations)
   **Recommendation**: Ready for archive | Fix and re-run `/opsx-verify-agents` | Do not archive

   ### Mechanical failures
   | Rule ID | File | Message |
   |---------|------|---------|
   ...

   ### Semantic findings
   | Severity | Category | Finding | Suggested fix |
   |----------|----------|---------|---------------|
   ...

   ### Scope summary (from proposal)
   - Declared impact: ...
   - Files reviewed: ...

   ### Next steps
   - All clear → `/opsx-archive <name>`
   - Violations → fix in the correct repo, re-run this command
   ```

   If both mechanical and semantic pass with no warnings: state explicitly that `/opsx-archive` is recommended.

**Guardrails**

- Do **not** modify code, check off tasks, or archive unless the user asks separately.
- Do **not** replace `openspec validate <name> --strict` — that validates change artifacts; this command validates **implementation vs AGENTS**.
- Every finding must map to a checklist rule ID or AGENTS section.
- Prefer diff-scoped review; do not fail the change for unrelated legacy violations outside the file list.
- This command is a gate, not an auto-fix workflow.

**Fluid workflow**

- Run after `/opsx-apply` completes (or between apply sessions on partial work).
- Run again after fixes until PASS.
- Pair with `/opsx-archive` as the recommended pre-archive step.
