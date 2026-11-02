---
name: investigate-with-evidence
description: Organize or resume multi-stage technical investigations with important uncertainty. Connect user goals, experiments, design updates, reusable knowledge, and implementation handoff. Use for evidence-driven research that needs execution; do not impose the full workflow on simple lookups or known fixes.
---

# IWE — Investigate With Evidence

Keep the goal, investigation route, experiment results, and reusable knowledge connected. IWE is an execution skill, not a new authority for feasibility, acceptance, or delivery status.

## Resolve project context

Start from the target project's `AGENTS.md`. Follow its subtree and Trait discovery rules; resolve project paths from that root, not from the skill's installation directory. Read the relevant Topic Summary before expanding supporting material.

This skill expects FEV, ICD, DOCS, and CED contracts or explicit project equivalents. Use only the contracts applicable to the task. If an authority needed for the requested work is absent or conflicting, identify that boundary; continue independent research within scope without inventing a Verdict, approval, or delivery policy. Do not install frameworks automatically.

| Owner | Use it for |
|---|---|
| FEV | Question, Experiment, Evidence, Local and Aggregate Verdict |
| DOCS | Reusable findings, design rationale, source references and knowledge state |
| ICD | Declared production capability and independent acceptance |
| CED | Formal delivery continuation, defer, stop and completion state |
| Project change workflow | Requirements, implementation scope and Promotion authorization |

For a compact worked example, read [the walkthrough](references/walkthrough.md) when first learning the workflow. It is illustrative, not project Evidence. For behavioral evaluation, use [the evaluation guide](references/evaluation.md); ordinary tasks do not need an evaluation report.

## 1. Recover the actual starting point

Identify the requested outcome, non-goals, important decisions, existing evidence, authorization and user-requested checkpoints. Reconcile handoff text with current artifacts and runtime conditions. Prefer current reliable evidence over a stale summary; do not repeat completed work merely because the handoff omits it.

Research-only or single-experiment requests remain limited to that scope. Ask only for missing information that materially changes the route, and continue independent authorized work while awaiting it.

## 2. Connect the route to the goal

Describe the smallest useful route from baseline to target. For each important stage, identify the question, input, observable output, dependencies and how its answer affects the route. Reuse or update an existing design instead of adding a parallel plan.

Separate known facts, hypotheses and unknowns. Apply the FEV Risk Gate; do not turn every stage or failed command into a Sub-FEV. Before running experiments, identify where design, actual results and durable interpretation belong under the project's contracts. Do not require a fixed number of documents or stages.

## 3. Resolve the next consequential uncertainty

Select a question whose dependencies are satisfied and whose answer can change the route. Check reusable evidence first, then execute the smallest discriminating experiment in the relevant environment with explicit observations and criteria.

Handle ordinary execution errors locally. New evidence may require changing the hypothesis or implementation route. If downstream behavior exposes an upstream error, repair the responsible layer and identify the affected dependencies. Refresh the affected evidence and references; do not silently reuse invalidated runs or rerun unrelated stages.

Respect the project's runtime isolation, resource ownership and experiment rules. A request for investigation does not itself authorize external publication or production changes.

## 4. Close each meaningful stage with integration

Before selecting the next step, answer:

- What question was answered, and how does it affect the user's goal?
- What is observed, inferred or still unknown?
- Which design decisions, dependencies and canonical references changed?
- What authorized work is now ready and useful?

Update the affected authoritative artifacts and reusable DOCS knowledge as part of stage completion. Do not copy every tool result or conversation turn; do not update unrelated documents merely to satisfy a template.

Report goal progress, essential evidence, limitations and the next action. A successful probe is not the end of a broader authorized investigation. Continue while another useful experiment can answer an important remaining question; use FEV's stopping criteria rather than inventing retry quotas.

## 5. Preserve the decision and delivery boundaries

Honor explicit user checkpoints and reuse existing authorization. For a necessary user choice, first prepare a concrete result, recommendation and consequences. Do not turn ordinary repair or a stage name change into repeated approval.

When the research question is sufficiently answered, give the supported route, conditions, limitations and implementation guidance. Research may end here. Enter production only under the applicable Promotion authorization and formal change workflow. Preserve proven behavior while deciding what experimental code should be retained, refactored or rewritten; do not mandate rewriting everything.

Once operating within a formal delivery effort, use CED for continuation, defer, stop and completion decisions. IWE supplies investigation evidence; it does not create competing Epic states. ICD independently judges production behavior: FEV FEASIBLE is not ICD PASS.

## Resume and handoff

Leave the goal, decisions, current authoritative entry points, evidence identities, relevant environment constraints, Negative Findings, next dependency and authorization boundary. Explain what remains unverified. The receiving agent must still reconcile this handoff with current facts.
