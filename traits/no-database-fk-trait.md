# no-database-fk

Trait: this project **does not use database foreign keys**. Related rows are linked by **logical Id columns**; integrity and joins live in **Service** code, not in the schema or EF relationship mapping.

## Purpose (non-negotiable)

- Tables MAY store `XxxId` / `YyyId` values that refer to other tables’ primary keys.
- The database and EF Core **MUST NOT** declare FK constraints, navigations that generate FKs, or cascade/restrict delete at the engine.
- Composition across entities (including kernel vs product contexts) happens in the Service layer.

## When this trait applies

- New or changed entities, Fluent API, migrations, SQL scripts in any sub-repo (`MaterialClient`, `UrbanManagement`, `FdSoft.BasePlatform`).
- OpenSpec `design.md` / `tasks.md` that sketch tables or EF models.
- Dual-context / product-layer work: **no cross-Context FK** either.

Do **not** use this trait to mass-drop existing engine FKs unless the current change’s proposal explicitly includes that cleanup.

## Required shape

- Store the related key as a scalar (`int` / `long` / `Guid`), named `{Related}Id`.
- Load related data with a second query, dictionary lookup, or Service call; then map with static `From*` / `To*` (see `static-from-to`).
- If two writes must be atomic, share a connection/transaction in the Service; do not encode that as an FK.

```csharp
// Entity: logical id only — no navigation, no [ForeignKey]
public class UrbanWeighingExtension
{
    public long WeighingRecordId { get; set; }
}

// Service: compose
var record = await _weighingRecordService.GetAsync(id);
var ext = await _urbanExtensionRepository.FindAsync(e => e.WeighingRecordId == id);
```

## Forbidden

| Pattern | Why |
|---------|-----|
| SQL `REFERENCES` / `FOREIGN KEY` / `CONSTRAINT ... FOREIGN KEY` | Engine FK |
| EF `HasOne` / `HasMany` / `WithOne` / `WithMany` / `HasForeignKey` | Generates FK and navigations |
| `[ForeignKey]` / `[InverseProperty]` on project entities | Same |
| `OnDelete(DeleteBehavior.Cascade\|Restrict\|SetNull\|ClientCascade)` | Engine or client cascade via relationship |
| Navigation properties whose only purpose is an EF relationship (`virtual Waybill Waybill`) | Pulls FK into the model |
| Cross-DbContext FK or `ReplaceDbContext` to “fix” joins | Violates isolation; join in Service |

## Allowed

- Scalar `*Id` columns and indexes on those columns (index ≠ FK).
- Application checks: “id exists”, orphan warnings, sync rewrites of stored ids.
- JSON nested ids (e.g. `MaterialsJson`) treated as data, not schema FK.
- Third-party / generated schemas you do not own; do not add FKs when wrapping them.

## OpenSpec

- `design.md` MUST NOT specify database FK, `HasForeignKey`, or cascade-on-delete between tables.
- Cross-module related data: **logical Id + Service composition**.
- `tasks.md` MUST NOT invent “配置外键 / 加导航属性 / Include 导航”.

## Behavior guardrails

- Prefer two queries over `Include` of a navigation that would require an FK.
- SQLite `PRAGMA foreign_keys` MUST remain irrelevant: the model must not depend on it.
- New product tables MUST NOT FK to kernel tables (or the reverse).
- Do not expand scope to strip legacy FKs unless the user or proposal asked.

## Prompt

You operate under no-database-fk.

1. Need a relation? Add `{Related}Id` only. Do not add FK constraints or EF relationship mapping.
2. Need related rows in one use case? Query in Service and compose; do not `Include` via navigation.
3. Need atomic writes? Shared connection/transaction in Service, not FK.
4. Do not drop historical engine FKs unless this change’s proposal lists that work.
