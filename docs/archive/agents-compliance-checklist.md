# AGENTS Compliance Checklist

Rule IDs used by `/opsx-verify-agents` and `scripts/validate-agents-implementation.ps1`.

Mechanical rules are enforced by the PowerShell script (may have false positives). Semantic rules are reviewed by the agent during verify.

## OpenSpec placement

| ID | Severity | Source | Check |
|----|----------|--------|-------|
| OS-001 | error | Monorepo AGENTS — OpenSpec location | Changed files must not add or modify `repos/*/openspec/**` |

## C# — records vs tuples

| ID | Severity | Source | Check |
|----|----------|--------|-------|
| CS-001 | error | Monorepo + sub-repo AGENTS | No tuple as return type, parameter, local, or field in changed `.cs` files (`ValueTuple`, `System.Tuple`, parenthesized type lists in signatures) |
| DOC-001 | warning | Monorepo AGENTS | `design.md` / `tasks.md` in the change dir should not use C# tuple syntax in API sketches |

## Layering (MaterialClient / UrbanManagement)

| ID | Severity | Source | Check |
|----|----------|--------|-------|
| ARCH-001 | error | Monorepo AGENTS — Repository access | `*ViewModel*.cs` must not reference `IRepository<` or common repository methods (`GetListAsync`, `InsertAsync`, `UpdateAsync`, `DeleteAsync`) |
| ARCH-002 | warning | Monorepo AGENTS — UnitOfWork | Changed `*Service*.cs` methods that call write repository APIs should have `[UnitOfWork]` on the containing method (heuristic) |

## MaterialClient-specific

| ID | Severity | Source | Check |
|----|----------|--------|-------|
| MC-001 | error | MaterialClient AGENTS — ViewModel communication | No new `public event` in `*ViewModel*.cs` |
| MC-002 | error | MaterialClient AGENTS — ReactiveUI | Changed files must not reference `CommunityToolkit.Mvvm` |

## Semantic-only (agent review)

| ID | Category | Source | Check |
|----|----------|--------|-------|
| SEM-001 | Scope | Monorepo AGENTS — tech debt | Changes match `proposal.md` What Changes / Capabilities; no drive-by refactors |
| SEM-002 | Layering | Monorepo AGENTS | ViewModel → Service → Repository; no business logic wrongly placed in ViewModels |
| SEM-003 | Consistency | OpenSpec + AGENTS | Implementation matches `design.md` / delta specs; records used consistently |
| SEM-004 | Sub-repo | `repos/*/AGENTS.md` | All NON-NEGOTIABLE sections for repos in scope (MessageBus, ReactiveUI, naming, etc.) |

## Workflow

1. Complete implementation (`/opsx-apply` or manual).
2. Run `/opsx-verify-agents <change-name>`.
3. Fix violations; re-run until PASS.
4. Run `openspec validate <change-name> --strict` if not already done.
5. Archive with `/opsx-archive <change-name>`.
