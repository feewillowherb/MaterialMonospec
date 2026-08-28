# minimal-di

Trait: **default deny** for ABP / DI registration. New types register as `ITransientDependency` or `ISingletonDependency` **only** when they need runtime collaborators (repository, HTTP, bus, lifecycle). Pure logic uses **static methods**, **extensions**, or **type-owned instance methods** (see `type-owned-methods-trait.md`) — not injectable services.

## Purpose (non-negotiable)

- DI is for **orchestration with I/O and infrastructure**, not for every helper class.
- **Do not register pure functions.** If a type has no constructor dependency on runtime services, it must not implement ABP dependency marker interfaces.
- Prefer Rust-style locality: logic lives on the owning type or as static/extension helpers; the container resolves only types that truly need wiring.

## When this trait applies

- Writing or reviewing C# in `repos/MaterialClient`, `repos/UrbanManagement`, or `repos/FdSoft.BasePlatform`.
- OpenSpec `design.md` / `tasks.md` that propose new classes, services, or DI registration.
- Refactors that add `IXxxService`, `XxxHelperService`, `XxxMappingService`, or `services.AddTransient<...>()`.
- Code review when AI output marks every new class as `ITransientDependency`.

Do **not** use this trait to remove legitimate existing services or MaterialClient ViewModel / Window registration unless the current change explicitly includes that cleanup.

## Registration gate (decision tree)

Register with `ITransientDependency` / `ISingletonDependency` (or explicit module registration) **only if at least one** applies:

| # | Condition | Examples |
|---|-----------|----------|
| 1 | **Persistence** | Injects `IRepository<>`, `DbContext`, `IUnitOfWorkManager`; `[UnitOfWork]` write paths |
| 2 | **External I/O** | HTTP clients, serial/hardware, app-root filesystem, external APIs |
| 3 | **ABP infrastructure role** | `ApplicationService`, `DomainService`, `BackgroundWorker`, `ILocalEventHandler`, auth handlers |
| 4 | **Lifecycle / shared runtime state** | Token refresh, connection pool, in-process cache (`ISingletonDependency`) |
| 5 | **Project UI convention** | MaterialClient / shared UI: ViewModel, Window, `ISettingsSection` marked transient per sub-repo `AGENTS.md` |

If **none** apply → **do not register**. Use static / extension / type-owned methods instead.

## Do not register (use static / extension / type-owned)

| Pattern | Use instead |
|---------|-------------|
| `IXxxMapper` / `XxxMapper : ITransientDependency` | `Dest.From*` / `source.To*` (`type-owned-methods`) |
| `IXxxMappingService` / field-resolution service (no I/O) | `Result.From*(...)` on the result type |
| `IXxxHelperService` / `XxxUtilityService` | `static` class or extensions |
| `IXxxFormatterService` / unit conversion with no I/O | `static` methods or extensions on the relevant type |
| `IXxxValidatorService` (pure rules, no DB) | static `Validate` / `TryValidate` on DTO or value object |
| Facade over **only** static helpers | call static methods directly; no wrapper service |
| `services.AddTransient` for stateless helpers | remove registration; call static API |

```csharp
// Forbidden — pure logic in DI
public interface IXiaoshanLicenseNoService : ITransientDependency
{
    string ForProduct(string licenseNo);
}

// Allowed — static helper
public static class XiaoshanBuildLicenseNo
{
    public static string ForProduct(string licenseNo) => /* ... */;
}
```

```csharp
// Forbidden
public class WeighingUnitConverterService : ITransientDependency
{
    public decimal TonToKg(decimal ton) => ton * 1000m;
}

// Allowed
public static class WeighingUnits
{
    public static decimal TonToKg(decimal ton) => ton * 1000m;
}
```

```csharp
// Allowed — needs repository + orchestration
public class RecycleReceivingService : IRecycleReceivingService, ITransientDependency
{
    [UnitOfWork]
    public async Task ConfirmAsync(long waybillId, ConfirmReceivingInput input)
    {
        var waybill = await _waybillRepository.GetAsync(waybillId);
        waybill.ConfirmReceiving(input.ReceivingTime, input.Proof);
        var outbound = RecycleTransportRecord.FromWaybill(waybill, input.ToContext());
        await _recycleClient.SubmitAsync(outbound);
    }
}
```

## Relationship to `type-owned-methods`

| Concern | Trait |
|---------|-------|
| Where mutation / projection logic lives | `type-owned-methods` |
| Whether that logic may be an injectable service | **`minimal-di`** |

Both apply together: even if logic were moved out of Service, **do not** register it as `ITransientDependency` unless the registration gate passes.

## Service creation rule (clarified)

Root `AGENTS.md` says: create a Service when Repository access is needed. That means an **AppService / DomainService that orchestrates persistence or I/O** — not «any new behavior → new Service».

- **Create** `IXxxService` + implementation when the gate (above) requires DI.
- **Do not create** a Service solely for testability, «clean architecture», or to wrap static helpers.
- **Do not** register conversion, formatting, or validation that has no injected runtime dependencies.

## Forbidden naming (new code)

New injectable types must not use these suffixes unless the type clearly passes the registration gate **and** performs I/O or persistence:

- `*HelperService`, `*UtilityService`, `*ConverterService`, `*FormatterService`
- `*Mapper`, `*MappingService` (see `type-owned-methods`)

Prefer domain names: `RecycleReceivingService`, `GovSyncBackgroundWorker`, `WeighingRecordService`.

## OpenSpec

- `design.md` must not propose `IXxxHelperService` / `XxxMappingService` for pure logic.
- `tasks.md` must not include «实现 XxxService 并注册 DI» unless the task satisfies the registration gate; otherwise specify static / extension / `From*` APIs.
- Archived designs that used mapping services (e.g. removed `XiaoshanUploadFieldMappingService`) are **not** templates for new work.

## Sub-repo overrides

Sub-repo `AGENTS.md` may **require** DI for specific kinds (e.g. ViewModels). When sub-repo rules require registration, follow sub-repo; when sub-repo is silent, **`minimal-di` default deny** applies.

## Behavior guardrails

- Before adding `ITransientDependency`, ask: **Does this type inject any runtime service from the gate table?** If no → static / extension.
- Prefer one orchestration service calling many static helpers over many tiny transient services.
- Do not add `services.AddTransient` in modules for types that could be static.
- Touching legacy unnecessary services: migrate to static in that change only when you already touch the call site; no repo-wide purge unless asked.

## Prompt

You operate under **minimal-di**.

1. New class? Default: **not** in DI. Check the registration gate.
2. Pure mapping, formatting, validation, or rules? Static, extension, or type-owned methods — **never** `ITransientDependency`.
3. Needs Repository, HTTP, bus, worker, or UI convention? Then register with the correct lifetime.
4. Do not invent `IXxxHelperService` because «services are testable» — unit-test static and `From*` instead.
5. Pair with **type-owned-methods**: Service orchestrates; types own logic; container stays small.
