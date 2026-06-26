# doc-first

Trait: document-first development flow for spec-driven changes (propose → design → apply → archive). When the user provides document references in their primary statement (主述), those documents are the authoritative source of truth — the proposal must be anchored to them, not fabricated from topic keywords alone.

## Core principle

In a doc-first flow, **documents are the requirement**. The user expresses intent by pointing to one or more document files; the AI's job is to read, comprehend, and translate those documents into a structured proposal — not to invert the process by guessing intent from a topic label and then checking if documents happen to agree.

This trait activates when the user's primary statement contains explicit document paths (file paths, relative paths, or unambiguous document references). It modifies the explore/propose phase of the OpenSpec workflow.

## Behavior rules

### Document path extraction

1. **Parse all document references** from the user's primary statement before any other reasoning.
2. A document reference is any of:
   - An absolute or relative file path (e.g., `docs/urban-blazor-epic.md`, `./specs/auth-flow.md`)
   - A path-like string with file extension (`.md`, `.pdf`, `.docx`, `.txt`, `.yaml`, `.json`)
   - A clearly identifiable document name when context resolves it unambiguously (e.g., "the urban epic doc" when only one file matches)
3. List every extracted reference with its resolved path and read status.

### Mandatory read-before-propose

4. **Read every referenced document in full** before generating any proposal content. No skimming, no summarizing from first paragraphs.
5. If a document is large (>500 lines), read it in chunks; do not skip sections.
6. If a document references other documents (transitive dependencies), follow and read those too unless the user explicitly scopes to a subset.
7. Do not generate a proposal until all extracted documents have been read and their read status is `complete`.

### Document anchoring

8. The proposal's **"What Changes"** section must trace back to specific sections, paragraphs, or artifacts in the referenced documents.
9. Every requirement bullet in the proposal must carry a source tag: `[Doc: filename#line-or-section]`.
10. If a document contradicts the user's stated topic, the contradiction must be surfaced explicitly — do not silently side with the topic.
11. If the documents cover scope beyond the stated topic, acknowledge the excess; do not silently expand or contract scope.

### Anti-patterns (never do these)

- **Topic fabrication**: Generating a proposal from the topic name alone, ignoring referenced documents.
- **Partial read**: Proposing after reading only the introduction or summary of a referenced document.
- **Path dismissal**: Treating document paths in the primary statement as optional hints rather than mandatory inputs.
- **Keyword hallucination**: Inventing requirements that plausibly match the topic but are absent from the documents.
- **Scope drift**: Expanding the proposal beyond what the documents describe, or shrinking it to avoid document complexity.

## Prompt

You operate under doc-first governance. Follow this prompt for every explore/propose phase when the user's primary statement contains document references.

### 1. Extract and resolve document references

From the user's primary statement:

1. List every document reference found (path or identifiable name).
2. Resolve each to an absolute or project-relative path.
3. If any reference cannot be resolved, stop and ask the user — do not guess.

Output:

```
## Document references extracted
| # | Raw reference | Resolved path | Read status |
|---|---------------|---------------|-------------|
| 1 |               |               | pending     |
```

### 2. Read all documents

1. Read each document in full.
2. For each document, produce a brief structural map (sections, key artifacts, decisions).
3. Update the read status table above to `complete`.

Output after reading:

```
## Document structural maps
### [filename]
- Section "X": covers ...
- Section "Y": covers ...
- Key artifacts: ...
- Key decisions: ...
```

### 3. Synthesize proposal from documents

1. The proposal title should reflect the documents' scope, not just the topic label.
2. **"What Changes"** must list requirements derived from the documents. Each item carries `[Doc: filename#line-or-section]`.
3. If the documents describe a multi-phase or multi-component scope, the proposal should reflect that structure — do not flatten into a single monolithic list.
4. If the topic implies scope not present in the documents, list it explicitly under "Topic-suggested scope (not in documents)" and ask the user whether to include it.
5. If the documents contain scope beyond the topic, list it under "Document scope beyond topic" and ask the user whether to include it.

### 4. Produce proposal content (required additions)

In addition to standard proposal sections, include:

```markdown
## Document-first summary
| Field | Value |
|-------|-------|
| Documents referenced | count |
| Documents fully read | count / count |
| Requirements sourced from documents | count |
| Requirements from topic only | count (should be 0) |
| Unresolved contradictions | none / description |

## Document references
| # | Path | Read status | Requirements derived |
|---|------|-------------|---------------------|
| 1 |      | complete    | N items              |
```

### 5. Guardrails for design and apply phases

- **design.md**: every design decision must reference which document requirement it fulfills.
- **tasks.md**: every task must trace to a document-derived requirement via `[Doc: ...]` tag.
- If implementation reveals that a document requirement needs clarification, flag it immediately — do not substitute your own interpretation silently.
- When documents are updated mid-change, re-read the updated documents and propagate changes to the proposal, design, and tasks.

### 6. When blocked

If doc-first governance blocks progress:

- State which documents could not be read or resolved.
- State which sections are ambiguous or contradictory.
- Recommend next action: ask user for clarification, split change by document scope, or read additional referenced documents.

Do not bypass document-first governance because the documents are long, complex, or partially irrelevant. Length and complexity are reasons to read more carefully, not less.
