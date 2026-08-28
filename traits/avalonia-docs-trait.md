# avalonia-docs

Trait: how to use the **Avalonia Docs MCP** (`avalonia-docs` / namespace typically `user-avalonia-docs`) as the authoritative source for Avalonia API, AXAML, styling, binding, and migration guidance—before inventing WPF-shaped patterns or guessing from memory.

## Purpose (non-negotiable)

- Avalonia is **not** WPF / UWP / WinUI. Do not assume WPF APIs, triggers, `DependencyProperty`, or `pack://` URIs work.
- Prefer **live docs + expert rules from MCP** over stale training recall for Avalonia framework behavior.
- This trait governs **documentation lookup and framework idioms**. It does **not** replace project `AGENTS.md` (architecture, DI, MVVM stack, Semi/Ursa themes).

## When this trait applies

- Editing or authoring Avalonia UI in any repo under this workspace (commonly `repos/MaterialClient/`: `.axaml`, Views, controls, styles, themes, bindings).
- User asks Avalonia how-to, API meaning, styling/selectors, compiled bindings, layout, DevTools package migration, or WPF→Avalonia porting.
- Implementing OpenSpec tasks that touch Avalonia XAML / controls / visual tree behavior.

Do **not** force Avalonia Docs MCP for pure backend C# with no UI (services, EF, ABP) unless the question is Avalonia-specific (e.g. `Dispatcher.UIThread`).

## MCP inventory (tool routing)

Discover schemas with `GetDynamicTools` on namespace `user-avalonia-docs` (or the active alias) before calling. Then route:

| Intent | Tool | Notes |
|--------|------|-------|
| Start of Avalonia coding / design session | `get_avalonia_expert_rules` | Load once per session (or after long gap); baseline idioms |
| Conceptual / how-to search | `search_avalonia_docs` | Specific queries: e.g. `TreeView data binding`, `compiled bindings x:DataType` |
| Exact type / member | `lookup_avalonia_api` | e.g. `StyledProperty`, `Window.Show`, `TopLevel` |
| WPF→Avalonia topic table | `lookup_wpf_to_avalonia_mapping` | One `topic` enum at a time |
| WPF migration entry | `analyze_wpf_project` | Then `migrate_to_avalonia` or `migrate_to_xpf` as recommended |
| DevTools package / bootstrap | `migrate_diagnostics` | Prefer over hand-editing Diagnostics packages |
| Auth if namespace `needsAuth` | `mcp_auth` | Only when required |

### Sibling MCP: `avalonia_devtools` (UI inspection)

| Need | Use |
|------|-----|
| Docs, API, idioms, migration playbooks | **avalonia-docs** (this trait) |
| Live tree / props / screenshot / attach to running app or previewer | **avalonia_devtools** |

Do not use docs MCP to “inspect” a running UI; do not use DevTools as a substitute for API documentation.

## Precedence (conflict resolution)

When sources disagree, apply **stricter / more specific** in this order:

1. **User explicit instruction** for the current task  
2. **Sub-repo `AGENTS.md`** (e.g. MaterialClient: ReactiveUI, Semi.Avalonia / Ursa, ABP layering)  
3. **Main-repo `AGENTS.md`** (OpenSpec, Service vs Repository, no tuple, …)  
4. **Avalonia Docs MCP** expert rules + search/API results  
5. General training knowledge  

Example: MCP expert rules may say “prefer CommunityToolkit.Mvvm / avoid ReactiveUI”. If the target project **already** standardizes on ReactiveUI (MaterialClient), **keep ReactiveUI**; still follow MCP for property system, AXAML, styling, bindings syntax, layout, and DevTools package names.

## Behavior guardrails

- **Before** inventing Avalonia XAML or control APIs: call `get_avalonia_expert_rules` (if not loaded this session) and/or `search_avalonia_docs` / `lookup_avalonia_api` for the concrete topic.
- Prefer **compiled bindings** + `x:DataType` unless the project or MCP docs say otherwise for that case.
- Prefer Avalonia idioms: `.axaml`, `StyledProperty` / `DirectProperty`, style **selectors** + pseudo-classes, `IsVisible`, `avares://` — not WPF triggers / `DependencyProperty` / `Visibility` enum / `pack://`.
- Never recommend the deprecated `Avalonia.Diagnostics` package; use MCP `migrate_diagnostics` / `AvaloniaUI.DiagnosticsSupport` guidance.
- Do not dump entire expert-rules into OpenSpec `proposal.md` / `design.md`; cite only decisions that affect the change.
- Do not expand change scope to “rewrite MVVM stack to match MCP defaults” unless the user/proposal explicitly requires it.
- If MCP is offline / namespace missing: say so briefly, fall back to project code + local docs, and avoid confident WPF-shaped guesses.

## Prompt

You operate under avalonia-docs. Follow this when Avalonia UI work is in scope.

### 1. Confirm scope

If the task touches AXAML, controls, styles, themes, bindings, visual tree, or Avalonia threading/windowing → this trait is **on**. Otherwise skip.

### 2. Session bootstrap

1. Ensure MCP namespace is available (`GetDynamicTools` / status). Authenticate only if `needsAuth`.
2. If not already loaded this session, call `get_avalonia_expert_rules`.
3. Note project MVVM / theme stack from sub-repo `AGENTS.md` so you do not “correct” it toward generic MCP defaults.

### 3. Answer or implement with docs first

| Question type | Action |
|---------------|--------|
| “How do I …” / concepts | `search_avalonia_docs` with a **specific** query |
| “What is X / does Y exist” | `lookup_avalonia_api` |
| WPF habit / rename table | `lookup_wpf_to_avalonia_mapping` |
| Porting a WPF app | `analyze_wpf_project` → migrate playbook tools |
| DevTools setup | `migrate_diagnostics` |

Then implement or advise using returned guidance **filtered** by project AGENTS precedence.

### 4. Split docs vs runtime inspection

- Docs / API uncertainty → avalonia-docs.  
- “What does this running UI look like / which property is set” → avalonia_devtools.  
- Both allowed in one session; do not conflate them.

### 5. Close the loop

- Prefer citing the MCP-backed fact (API name, selector, package) over vague “Avalonia usually…”.  
- If project convention overrides MCP (e.g. ReactiveUI), state that override once when relevant, then proceed.
