# type-owned-methods

Trait: **the type that owns the data** performs **state changes** and **cross-type projections**. Service / AppService / ViewModel layers orchestrate I/O and transactions; they **must not** assign fields on entities, DTOs, records, or form models.

> Supersedes the former `static-from-to` name, which covered only the projection half (`From*` / `To*`).

## Purpose (non-negotiable)

Two lanes, same ownership rule:

| Lane | What | Where logic lives |
|------|------|-------------------|
| **Mutation** | Change fields on a type you already hold | **Instance methods** on that type (entity, DTO, record, envelope, form state) |
| **Projection** | Build type B from type A (read-only conversion) | Static **`From*`** on the destination; optional **`To*`** extension on the source that delegates to `From*` |

- Mapping is **not** a layer, a service, or an injectable collaborator.
- New code must not add `IXxxMapper`, `XxxMapper`, `XxxMappingService`, AutoMapper `Profile`, or Mapster `IRegister` for project types.
- Do not register those types in DI — see `minimal-di-trait.md`.

## When this trait applies

- Writing or reviewing C# in `repos/MaterialClient`, `repos/UrbanManagement`, or `repos/FdSoft.BasePlatform`.
- OpenSpec `design.md` / `tasks.md` that sketch mutation or conversion APIs.
- Entity state changes, DTO / envelope updates, Entity ↔ outbound DTO, DTO ↔ form / JSON, ViewModel snapshot ↔ persistable model.

Do **not** use this trait as an excuse to mass-rewrite existing mappers or Service inline assignments unless the current change’s proposal explicitly includes that cleanup. **When you touch a Service block that assigns fields, migrate it to type-owned methods in that change.**

## Lane 1 — Mutation (state change)

Any type that **owns** mutable state — including **non-entity** DTOs, records with behavior, config envelopes, form state — exposes **named instance methods** for changes. Callers (Service, ViewModel) invoke those methods; they do not set properties line by line.

```csharp
// Entity / aggregate
waybill.ConfirmReceiving(receivingTime, proof);
waybill.ApplyRecycleExtension(unitPrice, saleContractNo);

// DTO / envelope / form (still owned by their type, not by Service)
envelope.EnableMode(XiaoshanUploadMode.Gate);
form.ApplySettings(settings);
writeDto.WithExpectedConfigVersion(expectedVersion);
```

**Forbidden in Service / AppService / ViewModel:**

```csharp
waybill.ReceivingTime = time;           // use domain method
dto.UnitPrice = extension.UnitPrice;      // use dto/envelope method or projection
envelope.Modes.Gate.Enabled = true;       // use envelope method
new RecycleTransportRecord { ... };       // use From* (projection lane)
```

Prefer **narrow, intention-revealing names** (`ConfirmReceiving`, `EnableMode`, `ApplySettings`) over generic `SetX`.

## Lane 2 — Projection (`From*` / `To*`)

Cross-type, **read-only** construction: outbound API DTOs, sync payloads, list items, JSON snapshots. Logic lives on the **destination** (canonical) or as a **source extension** that forwards to `From*`.

**`From*`** — static factory on the **destination** type. Name includes the source when multiple sources exist.

**`To*`** — instance method or static extension on the **source**; **must delegate** to `Dest.From*` (single implementation; no duplicated field maps).

Extra context (dictionaries, flags, related entities already loaded) are **method parameters** or a **context `record`**, not mapper constructor injection.

```csharp
public static WeighingListItemDto FromWaybill(
    Waybill waybill,
    Dictionary<int, Material>? materialsDict,
    Dictionary<int, MaterialUnit>? materialUnitsDict) { /* ... */ }

public static RecycleTransportRecord FromWaybill(
    Waybill waybill,
    RecycleTransportRecordContext ctx) { /* ... */ }

public static XiaoshanUploadSettingsFormState FromModesJson(string? modesJson) { /* ... */ }

public static string ToModesJson(this XiaoshanUploadSettingsFormState form) { /* ... */ }

// Ergonomic wrapper — delegates only
public static RecycleTransportRecord ToRecycleTransportRecord(
    this Waybill waybill,
    RecycleTransportRecordContext ctx)
    => RecycleTransportRecord.FromWaybill(waybill, ctx);
```

Call sites:

```csharp
var item = WeighingListItemDto.FromWaybill(waybill, materials, units);
var record = RecycleTransportRecord.FromWaybill(waybill, ctx);
var json = form.ToModesJson();
```

**Dependency direction:** domain entities **must not** take dependencies on external contract DTOs (GovSync payload, third-party API shape). Those DTOs own `FromEntity` / `FromWaybill`; the entity does not own `ToGovPayload()`.

Stateless pure rules (e.g. license `-02` suffix) may live in a static helper type (`XiaoshanBuildLicenseNo.ForProduct`); that is not a mapper service.

Fallible projection: use `TryFrom*` returning a named `record` (never a C# tuple / `ValueTuple`), for example `record TryFromResult<T>(bool Ok, T? Value, string? Error)`, or document throws (e.g. `ArgumentException`) in OpenSpec scenarios.

Nested projection: parent `From*` calls child `From*`; do not assemble nested objects field-by-field in Service.

## Service layer boundary

Service / AppService **SHALL**:

1. Load / persist via repositories (with `[UnitOfWork]` where required).
2. Call **type-owned mutation methods** on entities, DTOs, envelopes.
3. Call **`From*` / `To*`** for outbound or cross-layer snapshots.
4. Call external APIs, publish events, return results.

Service **SHALL NOT**:

- Assign fields on entities, DTOs, records, or form models (except delegating to lane 1 methods).
- Build outbound DTOs with object initializers or multi-line property assignment (use lane 2).
- Host mapping logic in private `MapXxx` helpers — move logic to the owning type.

```csharp
// OK — thin orchestration
var waybill = await _waybillRepo.GetAsync(id);
waybill.ConfirmReceiving(dto.ReceivingTime, proof);
var outbound = RecycleTransportRecord.FromWaybill(waybill, ctx);
await _recycleClient.SubmitAsync(outbound);
await _waybillRepo.UpdateAsync(waybill);
```

I/O and UnitOfWork stay in Service; **in-memory** mutation and projection stay on types.

## Forbidden

| Pattern | Why |
|---------|-----|
| `interface IFooMapper` + DI registration | Conversion / mapping is not a service |
| `Map(source)` on a mapper instance | Use owner mutation or `Dest.From*` |
| AutoMapper / Mapster profile for **new** project conversions | Same rule |
| Tuple as conversion result | Use named `record` (see AGENTS.md) |
| Service / ViewModel field assignment | Use lane 1 or lane 2 on the owning type |
| `IXxxMappingService` for field resolution | Use static `Result.From*(...)` on the result type |

Third-party generated clients: adapt at the boundary with `From*` / `To*`; do not wrap in a project mapper class.

## Allowed exceptions

- Generated code (gRPC, OpenAPI) you do not own.
- BCL / EF / JSON `Serialize` / `Deserialize` — wrap in `FromJson` / `ToJson` when the project needs a typed helper.
- Test doubles; they still must not implement `IXxxMapper`.

## OpenSpec

- `design.md` sketches: mutation → type-owned instance methods; projection → `From*` / `To*`, not `IXxxMapper.Map`.
- `tasks.md` must not invent “实现 XxxMapper 并注册 DI” or “在 Service 中赋值字段”.

## Behavior guardrails

- **Mutation:** `entity.Apply…()` / `envelope.Enable…()` / `form.Merge…()` on the owner.
- **Projection:** prefer `Dest.FromSource(...)`; optional `source.ToDest(...)` that delegates.
- **Context:** use `record XxxContext(...)` for many projection inputs; no DI.
- **Legacy:** do not repo-wide delete mappers unless asked; **do** fix assignments in code you touch.

## Prompt

You operate under **type-owned-methods**.

1. **Changing** state on a type? Add an instance method on **that type** (entity, DTO, envelope, form). No Service property assignment.
2. **Converting** A → B (read-only)? Add `B.FromA(...)` and/or `A.ToB(...)` delegating to `FromA`. No mapper type, no DI.
3. Service loads data, calls owner methods + `From*` / `To*`, then I/O. No `MapXxx` private methods with field copies.
4. Do not expand scope to delete every legacy mapper unless the user or proposal asked.
