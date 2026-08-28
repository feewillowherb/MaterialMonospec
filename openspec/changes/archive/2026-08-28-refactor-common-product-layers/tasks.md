## 1. Solution and kernel EF project

- [x] 1.1 Add `MaterialClient.Common.EntityFrameworkCore` class library to `MaterialClient.sln`; move `MaterialClientDbContext`, factory, kernel Fluent mapping, and kernel `Migrations` out of `MaterialClient.Common`
- [x] 1.2 Remove Urban/Recycle `DbSet`s and entity configuration from kernel `OnModelCreating`; keep kernel `SettingsEntity` mapping without requiring `UrbanSettingsJson` as a baseline column (column removal after Urban settings move)
- [x] 1.3 Register kernel `AddAbpDbContext<MaterialClientDbContext>` with `__EFMigrationsHistory_Kernel` (or documented equivalent) and `AddDefaultRepositories`; wire standard `MaterialClient` host to the kernel EF module
- [x] 1.4 Point `dotnet ef` design-time at the kernel EF project; verify kernel snapshot no longer contains `UrbanWeighingExtension` or `RecycleWaybillExtension`

## 2. Common.Urban

- [x] 2.1 Add `MaterialClient.Common.Urban`; move `UrbanWeighingExtension` and Urban-only services from Common/Urban host into this project (`Entities/`, `Services/`, `EntityFrameworkCore/`)
- [x] 2.2 Add `UrbanDbContext`, `IUrbanDbContext`, `UrbanDbContextFactory`, `MaterialClientCommonUrbanModule`, `__EFMigrationsHistory_Urban`; map only Urban tables; no kernel table ownership
- [x] 2.3 Move Urban settings persistence off `SettingsEntity.UrbanSettingsJson` onto an Urban entity mapped by `UrbanDbContext`; copy existing JSON in a product migration; then drop or stop mapping the kernel column
- [x] 2.4 Keep Xiaoshan/settings mapper **interface** on Common if UI needs it; put implementation in `Common.Urban` and register only from the Urban host module
- [x] 2.5 Update `MaterialClient.Urban` to `DependsOn` Common + kernel EF + `MaterialClientCommonUrbanModule`; migrate kernel then Urban at startup; remove product Fluent from the WinExe

## 3. Common.Recycle

- [x] 3.1 Add `MaterialClient.Common.Recycle`; move `RecycleWaybillExtension` and Recycle-only Service APIs into this project
- [x] 3.2 Add `RecycleDbContext`, factory, `MaterialClientCommonRecycleModule`, `__EFMigrationsHistory_Recycle`; Recycle host `DependsOn` Common + kernel EF + Recycle product module; migrate kernel then Recycle
- [x] 3.3 Ensure Recycle host MUST NOT reference `MaterialClient.Common.Urban`

## 4. Hosts, UI, tests, verify

- [x] 4.1 Confirm `MaterialClient` and `MaterialClient.UI` have no `ProjectReference` to `Common.Urban` or `Common.Recycle`
- [x] 4.2 Update `MaterialClient.Urban.Tests` / Common tests project references and namespaces; add a test or compile check that the kernel model excludes product entity types
- [x] 4.3 `dotnet build MaterialClient.sln -o .build-verify` for standard, Urban, and Recycle hosts after file-lock-safe verify
- [x] 4.4 Document that existing SQLite files may retain orphan Urban/Recycle tables; do not add kernel DROP TABLE migrations
