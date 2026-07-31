# standard-words

Trait: how to author and maintain a `standard_words.yaml` glossary that feeds an AI coding assistant a project's **canonical terminology** (标准用语), so generated code, comments, commit messages, and translations use the project's own vocabulary instead of generic guesses. Defines the file's purpose, schema, authoring workflow, field conventions, a blank template, and quality rules. This file contains **no project-specific terms**—each target project fills the glossary from its own source.

## What standard_words.yaml is

- A hierarchical glossary of standard terms, grouped by domain, that is submitted to the AI assistant as project context.
- Each entry pairs a short **label** (what a human picks) with a **submittedText** (the canonical phrase fed to the model, usually the standard term plus its code identifier).
- Lives at the tool's convention path (commonly `<repo>/.hagicode/standard_words.yaml`). Confirm the exact path and `schemaVersion` expected by the tool before editing.
- It is a **living config**: regenerate or extend it whenever enums, DTOs, or domain language change.

## When to use it

- The project has domain-specific words, abbreviations, or translations the assistant would otherwise mistranslate or invent.
- Code carries canonical wording in machine-readable places: enum `[Description(...)]` attributes, resource/localization files, display-name constants, DTO and service names.
- Multiple synonyms circulate for the same concept and one standard form must win.

Do **not** use it to dump arbitrary strings. It is for terms the assistant should treat as authoritative.

## Schema reference

Top level:

- `schemaVersion` — version declared by the tool (keep what the tool expects).
- `groups` — list of top-level groups.

A **group** may contain any of:

- `id` — kebab-case unique identifier.
- `label` — human-readable group name.
- `enabled` — boolean; include to toggle the whole group.
- `order` — integer; controls display order among siblings.
- `tags` — list of keywords (domain/category).
- `language` — primary language scope of the group (e.g. `C#`, `TypeScript`, `Markdown`). Phrases inherit it; set per group, not per phrase.
- `metadata` — free-form map; recommended key `desc` for a one-line group summary.
- `phrases` — list of term entries (see below).
- `children` — list of nested groups (same shape as a group). Use nesting for sub-domains instead of a flat list.

A **phrase** entry:

- `key` — kebab-case, globally unique across the whole file.
- `label` — short canonical display term (what shows in a picker).
- `submittedText` — the canonical phrase fed to the assistant. Richer than `label`: standard term plus code identifier and, where useful, the enum value (e.g. `"Term（EnumName.Member = n）"`).
- `enabled` — boolean.
- `order` — integer; ordering within the group.
- `metadata.desc` — one-line meaning in context (most useful metadata field).

A group uses **either** `phrases` directly **or** `children` (sub-groups that hold phrases)—pick the shape that matches the domain's depth.

## Authoring workflow

### 1. Confirm schema and location

Read the existing `standard_words.yaml` (or the tool's docs) to lock `schemaVersion`, the file path, and which optional fields the parser actually consumes. Match what is already there; do not invent fields.

### 2. Mine real terms from the codebase

Extract canonical wording only from source—never invent. Productive seams:

- Enum files, especially members with display attributes (`[Description]`, `Display(Name=...)`, annotations).
- DTO / entity / service class names and their XML doc comments.
- Localization / resource files (`.resx`, JSON i18n) where user-facing strings live.
- Domain docs, glossaries, operation manuals.

Record, per term: the canonical display string, the code identifier, and (for enums) the numeric value.

### 3. Group by domain

Cluster terms into top-level groups by business domain, then sub-groups (`children`) where a domain has natural sub-categories. Mirror how the team talks about the system, not how the filesystem is laid out.

### 4. Write phrases

For each term produce `key` (unique kebab id), `label` (short), `submittedText` (term + identifier), and `metadata.desc`. Assign `order` sequentially within each list.

### 5. Validate

Parse the YAML and check: well-formed, no duplicate `key`, every phrase has `key`/`label`/`submittedText`/`enabled`/`order`, `id`s unique, no demo/placeholder leftovers.

## Field conventions

- **Uniqueness**: `id` unique among groups; phrase `key` globally unique.
- **Naming**: kebab-case for `id` and `key`; prefix keys by category to avoid collisions (e.g. `status-active`, `mode-x`).
- **label vs submittedText**: `label` is the picker label; `submittedText` is what the model receives. Keep them different on purpose—`submittedText` carries the code symbol the model needs.
- **language**: set once per group; omit on phrases so they inherit. Use `Markdown` (or the doc language) for groups that describe documentation/workflow artifacts rather than code.
- **order**: stable integers, spaced (0, 10, 20 …) at group level is fine; sequential (0,1,2 …) within phrase lists.
- **tags**: domain/identifier keywords for filtering; one meaningful tag beats many.
- **metadata**: prefer a single `desc` string; avoid dumping large prose.

## Blank template (generic — fill from the target project)

```yaml
# standard_words — project canonical terminology glossary
# Terms MUST be mined from this project's own source; do not leave placeholders.
schemaVersion: 1.0
groups:
- id: <domain-group>
  label: "<Domain Group Display Name>"
  enabled: true
  order: 0
  tags:
  - <keyword>
  language: <PrimaryLanguage>
  children:
  - id: <subgroup>
    label: "<Subgroup Display Name>"
    enabled: true
    order: 0
    tags:
    - <CodeIdentifier>
    language: <PrimaryLanguage>
    phrases:
    - key: <unique-phrase-key>
      label: "<Canonical Display Term>"
      submittedText: "<Canonical Term（CodeIdentifier.Member = value）>"
      enabled: true
      order: 0
      metadata:
        desc: "<one-line meaning in context>"
    - key: <another-phrase-key>
      label: "<Canonical Display Term>"
      submittedText: "<Canonical Term（CodeIdentifier.Member = value）>"
      enabled: true
      order: 1
      metadata:
        desc: "<one-line meaning in context>"
# A flat group (no children) puts phrases directly under the group:
- id: <stack-group>
  label: "<Tech / Stack Group>"
  enabled: true
  order: 10
  tags:
  - stack
  language: <PrimaryLanguage>
  phrases:
  - key: <lib-key>
    label: "<Library Name>"
    submittedText: "<Library Name（role in project）>"
    enabled: true
    order: 0
    metadata:
      desc: "<what it is used for here>"
```

## Quality checklist

Before considering the glossary done:

1. Every term is traceable to a real source location (enum member, DTO, resource, doc)—no invented wording.
2. No demo/placeholder data remains (no `Group 1` / `Phrase 1` / `label`/`metdata`-style leftovers).
3. YAML parses; no duplicate `key`; no duplicate group `id`.
4. Each phrase has `key`, `label`, `submittedText`, `enabled`, `order`.
5. `submittedText` differs from `label` where a code identifier exists (that is the point of having both).
6. `language` set per group; phrases inherit (not repeated per phrase).
7. Groups ordered; phrases ordered within each group.
8. Hierarchy used for real sub-domains; flat where the domain is shallow.
9. Scope matches intent: authoritative domain terms only—no random string dump.
10. Re-validatable by a script (parse + uniqueness + required-fields) so it can run in CI.

## Anti-patterns

- Leaving the shipped demo file unchanged (`Group 1` / `Phrase 1`) and shipping it.
- Inventing plausible-sounding terms not present in the codebase.
- Duplicating `key`s or `id`s.
- Repeating `language`/`tags` on every phrase when the group already carries them.
- Putting large prose or full sentences in `submittedText`; keep it the canonical term + identifier.
- Letting the glossary go stale after enums or DTOs change.
