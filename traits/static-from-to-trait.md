# static-from-to

Trait: all **data conversion** between project-owned types uses **static `From*` / `To*` methods**. Do not introduce mapper types, mapper interfaces, or DI-registered mapping services.

## Purpose (non-negotiable)

- Conversion is a **pure function** next to the type that owns the result (or an extension on the source).
- Mapping is **not** a layer, a service, or an injectable collaborator.
- New code must not add `IXxxMapper`, `XxxMapper`, `XxxMappingService`, AutoMapper `Profile`, or Mapster `IRegister` for project types.

## When this trait applies

- Writing or reviewing C# in `repos/MaterialClient`, `repos/UrbanManagement`, or `repos/FdSoft.BasePlatform`.
- OpenSpec `design.md` / `tasks.md` that sketch conversion APIs.
- Entity ↔ DTO, DTO ↔ form/UI state, JSON/string ↔ typed config, ViewModel snapshot ↔ persistable model.

Do **not** use this trait as an excuse to mass-rewrite existing mappers unless the current change’s proposal explicitly includes that cleanup.

## Required shape

**`From*`** lives on the **destination** type (static factory). Name includes the source when there are multiple sources.

**`To*`** converts **this instance** (instance method) or the source via a **static extension**, targeting the destination type name.

Lookup dictionaries and other helpers are extra parameters on `From*` / `To*`, not a mapper constructor.

```csharp
public static WeighingListItemDto FromWaybill(
    Waybill waybill,
    Dictionary<int, Material>? materialsDict,
    Dictionary<int, MaterialUnit>? materialUnitsDict)
{
    // map fields; no IMapper, no injected service
}

public static XiaoshanUploadSettingsFormState FromModesJson(string? modesJson) { /* ... */ }

public static string ToModesJson(this XiaoshanUploadSettingsFormState form) { /* ... */ }
```

Call sites:

```csharp
var item = WeighingListItemDto.FromWaybill(waybill, materials, units);
var json = form.ToModesJson();
```

## Forbidden

| Pattern | Why |
|---------|-----|
| `interface IFooMapper` + `FooMapper : ITransientDependency` | Conversion is not a service |
| Register mapper in module / DI | Nothing to resolve |
| `Map(source)` on a mapper instance | Use `Dest.From*(source)` or `source.To*()` |
| AutoMapper / Mapster profile for **new** project conversions | Same rule; do not add profiles |
| Tuple as conversion result | Use named `record` (see AGENTS.md Record 约定) |

Third-party APIs that already return mapped types: adapt at the boundary with `From*` / `To*`; do not wrap them in a project mapper class.

## Allowed exceptions

- Generated code (gRPC, OpenAPI clients) you do not own.
- BCL / EF / JSON serializer `Serialize` / `Deserialize` — still wrap into `FromJson` / `ToJson` when the project needs a typed helper.
- Test test-doubles that fake a destination; they still should not implement `IXxxMapper`.

## OpenSpec

- `design.md` method sketches must use `From*` / `To*`, not `IXxxMapper.Map`.
- `tasks.md` must not invent “实现 XxxMapper 并注册 DI”.

## Behavior guardrails

- Prefer `Dest.FromSource(...)` when building a DTO/record/entity from another model.
- Prefer `source.ToDest()` / `ToJson()` when the conversion reads naturally from the current value.
- Keep methods static (or static extensions); no instance mapper fields on ViewModels or AppServices.
- If a conversion needs I/O or UnitOfWork, that I/O belongs in a **Service**; the Service then calls `From*` / `To*` on in-memory values.

## Prompt

You operate under static-from-to.

1. Need to convert A → B? Add `B.FromA(...)` and/or `A.ToB()` (extension). Do not create a mapper type.
2. Extra context (dictionaries, culture, flags) are parameters, not constructor-injected mapper state.
3. Do not register conversion in DI.
4. Do not expand scope to delete every legacy mapper unless the user or proposal asked.
