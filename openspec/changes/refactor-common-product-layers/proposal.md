## Why

MaterialClient 三种宿主共用 `MaterialClient.Common` 里的单一 `MaterialClientDbContext`，Urban/Recycle 扩展表与 `UrbanSettingsJson` 进入内核模型和 migration。标准客户端无法在 schema 上与产品表隔离，后续按产品拆需求只能往内核实体加列。需要把 **Common 冻为基线**，产品定制与产品表放到 **Common.{Product}**，双 Context 同库演进。

## What Changes

- 新增 `MaterialClient.Common.Urban` / `MaterialClient.Common.Recycle`：产品实体、`UrbanDbContext`/`RecycleDbContext`、产品 migration、产品 Service API（接口+实现）
- 内核 EF 从 `MaterialClient.Common` 迁到 `MaterialClient.Common.EntityFrameworkCore`（`MaterialClientDbContext` 仅内核表）；若分阶段，第一阶段可暂留内核 Context 在 Common，但 **MUST NOT** 再映射产品实体
- 标准 `MaterialClient` 宿主 MUST NOT 引用 `Common.Urban` / `Common.Recycle`；Urban/Recycle WinExe 仅 UI/模块组合，`DependsOn` 对应 `Common.{Product}` 模块
- `MaterialClient.UI` MUST NOT 引用产品 Common 程序集；若设置窗需要产品 mapper，接口可留 Common，实现 MUST 在 `Common.Urban` 且仅 Urban 宿主注册
- `SettingsEntity.UrbanSettingsJson` 移出内核基线，迁到 Urban 自有设置持久化（Urban Context）
- 同 SQLite 文件、两套 `__EFMigrationsHistory_*`；禁止 `ReplaceDbContext` 把产品模型并回内核（否则变回单 Context）
- 不自动 DROP 旧库中的产品表；新标准端安装不创建 Urban/Recycle 表
- **BREAKING**（程序集）：Urban/Recycle 实体与产品仓储从 `MaterialClient.Common` 命名空间迁出；调用方改引用 `MaterialClient.Common.Urban` / `Common.Recycle`

## Capabilities

### New Capabilities

- `product-common-layers`: 产品线分层：Common 基线 vs Common.{Product} 定制（实体、EF、Service API）与宿主引用规则
- `product-dbcontext-isolation`: 内核与产品双 DbContext、独立 migration/history、无跨 Context FK/join、启动迁移顺序

### Modified Capabilities

- `urban-abp-module`: Urban 模块依赖改为 Common + 内核 EF + Common.Urban；不再由 Common 提供 Urban 扩展表
- `recycle-abp-module`: Recycle 模块依赖改为 Common + 内核 EF + Common.Recycle；不再由 Common 提供 Recycle 扩展表

## Impact

- **MaterialClient**：`Common`、新 `Common.EntityFrameworkCore`、`Common.Urban`、`Common.Recycle`、三宿主 csproj/ABP 模块、sln、测试项目引用
- **UrbanManagement / FdSoft.BasePlatform**：本 change **不改**
- 无对外 HTTP **BREAKING**；本地 SQLite 旧库可能残留产品表（不强制删除）
- 调研依据：`_bmad-output/planning-artifacts/research/technical-materialclient-product-ef-isolation-research-2026-08-28.md`
