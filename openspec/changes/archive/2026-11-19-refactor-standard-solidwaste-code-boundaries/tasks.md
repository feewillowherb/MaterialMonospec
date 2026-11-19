## 1. Baseline and call matrix

- [x] 1.1 Read root/sub-repository AGENTS and applicable traits; inspect HEAD, origin/HEAD, dirty files and overlapping active changes. Create the change-named branch from trunk before the first code edit; preserve unrelated work. Do not commit, push, merge or archive without explicit authorization.
- [x] 1.2 Record the current dependency graph and a field-level read/write matrix covering creation, matching, unmatching, editing, deletion, query, export and printing. Record existing behavior and transaction boundaries in design.md before changing call sites.
- [ ] 1.3 Verify the target baseline on an isolated database copy: the only business field in ExtraProperties is UseIndependentDisplayedNet. Do not rescan/clean historical keys or migrate old MaterialId/WaybillQuantity. If the baseline differs, stop writes to that database and record the mismatch.
- [x] 1.4 Reconcile current schema/app-isolation specs and active changes. Keep their deployment work separate; ensure all superseded schema requirements are covered by this delta.

## 2. Shared desktop hosting

- [x] 2.1 Reuse a suitable shared library or create MaterialClient.Desktop.Hosting for StartupService, MinimalWebHostService and PollingBackgroundService; keep executable/product implementation dependencies out of it. Update solution/project references and namespaces.
- [x] 2.2 Remove SolidWaste Compile Link entries targeting Standard exe sources; wire both hosts to the same shared implementations without copying them. Make stateful startup-service lifetime consistent and preserve cancellation, worker toggles and shutdown ordering.
- [x] 2.3 Bind StreetsConfig/SolidWasteTypeConfig in SolidWaste composition; remove unused SolidWaste registration from Standard. Verify authorization/HTTP dependencies and fixed product identity for both hosts.

## 3. Product ownership and integration

- [x] 3.1 Introduce only the product-neutral lifecycle operations required by the call matrix; keep SolidWaste fields/branches out of Common orchestration. Verify Standard no-op and SolidWaste persistence registrations resolve uniquely.
- [x] 3.2 Move SolidWaste Store, four-field operations and export implementation to the product module. Place shared UI-facing contracts/readonly records in a dependency-safe contract boundary. Preserve Standard mixed-mode historical reads through a read-only adapter without loading SolidWaste runtime modules or migrations.
- [x] 3.3 Replace old four-field ExtraProperties getters/setters, fallback reads and copy-upserts with explicit product inputs and extension queries at every inventoried call site. Use type-owned mutation and From*/To* projection; do not add mappers, tuples or DI for pure logic.
- [x] 3.4 Keep UI persistence behind Services. Consult avalonia-docs before any necessary window/binding edits; preserve ReactiveUI and existing visuals.
- [x] 3.5 Share the connection/transaction for kernel and extension writes under Service [UnitOfWork]. Await product operations and propagate failure. Preserve documented unmatch/delete semantics; do not add database FK/navigation/cascade behavior.

## 4. Single source of truth

- [x] 4.1 Retain UseIndependentDisplayedNet only as an ExtraProperties business authority; remove its extension entity/snapshot/mapping usage and route display/export to the canonical getter. Preserve true/false/default behavior.
- [x] 4.2 Inspect the retained physical flag column and INSERT constraints. Keep published migrations immutable; if needed, add a non-destructive product migration that makes unmapped-column insertion safe. Do not delete the old column or backfill the flag.
- [x] 4.3 Retire startup backfill from old keys. Preserve existing extension values and make missing-extension reads explicit; require valid product input for writes that create extensions. Do not persist fabricated defaults.

## 5. Verification and handoff

- [x] 5.1 Build both desktop hosts and affected shared consumers, including Urban/Recycle compile coverage. If outputs are locked, use the fixed .build-verify directory per sub-repository AGENTS.
- [x] 5.2 Add focused regression coverage for transaction rollback, four-field save/read behavior, missing extensions, retained-column INSERT and canonical net-display flag; test existing paths rather than mirroring implementation.
- [ ] 5.3 On Windows with isolated data, verify both hosts' authorization/login/main-window, polling and shutdown paths; verify create/match/unmatch/edit/query/export/print/restart and Standard historical mixed-mode reads.
- [ ] 5.4 Verify repeated startup preserves extensions, failed extension writes leave no partial kernel commit, and a mismatched baseline database remains unchanged. Record commands, environment, source identity and outcomes in the change; leave blocked checks unchecked.
- [x] 5.5 Run openspec validate refactor-standard-solidwaste-code-boundaries --strict and relevant AGENTS checks. Report ICD evidence against the declared L3 scope; do not infer acceptance from builds or checked tasks. Do not expand into installation/release acceptance.
