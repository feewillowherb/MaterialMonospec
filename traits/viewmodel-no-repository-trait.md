# viewmodel-no-repository

Trait: **presentation types MUST NOT touch Repository (or DbContext)**. Data access goes **View / ViewModel (or Blazor / MVC UI) → Service → Repository → DbContext**. This rule lives in MaterialMonospec `traits/`; **do not duplicate it in sub-repo `AGENTS.md`**.

## Purpose (non-negotiable)

- ViewModels (and equivalent UI types) **cannot own UnitOfWork**. Injecting `IRepository<>` or `DbContext` captures a scoped context that is disposed when the original DI scope ends; the UI object outlives that scope → `ObjectDisposedException` / inconsistent transactions.
- Persistence and transactions belong in **Service**. UI coordinates commands, binding, and display.
- Layering: **View → ViewModel → Service → Repository → DbContext**.

## When this trait applies

- C# UI in `repos/MaterialClient` (Avalonia ViewModel, Window / UserControl code-behind).
- C# UI in `repos/UrbanManagement` or `repos/FdSoft.BasePlatform` that would otherwise inject repositories (Blazor component/page, MVC controller used as a screen).
- OpenSpec `design.md` / `tasks.md` that wire UI to data access.
- Code review of constructors that take `IRepository<,>` on a `*ViewModel` / Blazor component.

Do **not** use this trait to mass-rewrite existing UI→Repository calls unless the current change’s proposal lists that cleanup.

## Forbidden in presentation types

Presentation types include `*ViewModel`, Avalonia code-behind, Blazor `@code` / component classes, and UI controllers that act as screens.

| Pattern | Why |
|---------|-----|
| Inject `IRepository<TEntity, TKey>` / `IRepository<TEntity>` | Holds disposed scoped DbContext |
| Inject `DbContext` / `IDbContextProvider<>` for queries or writes | Same lifetime bug |
| Call `GetListAsync` / `InsertAsync` / `UpdateAsync` / `DeleteAsync` / `GetQueryable` on a repository from UI | Bypasses Service and UoW |
| Put write/query business rules in the ViewModel that belong on a Service | Logic scattered; hard to test |

```csharp
// Forbidden
public class UrbanAttendedWeighingViewModel
{
    public UrbanAttendedWeighingViewModel(IRepository<WeighingRecord, long> repository) { /* ... */ }
}
```

## Required

- UI injects **Service interfaces** only for data (`IWeighingRecordService`, AppServices, etc.).
- If no Service exists but UI needs persistence or external I/O, **create a Service** that passes `minimal-di` (repository / I/O). Do not inject Repository into the ViewModel “for now”.
- **Writes** on Service methods MUST use `[UnitOfWork]` (ABP). Exceptions in that method roll back with the UoW.
- Service constructors inject Repository and other **runtime** services; **MUST NOT** inject ViewModels.
- Cross-table composition stays in Service (`no-database-fk`). Entity state changes use type-owned methods (`type-owned-methods`).

```csharp
public interface IWeighingRecordService : ITransientDependency
{
    Task<List<WeighingRecord>> GetRecordsByStatusAsync(SyncStatus status);
    Task<WeighingRecord> CreateAsync(CreateWeighingRecordDto dto);
}

public class WeighingRecordService : IWeighingRecordService
{
    private readonly IRepository<WeighingRecord, long> _repository;

    public WeighingRecordService(IRepository<WeighingRecord, long> repository)
    {
        _repository = repository;
    }

    [UnitOfWork]
    public async Task<List<WeighingRecord>> GetRecordsByStatusAsync(SyncStatus status)
    {
        return await _repository.Where(r => r.SyncStatus == status).ToListAsync();
    }

    [UnitOfWork]
    public async Task<WeighingRecord> CreateAsync(CreateWeighingRecordDto dto)
    {
        var record = WeighingRecord.CreatePending(dto.PlateNumber, dto.TotalWeight);
        await _repository.InsertAsync(record);
        return record;
    }
}

public class UrbanAttendedWeighingViewModel : ViewModelBase
{
    private readonly IWeighingRecordService _weighingRecordService;

    public UrbanAttendedWeighingViewModel(IWeighingRecordService weighingRecordService)
    {
        _weighingRecordService = weighingRecordService;
    }

    public async Task LoadRecordsAsync()
    {
        var records = await _weighingRecordService.GetRecordsByStatusAsync(SyncStatus.Pending);
        Records.AddRange(records);
    }
}
```

## Allowed

- ViewModel injects hardware, messaging, or other **non-persistence** services (`IHikvisionService`, `ILocalEventBus`, etc.).
- Tests may fake Services; they MUST NOT make the production ViewModel take a Repository to “simplify tests”.
- Background workers and AppServices MAY inject Repository (they are not presentation).

## OpenSpec

- `design.md` / `tasks.md` MUST NOT specify ViewModel → Repository or ViewModel → DbContext.
- If UI needs a new query/write, tasks add or extend a **Service** method, not a Repository field on the ViewModel.

## Review checklist

- [ ] ViewModel / Blazor UI does not inject `IRepository<,>` or `DbContext`
- [ ] ViewModel / Blazor UI does not call Repository CRUD / queryable APIs
- [ ] All persistence goes through a Service
- [ ] Service write methods have `[UnitOfWork]`
- [ ] Service does not inject ViewModel

## Behavior guardrails

- Prefer one Service method per UI use case over leaking queryables to the ViewModel.
- Do not “fix” disposed DbContext by making Repository singleton or storing DbContext on the ViewModel.
- Conflict with a sub-repo `AGENTS.md` local note: **this trait is stricter** for persistence layering.

## Prompt

You operate under viewmodel-no-repository.

1. Need data in a ViewModel or UI component? Inject a Service, never `IRepository` / `DbContext`.
2. No Service yet? Add one that meets `minimal-di`; do not skip to Repository in the UI.
3. Writes go through `[UnitOfWork]` Service methods.
4. Do not mass-migrate leftover UI→Repository unless this change’s proposal lists that work.
