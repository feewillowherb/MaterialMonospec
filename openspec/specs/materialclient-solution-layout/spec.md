# MaterialClient Solution Layout Specification

## Purpose

定义 MaterialClient 子仓库的 `src/` 与 `tests/` 目录布局、解决方案嵌套结构，以及构建/打包脚本路径与 `src` 布局对齐的要求。

## Requirements

### Requirement: MaterialClient src and tests directory layout

The MaterialClient repository MUST organize production code under `src/` and test projects under `tests/`, consistent with the UrbanManagement repository layout pattern.

#### Scenario: Source projects under src
- **WHEN** the MaterialClient repository root is inspected
- **THEN** SHALL exist a `src/` directory
- **AND** SHALL contain `MaterialClient/`, `MaterialClient.Common/`, `MaterialClient.UI/`, `MaterialClient.Urban/`, `MaterialClient.Demo/`, and `MaterialClient.Toolkit/` as immediate child project folders
- **AND** each child SHALL contain its corresponding `.csproj` at `src/<ProjectName>/<ProjectName>.csproj`

#### Scenario: Test projects under tests
- **WHEN** the MaterialClient repository root is inspected
- **THEN** SHALL exist a `tests/` directory
- **AND** SHALL contain `MaterialClient.Common.Tests/` with `MaterialClient.Common.Tests.csproj`
- **AND** test projects MUST NOT reside directly at repository root

#### Scenario: Solution file at repository root
- **WHEN** `MaterialClient.sln` is opened
- **THEN** the solution file SHALL remain at repository root
- **AND** SHALL define solution folders `src` and `tests`
- **AND** SHALL nest each project under the appropriate folder via `NestedProjects`

#### Scenario: Project references resolve after move
- **WHEN** `dotnet build MaterialClient.sln` is executed from repository root
- **THEN** all projects SHALL compile without missing ProjectReference paths
- **AND** `MaterialClient.Urban` SHALL successfully reference `MaterialClient.Common` and `MaterialClient.UI`

#### Scenario: Directory.Build.props applies to moved projects
- **WHEN** projects are built under `src/` or `tests/`
- **THEN** root `Directory.Build.props` SHALL still apply inherited settings (TargetFramework, Nullable, shared packages)

### Requirement: Root-level build and packaging scripts path alignment

Build and packaging scripts at repository root MUST use paths consistent with the `src/` layout.

#### Scenario: Main installer script paths
- **WHEN** `MaterialClient.iss` is compiled after publish
- **THEN** `SourceDir` SHALL point to `src\MaterialClient\bin\Release\net10.0\win-x64\publish` (or equivalent documented path)
- **AND** `SetupIconFile` SHALL reference icon under `src\MaterialClient\Assets\`

#### Scenario: Publish commands use explicit project paths
- **WHEN** release publish is run from repository documentation or scripts
- **THEN** `dotnet publish` SHALL target `src/MaterialClient/MaterialClient.csproj` for the main app
- **AND** SHALL target `src/MaterialClient.Urban/MaterialClient.Urban.csproj` for the Urban variant
