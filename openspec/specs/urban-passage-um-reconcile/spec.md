# urban-passage-um-reconcile Specification

## Purpose
TBD - created by archiving change update-urban-passage-client-upload-reconcile. Update Purpose after archive.
## Requirements
### Requirement: ClientUpload reconcile cook chain

The pipeline graph `urban-passage-um-reconcile` SHALL provide a **ClientUpload** mode that validates real MaterialClient passage upload to UrbanManagement without Bridge POST simulation. The graph MUST configure the client `UrbanManagement:BaseUrl` to the reconcile target UM instance before cook.

#### Scenario: End-to-end client upload cook

- **WHEN** an operator runs ClientUpload mode with UrbanManagement running locally
- **THEN** the graph MUST seed license and LPR settings, inject passage cases via diagnostic API, wait for client upload, and GET UM checkpoint and finished-product lists
- **AND** MUST compare plates against local seed expectations (5 checkpoint + 5 finished-product)

#### Scenario: Bridge is not the default path

- **WHEN** documentation or default script parameters describe the primary reconcile flow
- **THEN** ClientUpload MUST be the default mode
- **AND** Bridge POST MUST NOT be documented as the primary production validation path

### Requirement: Graph WIP until ClientUpload passes

While ClientUpload implementation is incomplete, the graph metadata `graph.status` MUST be `wip`. After L0–L2 pass on ClientUpload in a cook run, maintainers MAY set `graph.status` to `active`.

#### Scenario: WIP metadata

- **WHEN** the change is proposed but not yet applied
- **THEN** `pipelines/graphs/urban/urban-passage-um-reconcile/config.yaml` MUST have `graph.status: wip`
- **AND** `pipeline.md` MUST state dependency on this OpenSpec change

### Requirement: Reconcile evidence package

ClientUpload runs MUST capture HTTP evidence for UM list queries, client probe summary, seed summary, and plate-match reconcile JSON under `runs/<timestamp>/`.

#### Scenario: Evidence sinks

- **WHEN** a ClientUpload cook completes
- **THEN** `summary.json` and `reconcile/plate-match.json` MUST exist
- **AND** client probe output MUST exist under `client-probe/` when probe step ran

