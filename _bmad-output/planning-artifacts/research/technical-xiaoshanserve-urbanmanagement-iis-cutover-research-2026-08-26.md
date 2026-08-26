---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments:
  - openspec/changes/archive/2026-05-29-xiaoshanserve-to-urbanmanagement-abp-migration/proposal.md
  - openspec/changes/archive/2026-05-29-xiaoshanserve-to-urbanmanagement-abp-migration/design.md
  - openspec/specs/legacy-api-compat/spec.md
  - _bmad-output/planning-artifacts/materialclient-urban-epic/project-context.md
workflowType: 'research'
lastStep: 6
research_type: 'technical'
research_topic: 'XiaoShanServe to UrbanManagement IIS dual-port cutover and data migration'
research_goals: 'Lock IIS dual-binding approach, SQLite/image migration mechanics, ID mapping, and cutover runbook so PRD/Architecture/OpenSpec can proceed; exclude GovLog and XSS GovProject per locked decisions D1–D4'
user_name: '77162'
date: '2026-08-26'
web_research_enabled: true
source_verification: true
---

# Research Report: technical

**Date:** 2026-08-26
**Author:** 77162
**Research Type:** technical

---

## Research Overview

This technical research locks the **ops cutover** that finishes consolidating XiaoShanServe into UrbanManagement on one Windows IIS host: dual-port binding so unmodified GovClient keeps posting to the old port, offline migration of weighing records / `GovSyncData` / images into UM’s Guid-based SQLite + `Uploads/`, then decommission of XiaoShanServe under an approved write-stop window.

Key conclusions: prefer **one IIS site with two bindings** (no YARP unless binding is blocked); treat `LegacyApiController` as the in-process anti-corruption layer already in place; remap primary keys to Guid; copy images and rewrite relative paths; skip GovLog and XSS GovProject (UM is SoT); mark historically synced rows `SyncType=1` to avoid government re-push. Methodology combined Microsoft IIS/ASP.NET Core docs, SQLite ATTACH/WAL guidance, Strangler Fig / ACL / cutover runbook practice, and verification against the current UrbanManagement codebase and archived OpenSpec migration.

Full executive summary, recommendations, and roadmap are in **Research Synthesis** below.

---

## Technical Research Scope Confirmation

**Research Topic:** XiaoShanServe to UrbanManagement IIS dual-port cutover and data migration
**Research Goals:** Lock IIS dual-binding approach, SQLite/image migration mechanics, ID mapping, and cutover runbook so PRD/Architecture/OpenSpec can proceed; exclude GovLog and XSS GovProject per locked decisions D1–D4

**Technical Research Scope:**

- Architecture Analysis - design patterns, frameworks, system architecture
- Implementation Approaches - development methodologies, coding patterns
- Technology Stack - languages, frameworks, tools, platforms
- Integration Patterns - APIs, protocols, interoperability
- Performance Considerations - scalability, optimization, patterns

**Research Methodology:**

- Current web data with rigorous source verification
- Multi-source validation for critical technical claims
- Confidence level framework for uncertain information
- Comprehensive technical coverage with architecture-specific insights

**Scope Confirmed:** 2026-08-26

---

## Technology Stack Analysis

### Programming Languages

_Popular Languages:_ C# remains the only language on both sides of this cutover. XiaoShanServe was ASP.NET Core 6 + SqlSugar; UrbanManagement is ABP 10 / .NET 10 / EF Core. Migration tooling and IIS ops scripts can stay PowerShell + SQLite CLI (no second language required).

_Emerging Languages:_ Not applicable for this brownfield cutover; introducing Python/Node only for a one-shot ETL would add operational surface without benefit when `sqlite3` + PowerShell already cover ATTACH/INSERT and file copy.

_Language Evolution:_ Archive design (2026-05) still referenced `int`/`long` PKs for sync/weighing entities; **current UrbanManagement code uses `Guid` PKs** (`UrbanWeighingRecord : AuditedEntity<Guid>`, `GovSyncData : AuditedEntity<Guid>`, `AttachmentFile : AuditedEntity<Guid>`). Any ETL must assume Guid targets, not the archive’s int/long sketch.

_Performance Characteristics:_ Cutover is batch ETL + IIS rebinding, not a hot-path language concern. SQLite single-writer constraints matter more than C# runtime version during the stop-write window.

_Source:_ Repo entities under `repos/UrbanManagement/src/UrbanManagement.Core/Entities/`; [.NET IIS hosting (ASP.NET Core 10)](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/?view=aspnetcore-10.0)

**Confidence:** High (repo + Microsoft docs).

### Development Frameworks and Libraries

_Major Frameworks:_ UrbanManagement = ABP Application Services + EF Core SQLite + MVC controllers (`LegacyApiController` for GovClient, urban weighing APIs for MaterialClient). Background sync = `AsyncPeriodicBackgroundWorkerBase` (`GovSyncBackgroundWorker`).

_Micro-frameworks / specialized:_ Refit + Polly for government HTTP forward; `IOptions<StorageOptions>` for `FilesPhysicalPath` / `GovAddress`; LayUI admin UI (unchanged by dual-port).

_Evolution Trends:_ Functional port from XiaoShanServe → UM is already archived (`xiaoshanserve-to-urbanmanagement-abp-migration`). Remaining stack work is **deployment + data**, not new framework features.

_Ecosystem Maturity:_ ABP/EF Core/SQLite and IIS AspNetCoreModule are production-standard. No new NuGet required for dual-port (IIS bindings are host-level).

_Source:_ [ASP.NET Core Module / IIS](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/aspnet-core-module); archive `openspec/changes/archive/2026-05-29-xiaoshanserve-to-urbanmanagement-abp-migration/`

**Confidence:** High.

### Database and Storage Technologies

_Relational Databases:_ Both systems use **SQLite files**. UM connection string: `Data Source=UrbanManagement.db`. Cross-DB copy is a first-class SQLite feature via `ATTACH DATABASE` then `INSERT INTO target SELECT … FROM source` ([SQLite ATTACH](https://sqlite.org/lang_attach.html)).

_NoSQL / In-Memory / Warehousing:_ Out of scope. Images are local filesystem under `StorageOptions.FilesPhysicalPath` (`Uploads/`), with `AttachmentFile.LocalPath` storing relative paths resolved by `StoragePathResolver`.

_Cutover implications:_
1. **Schema mismatch is the hard problem** — XSS SqlSugar tables ≠ UM EF Guid/`AuditedEntity` shapes; blind `SELECT *` will fail. Prefer application-level mapper or explicit column projection into UM schema.
2. **Guid storage** — EF Core SQLite maps Guid as TEXT by default; remapping legacy int IDs → new Guids is required; keep a side map (`LegacyId → NewId`) for join repair (weighing ↔ sync ↔ files). ([EF Core SQLite type notes / Guid pitfalls](https://stackoverflow.com/questions/72016544/migrating-data-in-an-database-created-with-ef-code-first-devart-connector-to-e))
3. **GovLog** — no UM entity; do not migrate (locked D1).
4. **GovProject** — UM is SoT; do not import XSS projects (locked D2). Pre-check: every migrated row’s access code must resolve in UM `GovProject`.

_Source:_ [sqlite.org/lang_attach.html](https://sqlite.org/lang_attach.html); [Simon Willison on cross-db ATTACH](https://simonwillison.net/2021/Feb/21/cross-database-queries/); UM `appsettings.json` / entities

**Confidence:** High for ATTACH pattern; Medium for exact XSS table/column names until a live XiaoShan.db schema dump is attached to research.

### Development Tools and Platforms

_IDE and Editors:_ Visual Studio / Rider / Cursor for any one-shot migrator console if needed.

_Version Control:_ Git (MaterialMonospec OpenSpec + UrbanManagement code). Cutover scripts SHOULD live in main or UM repo under `scripts/` once OpenSpec authorizes.

_Build Systems:_ `dotnet publish` UrbanManagement for IIS folder deploy; [.NET Hosting Bundle](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/?view=aspnetcore-10.0) on Windows Server.

_Testing Frameworks:_ Existing UM unit tests; cutover needs an **ops smoke checklist** (POST /Api/Post on old port, new-port MaterialClient path, image open, sync worker pickup) more than new xUnit suites.

_Ops tools:_ IIS Manager (site bindings collection), `netstat`/`Get-NetTCPConnection` to confirm old port free before rebind, `sqlite3` CLI for ATTACH dry-runs, robocopy/xcopy for image trees.

_Source:_ [IIS `<bindings>` collection](https://github.com/MicrosoftDocs/iis-docs/blob/master/iis/configuration/system.applicationHost/sites/site/bindings/index.md)

**Confidence:** High.

### Cloud Infrastructure and Deployment

_Major Cloud Providers:_ N/A — target is **same Windows Server IIS**, two sites historically (XSS vs UM), different ports.

_Container / Serverless / CDN:_ Out of scope for this cutover.

_Deployment pattern (recommended):_
- **One IIS site = UrbanManagement**, dedicated app pool (`No Managed Code`), AspNetCoreModule in-process/out-of-process per existing UM deploy.
- **Multiple `<binding>` entries** on that site (old XSS port + current UM port). IIS docs: a site’s `<bindings>` is a collection; each binding is an alternate way to reach the **same** site ([IIS bindings](https://github.com/MicrosoftDocs/iis-docs/blob/master/iis/configuration/system.applicationHost/sites/site/bindings/index.md)).
- ASP.NET Core behind ANCM does **not** need Kestrel/Http.Sys multi-URL config for this — IIS owns the public ports and forwards to the single app. (Http.Sys multi-`UrlPrefixes` applies when self-hosting Http.Sys, not the typical IIS+ANCM path — [Http.Sys docs](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/httpsys?view=aspnetcore-10.0).)
- **Constraint:** do not put two ASP.NET Core apps in one app pool; here we keep **one** app (UM) with two bindings — allowed. ([ANCM: one app pool per app](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/aspnet-core-module))

_Source:_ Microsoft Learn IIS hosting + IIS bindings docs above.

**Confidence:** High for dual binding on one site; High that no UM code change is required for dual HTTP ports.

### Technology Adoption Trends

_Migration Patterns:_ Industry and SQLite community pattern for brownfield DB merge = stop writers → ATTACH/ETL → cut DNS/port → retire old host. Matches locked D4 (allow write stop).

_Emerging Technologies:_ URL Rewrite reverse-proxy (Option B) is common when the old site must remain a different physical path; for same-machine port takeover, dual binding (Option A) is simpler and preferred.

_Legacy Technology:_ XiaoShanServe (SqlSugar + separate site) is being phased out after functional absorption; GovClient WinForms remains unmodified and keeps posting to the **old port URL**.

_Community Trends:_ Prefer host-level port sharing over application dual-listen when already on IIS.

_Source:_ Synthesis of IIS/SQLite docs + locked product decisions D1–D4.

**Confidence:** High for recommendation; Medium for field port numbers until ops inventory lists exact bindings.

### Stack Summary for This Cutover (actionable)

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Host | IIS one site, two bindings | Zero app change; official bindings collection |
| App | UrbanManagement only after cutover | Already has Legacy + Urban APIs |
| DB ETL | Stop-write + mapped insert (not raw SELECT *) | Schema/PK drift (Guid vs legacy) |
| Files | Copy into `Uploads/` + rewrite `LocalPath` | Clean XSS directory retirement |
| Skip | GovLog, XSS GovProject | D1/D2 + no GovLog entity in UM |

---

## Integration Patterns Analysis

### API Design Patterns

_RESTful APIs:_ UrbanManagement exposes two inbound HTTP contracts on the **same process**:
1. **Legacy compatibility endpoint** — `POST /Api/Post` (`LegacyApiController`, `[Route("Api/[action]")]`) accepts unmodified GovClient camelCase JSON (`carNo`, `snapImages`, dual access codes). This is an in-process **compatibility / anti-corruption layer**, not a separate microservice. ([legacy-api-compat spec](file://openspec/specs/legacy-api-compat/spec.md); controller in repo)
2. **Urban weighing API** — MaterialClient uses modern routes under `api/urban/*` (auth, attachments, weighing receive).

_GraphQL / RPC / gRPC:_ Not used and not recommended for this cutover — clients already speak HTTP JSON.

_Webhook Patterns:_ Outbound to government platform is **server-initiated polling + POST** via `GovSyncBackgroundWorker` + Refit (`IGovSyncHttpClient`), not inbound webhooks.

_Cutover API insight:_ Because the legacy contract is already hosted inside UM, the “strangler façade” for GovClient is **host-level port ownership** (IIS binds old port to UM), not a new mediator service. Azure’s Strangler Fig pattern still applies conceptually: clients keep the same interface while the backend is replaced. ([Microsoft Strangler Fig](https://learn.microsoft.com/en-us/azure/architecture/patterns/strangler-fig))

_Source:_ [Strangler Fig](https://learn.microsoft.com/en-us/azure/architecture/patterns/strangler-fig); [API compatibility layers](https://www.nilus.be/blog/api_compatibility_layers_in_microservices/)

**Confidence:** High.

### Communication Protocols

_HTTP/HTTPS Protocols:_ All client→server and server→gov traffic is HTTP(S). Dual-port cutover assumes **HTTP port identity** is what GovClient embeds (host:oldPort). IIS site with two bindings means both ports terminate at the same ANCM app; app code does not branch on port. Binding uniqueness is IP+Port(+Host); two ports on one site are valid. ([IIS bindings uniqueness](https://learn.microsoft.com/en-us/archive/blogs/parvez/iis-bindings))

_WebSocket:_ UM has SignalR config in `appsettings.json`; irrelevant to GovClient `POST /Api/Post` path. Do not couple cutover to SignalR.

_Message Queue / gRPC:_ Not in current architecture; introducing queues for cutover would expand scope without client benefit.

_Source:_ IIS bindings blog; UM appsettings / LegacyApiController

**Confidence:** High.

### Data Formats and Standards

_JSON:_ GovClient body = camelCase JSON; response = `{ success, msg, code, data }` with `code` 200/-1 ([legacy-api-compat](file://openspec/specs/legacy-api-compat/spec.md)). Images = Base64 string arrays in `snapImages`, then decoded to files + `AttachmentFile`.

_XML / Protobuf / MessagePack:_ Not on this path.

_CSV / Flat Files:_ Applicable only to **offline ETL** of SQLite + filesystem images during the stop-write window — bulk transfer, not runtime API.

_Custom:_ Dual access-code semantics (`fdBuildLicenseNo` priority → `buildLicenseNo`) must remain identical after port cutover or GovClient will see “对接码未接入”.

_Source:_ OpenSpec legacy-api-compat; repo `LegacyApiController`

**Confidence:** High for runtime JSON; Medium for XSS historical image path layout until filesystem inventory.

### System Interoperability Approaches

_Point-to-Point:_ GovClient → (old port) → UM Legacy API; MaterialClient → (new port) → Urban APIs; UM Worker → Gov HTTP. No ESB.

_API Gateway / reverse proxy (Option B):_ Classic strangler uses YARP/nginx/IIS URL Rewrite as façade when old and new apps both still run. ([Strangler + YARP discussions](https://dev.to/blackthorn_vision_co/strangler-fig-pattern-for-net-modernization-how-it-works-in-a-real-production-system-i76)). **For this project, Option A (same site, two bindings) is preferred** because:
- Legacy API already lives in UM (no path rewrite needed)
- Goal is to **stop** XSS, not run dual backends long-term
- Fewer moving parts than keeping a proxy in front of two sites

Use Option B only if ops cannot rebind the old port onto the UM site (policy, certificate, or third-party site lock).

_Service Mesh / ESB:_ Out of scope for single Windows IIS box.

_Source:_ [Strangler Fig](https://learn.microsoft.com/en-us/azure/architecture/patterns/strangler-fig); prior stack recommendation Option A

**Confidence:** High for A vs B decision.

### Microservices Integration Patterns

_API Gateway Pattern:_ Effectively **IIS bindings = thin L7 accept**, app = business gateway. Not a separate gateway product.

_Service Discovery:_ Static URLs in GovClient and MaterialClient config — unchanged for GovClient (port stays).

_Circuit Breaker / Retry:_ Outbound gov calls already planned with Polly on Refit; modern guidance prefers `Microsoft.Extensions.Http.Resilience` pipelines (retry + breaker + timeout). ([HTTP resilience](https://learn.microsoft.com/en-us/dotnet/core/resilience/http-resilience)). Cutover does not require changing this unless Worker fails post-merge; treat as optional hardening, not a cutover blocker.

_Saga:_ Not needed — cutover is a **single-box stop-write + ETL + rebind**, not a distributed transaction across services.

**Confidence:** High.

### Event-Driven Integration

_Publish-Subscribe / Event Sourcing / CQRS / Brokers:_ Not part of XiaoShanServe or UM weighing ingest. Runtime path is synchronous POST → persist → background poll → forward.

_Implication:_ During cutover, do **not** introduce event buses. Ensure `GovSyncBackgroundWorker` / polling flag is correctly enabled in production `appsettings` after merge so pending `GovSyncData` / weighing sync states continue to flush.

**Confidence:** High that event-driven is out of scope.

### Integration Security Patterns

_OAuth 2.0 / JWT:_ Used on Urban auth paths (`api/urban/auth`); **not** on legacy `POST /Api/Post` (access-code fields in body). Cutover must not accidentally place JWT middleware that blocks LegacyApiController.

_API Key:_ BasePlatform pull uses `PublicApiServiceAuth` / ApiKey — orthogonal to GovClient ingest.

_mTLS / Encryption:_ Depends on existing IIS HTTPS bindings; if old XSS port was plain HTTP, keep the same scheme when rebinding so GovClient TLS settings stay valid.

_Data:_ Base64 images in transit already; at rest under `Uploads/`. Migration copies files with ACL continuity for the UM app-pool identity.

_Source:_ Repo controllers + UrbanAuth settings; security pattern catalogs (OAuth/JWT as general reference via Microsoft Learn resilience/auth docs)

**Confidence:** Medium-High (exact IIS HTTP vs HTTPS on old port needs ops inventory).

### Cutover Integration Sequence (recommended)

```text
GovClient ──POST /Api/Post──► [IIS :OldPort] ──┐
                                                ├──► UrbanManagement (LegacyApi + Urban APIs)
MaterialClient ──api/urban/*──► [IIS :NewPort] ─┘
                                                │
                                                ▼
                                         SQLite + Uploads/
                                                │
                                    GovSyncBackgroundWorker
                                                │
                                                ▼
                                         Government HTTP API
```

1. Pre-check: UM `GovProject` resolves all access codes present in XSS rows to migrate.  
2. Stop XSS write / stop XSS site (free OldPort).  
3. ETL weighing + `GovSyncData` + images; remap IDs to Guid.  
4. Add OldPort binding to UM site; smoke `POST /Api/Post`.  
5. Keep NewPort for MaterialClient.  
6. Decommission XSS package after soak; retain backup for rollback.

_Source:_ Synthesis of Strangler Fig + IIS dual-binding + locked D1–D4

**Confidence:** High for sequence; Medium until live port numbers and XSS schema confirmed.

---

## Architectural Patterns and Design

### System Architecture Patterns

_Target steady state:_ Keep UrbanManagement as a **modular monolith** (single IIS deployable: Legacy API + Urban APIs + Worker + admin UI). Do **not** split weighing ingest into a new microservice for cutover — operational cost exceeds benefit on one Windows box. ([Modular monolith vs microservices](https://milanjovanovic.tech/blog/modular-monolith-vs-microservices))

_Migration pattern:_ Hybrid of **Strangler Fig** (clients keep URLs/ports) and **controlled Big Bang data cutover** (stop-write window for ETL). Functional strangling of XSS APIs is largely complete in-process (`LegacyApiController`); remaining work is **port ownership + historical data**. ([Strangler Fig](https://learn.microsoft.com/en-us/azure/architecture/patterns/strangler-fig); [Big Bang vs Strangler risk](https://ctoaccelerator.com/resources/decision-frameworks/strangler-fig-vs-big-bang-migration))

_Rejected:_ Full blue-green duplicate stacks on this server (2× IIS apps + 2× SQLite writers) — unnecessary when downtime is allowed (D4) and dual writers invite split-brain. ([Blue-green vs recreate trade-offs](https://www.cloudzero.com/blog/deployment-strategies/))

_Source:_ links above + prior integration Option A

**Confidence:** High.

### Design Principles and Best Practices

_Anti-Corruption Layer (ACL):_ `LegacyApiController` + `LegacyGovSyncAppService` translate GovClient DTOs → UM entities (`UrbanWeighingRecord` / `GovSyncData` / `AttachmentFile`). Preserve this boundary during ETL: map XSS rows through the same semantic rules (access-code priority, grossWeight override, images out of SourceData). ([Microsoft ACL pattern](https://github.com/microsoftdocs/architecture-center/blob/main/docs/patterns/anti-corruption-layer.md))

_Single source of truth:_ UM `GovProject` only (D2). Migrated rows reference UM project identity via access-code resolution or explicit ProId remapping — never revive XSS project tables as authoritative.

_Separation of concerns:_ Host concerns (IIS bindings) stay out of application code; application concerns (contracts, persistence) stay out of IIS rewrite rules when Option A works.

_Source:_ ACL docs; locked D1–D4

**Confidence:** High.

### Scalability and Performance Patterns

_Horizontal scaling:_ Out of scope for single-site industrial relay. SQLite remains **single-writer**; dual-process writers (XSS + UM) must not run against merged data. ([SQLite WAL / single writer](https://www.sqlite.org/draft/wal.html); [single-writer discussion](https://www.bugsink.com/blog/database-transactions/))

_Vertical / ops:_ Stop-write window length dominated by row count + image copy I/O, not CPU. Throttle image robocopy; run ETL local to the server disk.

_Caching / load balancing:_ Not required for cutover architecture.

**Confidence:** High.

### Integration and Communication Patterns

_Inbound:_ Port-based fan-in to one process (OldPort + NewPort → UM). Path-based dual API already exists.

_Outbound:_ Background worker → government HTTP (retry/resilience). Post-cutover, ensure pending sync states from migrated `GovSyncData` / weighing records are eligible for Worker pickup (or explicitly marked historical/synced to avoid mass re-push — **decision for implementation step**).

_No shared DB between XSS and UM after cutover:_ XSS is offline; UM owns `UrbanManagement.db` + `Uploads/`.

_Source:_ Integration analysis Step 3; SQLite concurrency constraints

**Confidence:** High; Medium on “re-sync vs mark synced” policy (needs product call in implementation research).

### Security Architecture Patterns

_Trust boundary:_ Legacy path remains access-code validated, not JWT. Architecture must keep Legacy routes outside Urban JWT gates.

_Least privilege:_ UM app-pool identity needs NTFS rights on `Uploads/` and SQLite files after image copy.

_Rollback security:_ Retained XSS backup offline (not bound to OldPort) so rollback cannot accidentally dual-serve.

**Confidence:** Medium-High.

### Data Architecture Patterns

_Canonical store:_ UM EF Core SQLite schema (Guid PKs, audited entities, attachment join table).

_ETL architecture:_ Offline batch transform (XSS schema → ACL-equivalent mapping → UM insert) inside maintenance window. Prefer **new Guids + LegacyId map table/file** over forcing legacy int IDs into Guid columns.

_File store:_ Content-addressed by relative `LocalPath` under `FilesPhysicalPath`; copy tree then rewrite paths. Do not leave production depending on XSS folders long-term.

_Consistency:_ Stop writers before final snapshot/copy; file copy of `.db` alone is insufficient if WAL exists — checkpoint or use backup API / stop app for cold copy. ([SQLite WAL](https://www.sqlite.org/draft/wal.html); backup practices)

_Excluded:_ GovLog (no sink); XSS GovProject (D2).

**Confidence:** High for pattern; Medium until XSS table inventory.

### Deployment and Operations Architecture

```text
Before:  [IIS XSS:OldPort]  [IIS UM:NewPort]
After:   [IIS UM:OldPort + NewPort]   XSS stopped (backup retained)
```

_Cutover style:_ **Maintenance-window Big Bang** for data + port rebind (allowed by D4), after functional strangler already completed in code. Fits “acceptable downtime + clean data migration path” criteria often cited for Big Bang. ([Cutover strategies](https://www.aurascience.blog/what-is-cutover-in-software-engineering); [Strangler vs Big Bang](https://ctoaccelerator.com/resources/decision-frameworks/strangler-fig-vs-big-bang-migration))

_Rollback:_ Restore UM DB/Uploads from pre-cutover backup; re-start XSS site on OldPort; remove OldPort from UM bindings. Document RTO expectation.

_Observability:_ Smoke POST on both ports; log Legacy successes; confirm Worker; sample image URLs.

_ADR candidates for OpenSpec/Architecture:_
1. Dual IIS binding (A) over reverse proxy (B)
2. Offline ETL with Guid remapping
3. Image copy + path rewrite
4. Skip GovLog / XSS GovProject
5. Sync-status policy for migrated historical rows

**Confidence:** High.

---

## Implementation Approaches and Technology Adoption

### Technology Adoption Strategies

_Approach:_ **Ops-first cutover**, not a feature rewrite. Functional XSS capabilities already live in UM; adopt by (1) one-shot ETL tool, (2) IIS binding change, (3) decommission XSS. Fits maintenance-window Big Bang with pre-tested scripts. ([Data migration runbook](https://stackpractices.com/docs/data-migration-runbook-template/); [DB migration checklist](https://onclickinnovations.com/blog/database-migration-checklist-production/))

_Gradual vs bang:_ Code path already gradual (strangled into UM). Remaining port + history = bang inside an approved window (D4).

_Vendor selection:_ Prefer built-in stack — PowerShell `New-WebBinding` / `New-IISSiteBinding`, `sqlite3` or a small `dotnet` console migrator, robocopy — over new ETL products. ([New-WebBinding](https://learn.microsoft.com/en-us/powershell/module/webadministration/new-webbinding?view=windowsserver2025-ps); [New-IISSiteBinding](https://learn.microsoft.com/en-us/powershell/module/iisadministration/new-iissitebinding?view=windowsserver2022-ps))

**Confidence:** High.

### Development Workflows and Tooling

| Artifact | Suggested home | Notes |
|----------|----------------|-------|
| Schema probe script | `scripts/xiaoshan-cutover/` (main or UM) | Dump XSS table/column list |
| ETL migrator | Small `dotnet` tool or PowerShell+sqlite | Map → Guid; write LegacyId map CSV |
| IIS bind script | `Add-UmOldPortBinding.ps1` | `New-WebBinding -Name <UM> -Protocol http -Port <OldPort>` |
| Smoke script | `Invoke-CutoverSmoke.ps1` | POST `/Api/Post` on both ports |
| OpenSpec change | Main repo after PRD | e.g. `add-xiaoshanserve-iis-cutover` |

_Workflow:_ Dry-run on **production clone** (copy of XiaoShan.db + UM.db + sample images) → time the window → only then schedule live cutover. ([Runbook: dry run gate](https://stackpractices.com/docs/data-migration-runbook-template/))

**Confidence:** High.

### Testing and Quality Assurance

_Pre-cutover:_
- Access-code coverage: every distinct code in XSS migrate set resolves in UM `GovProject` (fail ETL if not).
- Row-count reconciliation: source count vs inserted count; orphan image count.
- Idempotency: re-run migrator against clone must not duplicate (use LegacyId unique index or skip-if-exists).

_Smoke (critical path, &lt; few minutes):_ ([Post-deploy / smoke practices](https://stackpractices.com/docs/post-deployment-checklist-template/))
1. `POST http://server:OldPort/Api/Post` with known good access code → `code: 200`.
2. Same on NewPort (optional; proves dual bind).
3. Open one migrated image via UM storage path.
4. Admin list shows migrated weighing / sync rows.
5. Confirm Worker behavior matches sync policy (below).

_Do not_ use production customer plates for write smokes if avoidable — use a dedicated test project/access code.

**Confidence:** High.

### Deployment and Operations Practices

_Recommended cutover runbook (ordered):_

| Phase | Action | Verify |
|-------|--------|--------|
| T-7d | Inventory ports, XSS DB path, image root, UM site name | Written inventory |
| T-3d | Clone dry-run ETL + timed rollback | Duration &lt; window budget |
| T-0 backup | Cold/consistent copy XSS DB+images + UM DB+Uploads | Restore test on spare folder |
| T-0 stop | Stop XSS site / app pool; confirm OldPort free | `Get-NetTCPConnection` |
| T-0 ETL | Run migrator; copy images; rewrite paths | Counts + sample joins |
| T-0 bind | `New-WebBinding` OldPort → UM site | `Get-WebBinding` |
| T-0 smoke | Legacy POST + image + admin list | Pass/fail gate |
| T+soak | Monitor logs; keep XSS package offline | No dual bind |
| Close | Archive XSS; retain backups ≥30d | Documented |

_Rollback triggers (examples):_ Legacy POST fails after bind; row-count delta &gt; agreed threshold; images unreadable; window overrun. Rollback = remove OldPort from UM, restore UM backup if polluted, restart XSS on OldPort. ([Rollback criteria](https://oneuptime.com/blog/post/2026-02-12-create-an-aws-migration-runbook/view))

**Default sync-status policy (recommended):**
- XSS rows already successfully synced to government → migrate with **`SyncType = 1`** (done) so Worker does **not** re-push.
- XSS rows still pending/failed → migrate with **`SyncType = 0`** (and sane `RetryCount`) so Worker can continue.
- Rationale: `LegacyGovSyncAppService` creates new rows at `SyncType = 0`; blind import of historical synced rows as `0` would spam the gov API.

**Confidence:** High for runbook; High for sync-status default (product-confirmable).

### Team Organization and Skills

| Role | Skills |
|------|--------|
| Ops / IIS | Bindings, app pools, port conflict, NTFS for app-pool identity |
| Backend | UM entities, ACL field mapping, Guid remapping |
| Domain QA | Access codes, GovClient sample payload, gov sync expectations |
| Decision owner | Named person for go/rollback during window |

No cloud/K8s skills required for this cutover.

**Confidence:** High.

### Cost Optimization and Resource Management

- Prefer **scripts + short window** over prolonged dual-run (double support cost).
- Skip buying ETL platforms; data volume is site-local SQLite + images.
- Keep backups on the same server only short-term; copy off-box if disk risk.
- Effort class (for later OpenSpec `.openspec.yaml` only): roughly **M** if schema mapping is straightforward, **L** if XSS schema diverges heavily or images are huge — finalize after schema probe.

**Confidence:** Medium on effort until schema probe.

### Risk Assessment and Mitigation

| Risk | Mitigation |
|------|------------|
| Access code missing in UM | Pre-check gate; fix projects before window |
| Duplicate gov submissions | SyncType policy above |
| Port still held by XSS | Stop site before bind; verify listen |
| WAL/inconsistent DB copy | Stop app then copy, or backup API |
| Path/ACL on images | Copy under `Uploads/`; grant app-pool rights |
| JWT middleware blocks Legacy | Smoke `/Api/Post` explicitly |
| Partial ETL | Transactional batches + LegacyId map; do not bind OldPort until verify |

_Source:_ Runbook/checklist sources above + repo Worker/`SyncType` behavior

**Confidence:** High.

## Technical Research Recommendations

### Implementation Roadmap

1. **Schema probe** — export XSS weighing/sync/image table DDL + sample rows.  
2. **Write migrator + dry-run** on clones; lock field map + SyncType policy.  
3. **IIS + smoke scripts** — bind/unbind OldPort; POST smoke.  
4. **PRD / Architecture / OpenSpec** — encode D1–D4 + runbook acceptance.  
5. **Live window** — execute runbook; soak; decommission XSS.  

### Technology Stack Recommendations

- Host: IIS dual binding (Option A)  
- ETL: `dotnet` console or PowerShell + sqlite3  
- Files: robocopy → `StorageOptions.FilesPhysicalPath`  
- Verify: PowerShell/`curl` smoke + admin UI spot-check  
- No YARP unless Option A blocked  

### Skill Development Requirements

- Brief ops on `New-WebBinding` / port release  
- Brief backend on Guid remap + attachment path rewrite  
- Tabletop walkthrough of rollback once  

### Success Metrics and KPIs

| Metric | Target |
|--------|--------|
| GovClient OldPort POST success | `code: 200` in smoke |
| Migrated weighing / GovSyncData counts | 100% of in-scope source rows (minus explicit skips) |
| Image open rate (sample) | 100% of sampled migrated attachments |
| Gov re-push of already-synced history | 0 unintended |
| XSS process listening on OldPort | 0 after cutover |
| Rollback drill | Documented time &lt; agreed threshold |

---

# XiaoShanServe → UrbanManagement Cutover: Comprehensive Technical Research Synthesis

## Executive Summary

UrbanManagement already hosts the XiaoShanServe business surface (`POST /Api/Post`, attachment storage, gov sync worker). What remains is an **IIS + data cutover**: stop XSS writes, migrate weighing / `GovSyncData` / images into UM, bind the **old GovClient port** onto the UM site beside the existing UM port, smoke-test, then retire XSS. This matches industry guidance that consolidating legacy IIS workloads fails when bindings, external files, and rollback triggers are underspecified — not when the app code is “mostly ready.” ([IIS migration pre-flight](https://win-architecture-solutions.hashnode.dev/iis-website-migration-guide); [legacy cutover ownership](https://saigontechnology.com/blog/legacy-application-migration/))

**Key Technical Findings:**

- Dual HTTP bindings on one IIS site are first-class; ANCM forwards both to one ASP.NET Core app — no Kestrel multi-listen change required.
- Schema drift (XSS SqlSugar vs UM EF Guid/`AuditedEntity`) forbids blind `SELECT *`; ETL must remap IDs and fields through ACL semantics.
- SQLite single-writer forbids running XSS and UM writers against one logical dataset; stop-write (D4) is the correct consistency model.
- In-process Legacy API means Strangler façade = **port ownership**, not a long-lived reverse proxy (Option A > B).

**Technical Recommendations:**

1. Adopt Option A (same UM site, OldPort + NewPort bindings).  
2. Ship schema probe → dry-run migrator → IIS/smoke scripts before live window.  
3. Migrate only weighing + `GovSyncData` + images; skip GovLog / XSS GovProject.  
4. Default SyncType: historical success → `1`, pending/fail → `0`.  
5. Gate go-live on OldPort `POST /Api/Post` smoke + count/image checks; named rollback owner.

## Table of Contents

1. Technical Research Introduction and Methodology  
2. Technical Landscape and Architecture Analysis  
3. Implementation Approaches and Best Practices  
4. Technology Stack Evolution and Current Trends  
5. Integration and Interoperability Patterns  
6. Performance and Scalability Analysis  
7. Security and Compliance Considerations  
8. Strategic Technical Recommendations  
9. Implementation Roadmap and Risk Assessment  
10. Future Technical Outlook  
11. Methodology and Source Verification  
12. Appendices (Decision Lock + Runbook Sketch)

## 1. Technical Research Introduction and Methodology

### Technical Research Significance

Industrial GovClient fleets often cannot be mass-updated. Retiring XiaoShanServe without preserving the **old port URL** would strand field machines. Research significance is therefore **compatibility-preserving consolidation** on a single IIS box — a classic “move + cutover” problem where external files (snap images) and DB semantics matter as much as site config. ([IIS migration checklist themes](https://win-architecture-solutions.hashnode.dev/iis-website-migration-guide); [Windows cutover checklist](https://rafftechnologies.com/windows-server/windows-server-migration-checklist-small-business))

_Business Impact:_ One backend to operate; GovClient unchanged; MaterialClient keeps NewPort; historical weighing/sync/images remain queryable in UM.

### Technical Research Methodology

- **Scope:** Stack, integration, architecture, implementation/runbook for dual-port cutover + selective ETL.  
- **Sources:** Microsoft Learn (IIS, ANCM, Http.Sys), SQLite ATTACH/WAL, Azure Strangler Fig & ACL, migration runbook practice, UM repo + archived OpenSpec.  
- **Framework:** Pattern fit → locked product decisions D1–D4 → actionable runbook.  
- **Depth:** Decision-grade for PRD/Architecture/OpenSpec; medium confidence where live XSS schema/ports not yet inventoried.

### Goals Achievement

| Goal | Status |
|------|--------|
| Lock IIS dual-binding | **Achieved** — Option A recommended with citations |
| SQLite/image migration mechanics | **Achieved** — remap Guid, copy+rewrite paths, ATTACH unsuitable for blind copy |
| ID mapping | **Achieved** — new Guid + LegacyId map |
| Cutover runbook | **Achieved** — phased table + rollback triggers |
| Exclude GovLog / XSS GovProject | **Achieved** — D1/D2 + code confirms no GovLog entity |

## 2. Technical Landscape and Architecture Analysis

_Dominant pattern:_ Modular monolith UM + maintenance-window data bang + host-level strangler (port).  
_Trade-offs:_ Accept short downtime (D4) to avoid dual-writer SQLite and dual-app complexity; reject blue-green 2× stacks on one industrial server.  
_Design principles:_ ACL at Legacy boundary; UM `GovProject` SoT; host concerns in IIS, not app.  
_Sources:_ Steps 3–4; [Strangler Fig](https://learn.microsoft.com/en-us/azure/architecture/patterns/strangler-fig); [ACL](https://github.com/microsoftdocs/architecture-center/blob/main/docs/patterns/anti-corruption-layer.md); [modular monolith](https://milanjovanovic.tech/blog/modular-monolith-vs-microservices)

## 3. Implementation Approaches and Best Practices

Dry-run on production clones; verified backup; stop writes; ETL; bind OldPort; smoke; soak; decommission. Tooling: PowerShell `New-WebBinding`/`New-IISSiteBinding`, `dotnet`/sqlite migrator, robocopy, curl smoke. ([Runbooks](https://stackpractices.com/docs/data-migration-runbook-template/); [New-WebBinding](https://learn.microsoft.com/en-us/powershell/module/webadministration/new-webbinding?view=windowsserver2025-ps))

## 4. Technology Stack Evolution and Current Trends

C# / ABP / EF Core SQLite / local `Uploads/` remain. Archive May-2026 int/long PK sketch is obsolete — **current UM uses Guid** for weighing/sync/attachments. No new cloud/container stack for this cutover.

## 5. Integration and Interoperability Patterns

```text
GovClient → :OldPort → UM LegacyApi (/Api/Post)
MaterialClient → :NewPort → UM api/urban/*
UM Worker → Government HTTP
```

Compatibility layer already in UM; IIS multi-binding is the remaining interoperability seam. ([IIS bindings](https://github.com/MicrosoftDocs/iis-docs/blob/master/iis/configuration/system.applicationHost/sites/site/bindings/index.md))

## 6. Performance and Scalability Analysis

Window duration ≈ DB transform + image I/O. SQLite single-writer + stop-write is the scalability/consistency control — not horizontal scale-out. ([SQLite WAL](https://www.sqlite.org/draft/wal.html))

## 7. Security and Compliance Considerations

Keep Legacy access-code path free of Urban JWT gates; match OldPort HTTP/HTTPS to GovClient expectations; app-pool NTFS on `Uploads/` and DB; keep XSS backup offline (not listening) for rollback. Soft compliance: retain pre-cutover backups ≥30 days.

## 8. Strategic Technical Recommendations

| # | Recommendation | Priority |
|---|----------------|----------|
| R1 | IIS Option A dual binding | P0 |
| R2 | Offline ETL with Guid + LegacyId; image copy+rewrite | P0 |
| R3 | SyncType policy (synced→1, else→0) | P0 |
| R4 | Access-code pre-check gate | P0 |
| R5 | YARP/rewrite only if A blocked | P2 |
| R6 | Separate Epic from urban-v2-four-machine-code | P0 (planning) |

## 9. Implementation Roadmap and Risk Assessment

**Phases:** (1) Schema probe (2) Migrator dry-run (3) IIS+smoke scripts (4) PRD/OpenSpec (5) Live window (6) Soak + XSS decommission  

**Top risks:** missing GovProject codes; gov re-push; port still held; broken image paths; WAL inconsistent copy — mitigations in Step 5 risk table.

## 10. Future Technical Outlook

Near-term: retire XSS package; optional later hardening to `Microsoft.Extensions.Http.Resilience` on gov client. Medium-term: only if GovClient fleet can be reconfigured, drop OldPort binding. Do not invent event buses for this domain.

## 11. Technical Research Methodology and Source Verification

Primary: Microsoft Learn IIS/ANCM/Http.Sys/Resilience; sqlite.org ATTACH/WAL; Azure Strangler Fig & ACL; PowerShell WebAdministration/IISAdministration; UM entities/`LegacyApiController`/`GovSyncBackgroundWorker`; archived `xiaoshanserve-to-urbanmanagement-abp-migration`.  

**Limitations:** Live XiaoShan.db DDL and exact production port numbers not inspected — Medium confidence on field maps and window duration until probe.

## 12. Technical Appendices

### A. Locked Decisions (D1–D4)

| ID | Decision |
|----|----------|
| D1 | No GovLog migration (no UM sink) |
| D2 | No XSS GovProject import; UM SoT |
| D3 | Recommend IIS same-site dual binding |
| D4 | Write-stop window allowed |

### B. Steady-State Diagram

```text
Before: XSS:OldPort | UM:NewPort
After:  UM:OldPort+NewPort | XSS stopped (backup retained)
```

### C. Open Items for PRD

1. Exact OldPort / NewPort / site names (ops inventory)  
2. XSS table/column map after schema probe  
3. Confirm SyncType default policy with domain owner  
4. Effort token estimate in OpenSpec `.openspec.yaml` only (M/L after probe)

---

## Technical Research Conclusion

**Finding:** Cutover is an **operations + ETL** problem on a completed functional strangler.  
**Impact:** Enables safe XSS shutdown without GovClient changes.  
**Next steps:** Schema probe → dry-run → `bmad-prd` (or OpenSpec propose) for `add-xiaoshanserve-iis-cutover` (name TBD) — separate from urban-v2 four-machine-code.

**Technical Research Completion Date:** 2026-08-26  
**Source Verification:** Claims cited to current public docs + repo evidence  
**Technical Confidence Level:** High on host/architecture defaults; Medium on XSS schema specifics pending probe

_This document is the decision reference for PRD / Architecture / OpenSpec on the XiaoShanServe IIS dual-port cutover._
