## ADDED Requirements

### Requirement: Monospec authority layers stay distinct

The orchestration repository SHALL keep separate authorities for feasibility, capability delivery, epic stop conditions, reusable knowledge, and pipeline acceptance. Product SHALL statements remain in `openspec/`. Node.js cook behavior remains defined by `pipelines/AGENTS.md`.

#### Scenario: Pipeline result is not product approval

- **WHEN** a pipeline run reaches a passing evidence result
- **THEN** that result SHALL NOT authorize a product behavior change
- **AND** a product change SHALL require the existing OpenSpec workflow
- **AND** a change that originates from pipeline or DOCS evidence SHALL also have an explicit Human `APPROVED` decision

#### Scenario: Feasible is not delivered

- **WHEN** an investigation records a FEV verdict of FEASIBLE
- **THEN** that verdict SHALL NOT be treated as an ICD PASS

### Requirement: Task completion does not prove capability delivery

An OpenSpec change SHALL treat checked tasks as evidence that the listed file work is done. Checked tasks SHALL NOT by themselves prove that a declared capability is delivered.

#### Scenario: All tasks are checked

- **WHEN** every item in `tasks.md` is checked
- **THEN** an agent SHALL NOT claim the capability is delivered unless acceptance evidence for the declared ICD level exists

### Requirement: Acceptance scales do not imply one another

Pipeline acceptance SHALL use P0–P3. ICD capability acceptance SHALL use L1–L4. Requirement-risk judgment in `guess-governance` SHALL keep its own L1–L3. An agent SHALL NOT convert a level in one scale into a level in another scale.

#### Scenario: Cook evidence is labeled

- **WHEN** an agent reports a pipeline cook result
- **THEN** the agent SHALL use P0–P3 for that cook result
- **AND** the agent SHALL NOT describe that cook result as an ICD L3 capability delivery

### Requirement: Technology stack remains unchanged

This authority upgrade SHALL NOT change the product language or framework choices, the Node.js cook runtime, or the child-repository architecture. It SHALL NOT require Python cook, parallel investigation leases, or DCC context objects for existing graphs.

#### Scenario: Existing graph is given a contract

- **WHEN** a contract file is added to an existing graph
- **THEN** the graph cook scripts and `config.yaml` behavior SHALL remain unchanged
- **AND** the contract SHALL describe inputs, outputs, and invariants already stated by that graph
