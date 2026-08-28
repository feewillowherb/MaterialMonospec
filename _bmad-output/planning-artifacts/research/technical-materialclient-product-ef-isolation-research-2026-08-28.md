---
stepsCompleted: [1, 2, 3]
inputDocuments: []
workflowType: 'research'
lastStep: 4
research_type: 'technical'
research_topic: 'MaterialClient per-product EF Core and entity-table isolation'
research_goals: >-
  Compare architecture options to keep a shared kernel schema as the baseline
  (current MaterialClient.Common tables: WeighingRecord, Waybill, attachments,
  settings kernel JSON columns, auth, etc.) while each business client (Urban,
  Recycle, and future products) independently extends that baseline with its own
  tables/mappings, without polluting Common. Later requirement splits must treat
  today's kernel table structure as the freeze line: new client capabilities add
  extension tables (or product DbContext configuration), not columns on kernel
  entities. SettingsEntity.UrbanSettingsJson is OUT of the baseline — it is
  product-owned settings persistence and must move with Urban (or a generic
  product-settings table), not remain a required kernel column. Recommend a path
  that fits ABP + SQLite, existing UrbanWeighingExtension /
  RecycleWaybillExtension, multi-client evolution, and OpenSpec follow-up.
user_name: '77162'
date: '2026-08-28'
web_research_enabled: true
source_verification: true
---

# Research Report: technical

**Date:** 2026-08-28
**Author:** 77162
**Research Type:** technical

---

## Research Overview

Brownfield technical research for MaterialClient (Avalonia desktop, ABP + EF Core + SQLite). Goal is a **shared kernel schema freeze** plus **per-business-client independent expansion**, so later product splits reuse today's kernel tables instead of forking WeighingRecord/Waybill.

Methodology: public EF Core / ABP / SQLite docs and current practitioner write-ups, cross-checked against the existing single `MaterialClientDbContext` in Common.

---

## Technical Research Scope Confirmation

**Research Topic:** MaterialClient per-product EF Core and entity-table isolation
**Research Goals:** Kernel tables as freeze-line baseline; Urban/Recycle/future clients extend independently; `SettingsEntity.UrbanSettingsJson` excluded from baseline.

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

**Scope Confirmed:** 2026-08-28

**Baseline exclusions (user):** `SettingsEntity.UrbanSettingsJson` is not a kernel column. Product settings belong to the product module (dedicated table, JSON blob on a product settings entity, or product DbContext). Kernel `SettingsEntity` may keep scale/camera/system JSON only.

---

<!-- Content will be appended sequentially through research workflow steps -->

## Technology Stack Analysis

### Programming Languages

MaterialClient is locked to **C# 13 / .NET 10**. Isolation work stays in this language; there is no stack migration. EF Core model configuration (`IEntityTypeConfiguration<T>`, `ModelBuilder` extensions) is the native extension point for “kernel + N product assemblies”.

_Popular Languages: C# for this repo; EF Core configuration APIs are first-class in C#._
_Emerging Languages: N/A for this change._
_Language Evolution: Keep file-scoped namespaces, records (no tuples), as in MaterialClient AGENTS.md._
_Performance Characteristics: Language choice is not the bottleneck; SQLite file locking and extra DbContext instances are._
_Source: [ABP EF Core integration best practices](https://abp.io/docs/latest/framework/architecture/best-practices/entity-framework-core-integration)_

### Development Frameworks and Libraries

**EF Core 10 (aligned with .NET 10 hosts)** is the persistence framework. Practitioner guidance for EF Core 10: multiple `DbContext` types are justified for **bounded contexts / modular monolith**, not one context per aggregate. Each context needs `DbContextOptions<TContext>` (generic), `--context` on `dotnet ef`, separate `--output-dir`, and a **distinct migrations history table** when sharing one database. Cross-context LINQ joins are not supported.

**ABP** official EF practice: **one DbContext interface + class per module**; map via `ModelBuilder` extension `Configure{ModuleName}` rather than a giant `OnModelCreating`; register with `AddAbpDbContext`. Runtime merge uses **`[ReplaceDbContext(typeof(IXxxDbContext))]`** so modules keep their own context types in development but the host uses **one physical schema, one migration path, one transaction**. That maps to “kernel interface + product module interface, host Urban/Recycle DbContext replaces both”.

Existing code already matches the **extension-table** style (`UrbanWeighingExtension`, `RecycleWaybillExtension`, logical id, no FK). Stack research supports keeping that mapping style while moving types out of Common.

_Major Frameworks: EF Core, ABP `AbpDbContext`, Avalonia (UI, out of EF scope)._
_Micro-frameworks: `IEntityTypeConfiguration<T>` + `ApplyConfigurationsFromAssembly` with a namespace/filter (required if two contexts live in one assembly)._
_Evolution Trends: Modular monolith + ReplaceDbContext is ABP’s documented default for combining modules._
_Ecosystem Maturity: High for EF/ABP; SQLite schema namespaces are weak (see Database)._
_Source: [Multiple DbContext in EF Core 10](https://codewithmukesh.com/blog/multiple-dbcontext-efcore/); [Milan Jovanović – multiple DbContexts](https://milanjovanovic.tech/blog/using-multiple-ef-core-dbcontext-in-single-application); [ABP ReplaceDbContext](https://github.com/abpframework/abp/blob/rel-8.3/docs/en/framework/data/entity-framework-core/index.md); [ABP module EF best practices](https://abp.io/docs/latest/framework/architecture/best-practices/entity-framework-core-integration)_

### Database and Storage Technologies

**Relational:** Single **SQLite** file (`MaterialClient.db`) is the production store. SQLite has **no user schemas** comparable to PostgreSQL `sales` / `billing`. `HasDefaultSchema` / schema-qualified `__EFMigrationsHistory` (SQL Server/Npgsql examples) **do not isolate tables** on SQLite; history collision must be solved with **different history table names** (e.g. `__EFMigrationsHistory_Kernel` vs `__EFMigrationsHistory_Urban`), not schemas.

**ExcludeFromMigrations:** Microsoft documents mapping the same table in multiple contexts and calling `ToTable(..., t => t.ExcludeFromMigrations())` so only the owning context migrates it. Useful if a product context must *read* kernel `WeighingRecord` but must not own kernel DDL.

**Ignore vs ExcludeFromMigrations:** `modelBuilder.Ignore<T>()` removes the type from that model entirely (cannot query). Hosts that should not see Recycle tables should **not include** those configurations, not Ignore after scanning the whole assembly.

**Split files:** SQLite `ATTACH` can add a second file. Cross-file COMMIT is **not atomic under WAL** (typical EF/SQLite default). Microsoft.Data.Sqlite / EF Core **do not first-class map catalogs**; attached tables need raw SQL / `FromSql`. Confidence: **high** that split-file (option D) is a poor default for this desktop app.

**NoSQL / warehouse / Redis:** Not in play for local weighing records.

_Relational Databases: SQLite file; kernel + product tables can coexist in one file._
_NoSQL Databases: Not applicable._
_In-Memory Databases: Design-time factory already uses `:memory:`; not a product isolation strategy._
_Data Warehousing: Not applicable._
_Source: [EF Core migrations history table](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/history-table); [EF Core entity types – ExcludeFromMigrations](https://learn.microsoft.com/en-us/ef/core/modeling/entity-types); [SQLite ATTACH](https://www2.sqlite.org/lang_attach.html); [efcore#6770 attach](https://github.com/dotnet/efcore/issues/6770); [efcore#30279 catalogs](https://github.com/dotnet/efcore/issues/30279)_

### Development Tools and Platforms

**CLI:** `dotnet ef migrations add --context <T> --output-dir ...` is mandatory once more than one context exists. Current design-time factory is `MaterialClientDbContextFactory` on in-memory SQLite — product contexts need their own factories or a host-based factory.

**IDE:** Cursor / Visual Studio; no change.

**VCS:** Kernel migrations stay reviewable in Common; product migrations should live in Urban/Recycle projects so requirement splits do not touch kernel history.

**Testing:** Isolation is proven by compiling Urban without Recycle entity types in the model, and Recycle without Urban; plus a migration test that kernel snapshot does not include `UrbanWeighingExtension` / `UrbanSettings`.

_IDE and Editors: Unchanged._
_Version Control: Git; split migration folders reduce Common churn._
_Build Systems: `dotnet build` with MaterialClient `.build-verify` convention._
_Testing Frameworks: Existing test projects; add model-assert tests (entity types in/out of model)._
_Source: [EF Core migrations with multiple providers / context types](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/providers); [Organising migrations with multiple DbContexts](https://blackflow.co.uk/custom-software-development/organising-ef-core-migrations-with-multiple-dbcontexts/)_

### Cloud Infrastructure and Deployment

Not a cloud persistence problem. Clients are **Windows desktop installers**; the database is a local file. Deployment implication: **one installer per product** already matches “host DbContext includes kernel + that product’s extensions only”. Do not introduce Azure SQL / containers for this research.

_Major Cloud Providers: Out of scope._
_Container Technologies: Out of scope._
_Serverless Platforms: Out of scope._
_CDN and Edge Computing: Out of scope._
_Source: Project constraint (MaterialClient AGENTS.md / urban epic project-context) — desktop, local SQLite._

### Technology Adoption Trends

Industry trend for modular monoliths: **one DbContext per bounded context**, merge at host with ABP `ReplaceDbContext` **or** keep one context and compose `ConfigureUrban()` / `ConfigureRecycle()` from the loaded module only.

Industry caution (multiple independent sources): **do not split too early** (context per aggregate). MaterialClient already has a natural split: **kernel weighing** vs **product extensions**. That is the right grain.

SQLite-specific trend: teams on SQL Server copy schema-per-module; **that pattern must be adapted** (history table names, not schemas).

`UrbanSettingsJson` on shared `SettingsEntity` is a **column-on-kernel** anti-pattern relative to the freeze-line goal; moving it off baseline matches “product settings as product-owned storage”.

_Migration Patterns: Common → module `ConfigureX` + host replace, or dual context + dual history tables on one SQLite file._
_Emerging Technologies: Unchanged stack._
_Legacy Technology: Monolithic `OnModelCreating` in `MaterialClientDbContext` should be phased toward module extensions._
_Community Trends: ABP still documents ReplaceDbContext as the way to keep one transaction across modules._
_Source: [codewithmukesh EF Core 10 multiple context](https://codewithmukesh.com/blog/multiple-dbcontext-efcore/); [ABP migrations / ReplaceDbContext](https://github.com/abpframework/abp/blob/rel-10.2/docs/en/framework/data/entity-framework-core/migrations.md)_

### Stack implications for the four architecture options (preview)

| Option | Stack fit (this step) | Confidence |
|--------|------------------------|------------|
| A – One kernel DbContext + product `IEntityTypeConfiguration` applied by loaded module | Best SQLite fit; one history table; matches “don’t split too early”; new client = new assembly + `ConfigureNewProduct()` | High |
| B – Kernel context + product context, same file | Supported by EF 10 docs; need extra history table name; no LINQ join (already no FK); SQLite lock if two writers | Medium-High |
| C – Host inherits kernel context | Works; ABP ReplaceDbContext is the cleaner module form of the same idea; snapshot drift if each host duplicates kernel migrations | Medium |
| D – Separate SQLite files | ATTACH/WAL atomicity and EF catalog gaps; avoid unless compliance requires physical files | High that it is costly |

**Quality assessment:** Language/framework facts are well sourced. SQLite vs SQL Server schema advice is the main pitfall (sources assume Postgres/SQL Server schemas). Cloud sections are intentionally empty for this product.

**User decision (2026-08-28):** Prefer **option B** (kernel DbContext + product DbContext, same SQLite file). Remaining steps treat B as the integration target.

## Integration Patterns Analysis

In-process modular-monolith integration on one SQLite file. HTTP/GraphQL/gRPC/service mesh are **not** the isolation mechanism; they already exist only for UrbanManagement upload. Cross-module “API” is **ABP application services + repositories**, not REST.

### API Design Patterns

**Public API = Service, not DbContext.** Kernel and product modules must not inject the other module’s `DbContext`. ViewModels already must go ViewModel → Service → Repository (MaterialMonospec AGENTS.md). Option B hardens that: `IRepository<WeighingRecord, long>` is registered from **kernel** `AddAbpDbContext`; `IRepository<UrbanWeighingExtension, Guid>` from **Urban** `AddAbpDbContext`. A service that creates a weighing record and an extension injects **two repositories**, not two contexts.

ABP’s modular CRM tutorial instead **replaces** module DbContexts with one host context so modules talk through `IOrderingDbContext` implemented by the host — that is option **C / ReplaceDbContext**, which the user declined. B keeps **two live Database APIs**. Conflict is documented: ABP prefers merge for “one transaction, one migration path”; B prefers **two migration paths** and accepts Service-level composition.

_RESTful APIs: Existing Urban `SubmitRecordAsync` to UrbanManagement; unchanged by EF split._
_GraphQL APIs: Not used._
_RPC and gRPC: Not used._
_Webhook Patterns: Not used._
_Source: [ABP modular CRM part 05 – DbContext interface](https://github.com/abpframework/abp/blob/dev/docs/en/tutorials/modular-crm/part-05.md); [ABP AddDefaultRepositories](https://abp.io/docs/5.3/Entity-Framework-Core)_

### Communication Protocols

Inside the desktop process: DI + `[UnitOfWork]` on services. Between clients and government cloud: existing HTTPS JSON. No new protocol.

ABP UoW with **two DbContexts**: support thread says UoW will **attempt to rollback all Database APIs** in the same ambient UoW, but that is **not** a native distributed/SQLite 2PC. Two SQLite connections can commit one and fail the other. For record+extension insert, prefer **one ambient UoW on one thread** and, if atomicity is required, **shared `SqliteConnection` + `UseTransaction`** (EF Core docs). Do **not** share one connection across threads (`SqliteConnection` is not thread-safe; nested transaction errors).

_HTTP/HTTPS: UrbanManagement upload only._
_WebSocket: Unrelated (device SDKs)._
_Message Queue: Not required for B; outbox would be overkill on one file._
_gRPC / Protobuf: Not used._
_Source: [EF Core share transaction](https://learn.microsoft.com/en-us/ef/core/saving/transactions); [ABP support Q8736 multi-DbContext UoW](https://abp.io/support/questions/8736/UnitOfWork-For-Multiple-Db-Contexts-with-Different-Connection-Strings-On-Different-Db-Servers); [Microsoft.Data.Sqlite locking](https://learn.microsoft.com/en-us/dotnet/standard/data/sqlite/database-errors)_

### Data Formats and Standards

Kernel ↔ product: **CLR entities and named records**, not JSON over the wire. Logical keys already used: `WeighingRecordId`, `WaybillId` (no FK) — this **is** the interoperability contract for later product splits.

Product settings: move `UrbanSettingsJson` off `SettingsEntity` into Urban-owned persistence (entity + JSON column on **Urban** table, or dedicated `UrbanSettingsEntity`). Kernel settings JSON (scale/camera/system) stays kernel.

_JSON and XML: Settings blobs remain JSON **inside product tables**, not kernel columns._
_Protobuf / MessagePack: N/A._
_CSV and Flat Files: Existing import paths stay on kernel if they target kernel tables._
_Custom Data Formats: ExtraProperties on Urban extension stays Urban-owned._
_Source: Current MaterialClient entities; modular monolith “store a plain ID, no cross-module FK” ([SEMastery cross-schema](https://se.dosibridge.com/articles/database/querying-and-performing-transactions-across-multiple-database-schemas-in-a-modular-monolith/))_

### System Interoperability Approaches

**Point-to-point in-process:** Urban service calls kernel `IWeighingRecordService` / repository, then upserts extension. Recycle does the same for waybills. This is the extractability story: a future product copies the product module, not the kernel schema.

**Not** API gateway / service mesh / ESB. SQLite cannot enforce schema-per-module roles (Postgres/SQL Server pattern). Isolation is **EF model membership + project references** (Urban project must not reference Recycle entities; Common must not reference Urban entities).

Startup interoperability: host runs `Migrate()` **kernel first**, then **product**. Same connection string; different `__EFMigrationsHistory_*` table names.

_Point-to-Point Integration: Service-to-service inside the exe._
_API Gateway / Service Mesh / ESB: Out of scope._
_Source: [Milan – data boundaries in modular monolith](https://milanjovanovic.tech/blog/how-to-keep-your-data-boundaries-intact-in-a-modular-monolith); [schema-per-module vs database-per-module](https://milanjovanovic.tech/blog/schema-per-module-vs-database-per-module)_

### Microservices Integration Patterns

MaterialClient is a **modular monolith**, not microservices. Do not introduce saga/circuit breaker for local SQLite.

ABP warning: outbox/inbox **in the same database** with two DbContexts can **collide on table names** if both define Outbox. Do not enable ABP outbox on both contexts without renaming.

_API Gateway / Service Discovery / Circuit Breaker: N/A._
_Saga Pattern: Avoid; same-file writes should use UoW + optional shared connection, not sagas._
_Source: [ABP microservice distributed events – same DB two schemas conflict](https://abp.io/docs/latest/solution-templates/microservice/distributed-events)_

### Event-Driven Integration

Optional later: `ILocalEventBus` after kernel insert so Urban handler writes extension. Default local bus runs **in the same UoW**; handler exceptions roll back the UoW **if** both DbContexts enlisted. Safer first slice: **explicit sequential calls in one service method** (create record → create extension), no event required.

_Publish-Subscribe: ABP local event bus only if needed._
_Event Sourcing / Kafka / CQRS: Out of scope._
_Source: [ABP distributed/local event bus UoW](https://abp.io/docs/10.2/framework/infrastructure/event-bus/distributed)_

### Integration Security Patterns

No new auth between kernel and product (same process, same user session). `UserSessions` remains **kernel**. Product tables must not store tokens. Upload HTTPS/auth to UrbanManagement unchanged.

_OAuth/JWT/mTLS: Unchanged cloud path._
_Data Encryption: SQLite file encryption not in this change._
_Source: Existing MaterialClient auth entities in Common._

### Option B integration contract (actionable)

1. **Connection:** both contexts `UseSqlite` same `Data Source`.
2. **History:** `MigrationsHistoryTable("__EFMigrationsHistory_Kernel")` vs `"__EFMigrationsHistory_Urban"` (Recycle analog). SQLite has no schema qualifier that isolates tables.
3. **Registration:** two `AddAbpDbContext` calls; `AddDefaultRepositories(includeAllEntities: true)` **per** context; **do not** `ReplaceDbContext` kernel into Urban (that would collapse B→C).
4. **Forbidden:** product `ApplyConfigurationsFromAssembly` on Common; product `DbSet<WeighingRecord>` unless `ExcludeFromMigrations` and documented as read-only anti-pattern — prefer kernel repository instead.
5. **Composition:** product application service injects kernel **service or repository interfaces** defined in Common, plus product repositories.
6. **Settings:** Urban settings entity on Urban context; drop/stop requiring `SettingsEntity.UrbanSettingsJson` for Urban host (migration in Urban history).
7. **New client checklist:** new csproj → entities → `IXxxDbContext` → `XxxDbContext` + factory → history table name → module `AddAbpDbContext` → host `DependsOn` + migrate after kernel.
8. **Atomicity:** default = same `[UnitOfWork]` method, sequential SaveChanges; escalate to shared connection + `UseTransaction` only for record+extension that must be all-or-nothing; never share connection across threads.

**Quality assessment:** Integration sources are strong for ABP UoW and modular boundaries. Gap: ABP docs push ReplaceDbContext (single runtime context); B is closer to “schema-per-module” without schemas. Confidence **high** on repository split and no-FK IDs; **medium** on ABP UoW actually rolling back two SQLite connections as one atomic unit — design as if they might not, and share a connection when it matters.

## Architectural Patterns and Design

Target architecture: **software product line + DDD shared kernel + modular-monolith persistence (option B)**. Hosts (Urban.exe / Recycle.exe / Standard.exe) share frozen kernel tables; each product is a bounded context with its own DbContext and extension tables.

```text
Urban host (or Recycle host)
  UI / ViewModels
       |  (services only)
  Product application services          Kernel application services
       |                                      |
  UrbanDbContext                        MaterialClientDbContext
  (extensions, Urban settings)          (WeighingRecord, Waybill, ...)
       \                                      /
              same MaterialClient.db
              two __EFMigrationsHistory_* tables
```

### System Architecture Patterns

**Modular monolith, not microservices.** Each product module: own assembly, own DbContext, own migrations. Cross-module calls go through **services/contracts**, not the other module’s entities. This matches .NET modular-monolith guidance (one context per module) adapted to SQLite (no schemas).

**Shared kernel (DDD):** `WeighingRecord`, `Waybill`, attachments, auth, kernel settings JSON live in Common. Keep the kernel **small**; DevIQ warns shared kernels become coupling magnets if they absorb product fields — which is why `UrbanSettingsJson` is out of baseline.

**Extension tables (vertical, not EAV):** One (or few) product tables per client, 1:0..1 by logical id. Industry write-ups often use FK as PK; MaterialClient already chose **no DB FK** for extractability — keep that; uniqueness index on `WeighingRecordId` remains.

**Product line / later requirement split:** Core assets (kernel schema + Common services) vs application assets (Urban/Recycle modules). New client = new application asset; weave migrations by **ordered apply** (kernel then product), not a custom DAVE weaver. Academic SPL DB evolution (DAVE) is heavier than needed.

**Anti-pattern:** Fat shared project that references every product entity (today’s Common `OnModelCreating`).

_Source: [DevIQ Shared Kernel](https://deviq.com/domain-driven-design/shared-kernel/); [Extension tables](https://v-checha.medium.com/extension-tables-f3e0ada6fce5); [Build a modular monolith in .NET](https://milanjovanovic.tech/blog/build-modular-monolith-dotnet-step-by-step); [Database evolution for SPLs (DAVE)](https://www.scitepress.org/PublishedPapers/2015/54841/54841.pdf)_

### Design Principles and Best Practices

- **SOLID / module boundaries:** Open for new products (new context), closed for kernel table changes. Dependency rule: Product → Common (kernel services/entities). Common ↛ Urban/Recycle.
- **Clean/hexagonal (light):** Persistence adapters are the two DbContexts. Domain entities can stay in Common (kernel) and product projects; do not explode into four projects per module unless needed — .NET guides allow merging Application+Infrastructure per module.
- **Contracts:** Prefer existing Common service interfaces over a new `*.Contracts` project unless Urban must stop taking a compile-time dependency on kernel entity types (not required for first slice).
- **Do not** use GraphQL vs REST as the architecture driver.

_Source: [Dometrain modular monoliths](https://dometrain.com/blog/getting-started-with-modular-monoliths-in-dotnet/); [SEMastery data isolation](https://se.dosibridge.com/articles/architecture/modular-monolith-data-isolation/)_

### Scalability and Performance Patterns

This is a **single-workstation SQLite** app. Horizontal scaling, load balancers, and consensus are irrelevant.

SQLite WAL: **one writer at a time** for the whole file, even with two DbContexts. Two contexts do **not** buy write parallelism. Architecture must keep write transactions **short** (no HTTP inside a dual-context transaction). Existing `PollingBackgroundService` + UI already contend; B must not add a second long-lived writer connection without busy_timeout / WAL.

If dual SaveChanges without shared connection: two writer rounds, more `SQLITE_BUSY` risk vs one context. Mitigation: sequential short saves, or one shared connection for the compose method.

_Source: [SQLite WAL](https://www2.sqlite.org/wal.html); [Single-writer SQLite](https://www.bugsink.com/blog/database-transactions/)_

### Integration and Communication Patterns

Unchanged from Step 3: in-process services; optional local events; HTTPS only to UrbanManagement. Architecture decision: **orchestration in product service** (call kernel save, then product save) rather than domain events for v1.

_Source: Step 3; [modular monolith step-by-step](https://milanjovanovic.tech/blog/build-modular-monolith-dotnet-step-by-step)_

### Security Architecture Patterns

Same process, same user. Kernel owns `UserSessions` / credentials. Product tables must not become a second identity store. File ACL / SQLite encryption unchanged. No new trust boundary between contexts.

_Source: Existing MaterialClient auth in Common; desktop threat model (local file)._

### Data Architecture Patterns

| Layer | Owner | Examples |
|-------|--------|----------|
| Kernel schema (frozen) | Common / `MaterialClientDbContext` | WeighingRecord, Waybill, attachments, LicenseInfo, User*, WorkSettings, Settings **without** UrbanSettingsJson |
| Urban schema (logical) | `UrbanDbContext` | UrbanWeighingExtension, Urban settings entity |
| Recycle schema (logical) | `RecycleDbContext` | RecycleWaybillExtension |

Table names stay unique in one SQLite file (no schema prefix). Naming convention: product prefix (`Urban*`, `Recycle*`) to avoid collisions when two products’ tables coexist after mixed installs.

**Read models:** list screens that need kernel + extension columns: two queries + in-memory join in the **product** service (Urban list already has this shape). Do not add a SQL VIEW in kernel that selects Urban columns (would recouple DDL).

_Source: [schema-per-module vs database-per-module](https://milanjovanovic.tech/blog/schema-per-module-vs-database-per-module); extension-table pattern_

### Deployment and Operations Architecture

- **One DB file per machine**, two (or more) migration pipelines in the **host that is installed**.
- Installer = product line derivation: Urban installer ships kernel + Urban migrations only.
- Startup: apply kernel pending, then product pending.
- Backup: copy `MaterialClient.db` (+ WAL/SHM if WAL).
- Mixed leftover tables from another product: ignore; do not drop in kernel migrations.

_Source: SPL core vs application assets; SQLite file ops_

### Architecture decision (ADR-style)

**Status: ADOPTED (2026-08-28).** OpenSpec change **not** opened yet (deferred by user).

**Decision:** Option B + product-common layers: `MaterialClient.Common` is the frozen kernel baseline; `MaterialClient.Common.Urban` / `MaterialClient.Common.Recycle` hold product entities, product DbContext/migrations, and product Service APIs. Hosts are UI composition only. Standard `MaterialClient` MUST NOT reference `Common.*` product projects.

**Why:** Freeze kernel snapshot; independent product DDL; matches extension tables and no-FK; later requirement splits add `Common.{Product}`.

**Consequences:** Dual history tables; no EF joins; SQLite single-writer; do not ReplaceDbContext; Urban settings leave kernel `SettingsEntity`.

**Rejected:** A (weak freeze), C (snapshot drift / ABP merge), D (ops + WAL ATTACH).

**Follow-up:** When implementation starts, create OpenSpec in `openspec/changes/` (do not implement from this research file alone).

### Naming: `Common.Urban` / `Common.Recycle` product-common layers (ADOPTED, 2026-08-28)

Product-specific **shared** code (entities, EF, application Service APIs) lives in **`MaterialClient.Common.{Product}`**, not in the WinExe and not as `*.EntityFrameworkCore` sibling projects. The WinExe (`MaterialClient.Urban` / `MaterialClient.Recycle`) is UI + host composition only.

**Csproj:**

| Project | Contains | Must NOT contain |
|---------|----------|------------------|
| `MaterialClient.Common` | Kernel entities, kernel Service APIs, shared hardware/config | Urban/Recycle entities, product DbContext, product migrations |
| `MaterialClient.Common.EntityFrameworkCore` | Kernel `MaterialClientDbContext` + kernel migrations (split from Common when EF leaves Common) | Product `DbSet`s |
| `MaterialClient.Common.Urban` | Urban entities, `UrbanDbContext`, Urban migrations, Urban Service interfaces **and** implementations (ABP `ITransientDependency`) | Avalonia views, Urban `WinExe` startup |
| `MaterialClient.Common.Recycle` | Recycle entities, `RecycleDbContext`, Recycle migrations, Recycle Service APIs | Recycle WinExe UI |
| `MaterialClient.Urban` | AXAML, Urban host module, `DependsOn` Common + Common.EF + **Common.Urban** | Product table mappings (delegate to Common.Urban) |
| `MaterialClient.Recycle` | Same pattern for Recycle | — |
| `MaterialClient` (standard) | Standard host | **No** `Common.Urban` / `Common.Recycle` references |

If kernel EF is not split yet, kernel Context can stay in `MaterialClient.Common` until the Common.EF project exists; **product** EF still must not stay in `MaterialClient.Common`.

**Namespaces (match csproj):** `MaterialClient.Common.Urban`, `MaterialClient.Common.Recycle`. Suggested folders in each product-common project: `Entities/`, `EntityFrameworkCore/` (DbContext, factory, `*EntityFrameworkCoreModule`), `Migrations/`, `Services/`.

**Types:**

| Kind | Kernel | Urban product-common | Recycle product-common |
|------|--------|----------------------|------------------------|
| DbContext | `MaterialClientDbContext` | `UrbanDbContext` | `RecycleDbContext` |
| Interface | `IMaterialClientDbContext` | `IUrbanDbContext` | `IRecycleDbContext` |
| ABP module | `MaterialClientCommonModule` / `MaterialClientEntityFrameworkCoreModule` | `MaterialClientCommonUrbanModule` | `MaterialClientCommonRecycleModule` |
| History table | `__EFMigrationsHistory_Kernel` | `__EFMigrationsHistory_Urban` | `__EFMigrationsHistory_Recycle` |

**References:**

```text
Common.Urban     → Common  (and Common.EntityFrameworkCore only if it must register alongside; prefer Urban module calling AddAbpDbContext<UrbanDbContext> itself)
Common.Recycle   → Common
MaterialClient.Urban (exe) → Common, Common.EntityFrameworkCore, Common.Urban, UI
MaterialClient (exe)       → Common, Common.EntityFrameworkCore, UI   // no Common.Urban
MaterialClient.UI          → Common only   // no Common.Urban (same rule as today: UI must not reference Urban)
```

Urban Service APIs used by the Urban host are injected from `Common.Urban`. If a mapper interface must stay on Common for UI (historical Xiaoshan mapper), the **interface** may remain on Common; the **implementation** lives in `Common.Urban` and is registered only when the Urban host loads `MaterialClientCommonUrbanModule`.

**New product:** add `MaterialClient.Common.{Product}` (EF + Service API) + `{Product}` WinExe. Do not add `Entities/Urban` back under `MaterialClient.Common`.
