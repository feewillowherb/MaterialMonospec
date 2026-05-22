# 构建配置 规范

## 目的
待定 - 由变更 centralize-build-configuration 归档后创建。归档后更新目的。

## 需求

### 需求：集中式构建配置

系统应在解决方案根目录使用 `Directory.Build.props` 定义适用于所有项目的公共构建设置和包引用。

#### 场景：所有项目均可使用 AutoConstructor
- **当** 解决方案中的项目使用 `[AutoConstructor]` 特性
- **则** AutoConstructor 源生成器应可用，且无需在项目的 `.csproj` 中显式添加包引用
- **且** 包引用应在 `Directory.Build.props` 中定义，且：
  - `PrivateAssets` 设为 `all`
  - `IncludeAssets` 设为 `runtime; build; native; contentfiles; analyzers`

#### 场景：公共包自动可用
- **当** 在 `Directory.Build.props` 中添加包引用
- **则** 解决方案中所有项目应自动可访问该包
- **且** 项目无需在各自 `.csproj` 中显式引用该包

### 需求：集中式包版本管理

系统应使用带中央包管理（CPM）的 `Directory.Packages.props`，在单一位置管理所有包版本。

#### 场景：包版本集中定义
- **当** 在 `Directory.Packages.props` 中更新某包版本
- **则** 使用该包的所有项目应自动使用更新后的版本
- **且** 项目在 `.csproj` 中引用包时不应写版本号

#### 场景：项目间版本一致
- **当** 多个项目引用同一包
- **则** 所有项目应使用 `Directory.Packages.props` 中定义的同一版本
- **且** 构建系统应避免版本冲突

#### 场景：无版本的包引用
- **当** 项目在 `.csproj` 中添加 PackageReference
- **则** PackageReference 不得包含 Version 属性
- **且** 版本应从 `Directory.Packages.props` 解析
- **除非** 该包为项目专用且未在 `Directory.Packages.props` 中定义

### 需求：构建配置文件结构

系统应在解决方案根目录维护构建配置文件。

#### 场景：解决方案根目录存在 Directory.Build.props
- **当** 构建解决方案时
- **则** 解决方案根目录应存在 `Directory.Build.props`
- **且** 其应被解决方案中所有项目自动导入

#### 场景：解决方案根目录存在 Directory.Packages.props
- **当** 构建解决方案时
- **则** 解决方案根目录应存在 `Directory.Packages.props`
- **且** 其中应包含 `<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>`
- **且** 其中应包含所有包版本定义

#### 场景：项目引用包时不写版本
- **当** `.csproj` 中包含 PackageReference
- **则** PackageReference 不得包含 Version 属性
- **且** 版本应从 `Directory.Packages.props` 解析
- **除非** 该包未在 `Directory.Packages.props` 中定义（项目专用包）

### 需求：MaterialClient src/tests 目录布局下的构建脚本路径

采用 `src/` 与 `tests/` 解决方案布局的仓库（如 MaterialClient 重构后），根目录构建与打包脚本 MUST 保持有效，且项目与发布输出路径 MUST 与 `src` 布局一致。

#### 场景：Directory.Build.props 在 src 与 tests 下生效
- **当** 项目位于 `src/**` 或 `tests/**`
- **则** 根目录 `Directory.Build.props` MUST 仍被这些项目自动导入
- **且** 除非明确需要，否则不得在 `src/` 内重复放置 `Directory.Build.props`

#### 场景：Inno Setup 与 publish 路径对齐 src 布局
- **当** 维护 `MaterialClient.iss` 或 `MaterialClient.Urban.iss`
- **则** 脚本中的 `SourceDir` 与资源路径 MUST 使用 `src\<ProjectName>\...`
- **且** 脚本中的 `dotnet publish` MUST 使用 `src/<ProjectName>/<ProjectName>.csproj` 项目路径
