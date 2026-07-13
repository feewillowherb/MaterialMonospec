# MaterialMonospec - Agent 行为准则

## 项目概述

MaterialMonospec 是一个 Monospec 主仓库，统一管理 MaterialClient（工业材料称重桌面应用）和 UrbanManagement（城市管理 Web 应用）两个子仓库的 OpenSpec 文档。所有变更的 proposal、design、specs、tasks 在主仓库中创建和管理，代码实现仍在各自的子仓库中进行。

## 子仓库 AGENTS

在 `repos/` 下编写或修改代码前，须读取对应子仓库的 `AGENTS.md`：

- `repos/MaterialClient/AGENTS.md`
- `repos/UrbanManagement/AGENTS.md`

跨子仓库 C# 约定（含 Record 替代 Tuple）见下文「跨子仓库 C# 编码约定」；实现前仍须阅读对应子仓库 `AGENTS.md`，冲突时以**更严格**者为准。

## 目录结构

```
MaterialMonospec/
├── openspec/
│   ├── changes/                          # 活动变更
│   │   └── <change-name>/               # 变更目录
│   │       ├── proposal.md
│   │       ├── design.md
│   │       ├── specs/
│   │       └── tasks.md
│   ├── changes/archive/                  # 归档变更（历史记录）
│   └── specs/                            # 规范定义（51个）
├── repos/                                # 子仓库（目录联接）
│   ├── MaterialClient/                   # Avalonia 桌面应用
│   └── UrbanManagement/                  # ABP Web 应用
├── docs/                                 # 文档（产出约定见 docs/AGENTS.md）
│   ├── AGENTS.md                         # 仅约束 docs/ 的调研产出格式
│   ├── monospecs-yaml-template.md        # 配置模板
│   ├── add-repo-guide.md                 # 添加子仓库指南
│   ├── migration-guide.md                # 迁移指南
│   └── troubleshooting.md               # 故障排除
├── scripts/                              # 工具脚本
│   ├── validate-config.ps1               # 配置验证
│   └── validate-migration.ps1            # 迁移验证
├── monospecs.yaml                        # Monospec 配置
├── PROPOSAL_DESIGN_GUIDELINES.md         # 提案设计指南
├── _bmad/                                # BMAD 配置与工作流（仅主仓库，子仓库不安装）
├── _bmad-output/                         # BMAD 规划/实现产出
├── .agents/skills/                       # Cursor BMAD skills
├── AGENTS.md                             # 本文件
└── .gitignore                            # 排除 repos/、BMAD 个人配置
```

## Monospec 工作流程

### 完整工作流概览

```
创建变更 → 编写提案 → 审查设计 → 实现代码 → 归档变更
   |           |           |           |           |
   v           v           v           v           v
 主仓库      主仓库      主仓库     子仓库      主仓库
 openspec/   proposal   design    repos/XX/   archive +
             specs      tasks     代码实现     自动提交
```

### 1. 变更创建

所有变更在主仓库中创建：

```bash
# 创建新变更
openspec create <change-name>

# 查看活动变更
openspec list

# 查看变更状态
openspec status --change <change-name> --json
```

变更命名规范：
- `add-*`：新功能
- `update-*`：更新功能
- `remove-*`：移除功能
- `refactor-*`：重构
- `fix-*`：修复

### 2. 编写提案和设计

在变更目录中编写工件：

1. **proposal.md**：说明 Why（为什么）、What Changes（变更内容）、Capabilities（能力）、Impact（影响）
2. **design.md**：技术决策、组件架构、数据流、风险和权衡
3. **specs/**：每个受影响能力的 delta spec（ADDED/MODIFIED/REMOVED）
4. **tasks.md**：实施任务清单

### 3. 规范管理

所有 specs 存储在 `openspec/specs/` 目录中：

```bash
openspec list --specs    # 查看所有 specs
```

每个 spec 目录包含 `spec.md`，定义该能力的需求（Requirements）和场景（Scenarios）。

## 子仓库代码实现流程

### 涉及 MaterialClient 的变更

1. 在主仓库创建变更提案
2. 在 `repos/MaterialClient/` 中实现代码变更
3. MaterialClient 技术栈：
   - C# 13 / .NET 10.0 / Avalonia UI 11.3.9 / ReactiveUI
   - ABP Framework / SQLite (Entity Framework Core)
   - MVVM 模式，View-ViewModel 分离
4. 代码提交和推送需在 MaterialClient 仓库中单独操作

### 涉及 UrbanManagement 的变更

1. 在主仓库创建变更提案
2. 在 `repos/UrbanManagement/` 中实现代码变更
3. UrbanManagement 技术栈：
   - ABP Framework / .NET
   - Web 应用
4. 代码提交和推送需在 UrbanManagement 仓库中单独操作

### 跨仓库变更

如果变更涉及多个子仓库：
- 在提案中明确说明每个子仓库的影响范围
- tasks.md 中分列每个子仓库的实施任务
- 代码实现分别在各自的子仓库中完成

## 变更创建和归档流程

### 创建变更

```bash
# 步骤 1：创建变更
openspec create <change-name>

# 步骤 2：编写 proposal.md
# 步骤 3：编写 design.md（如需要）
# 步骤 4：创建 specs/ 下的 delta spec
# 步骤 5：编写 tasks.md

# 步骤 6：验证变更
openspec validate <change-name> --strict
```

### 实现变更

```bash
# 在 tasks.md 指引下实现代码
# 每完成一个任务，在 tasks.md 中标记：- [ ] -> - [x]
```

### 归档变更

```bash
# 归档完成的变更
openspec archive <change-name>
```

归档行为：
- 变更目录从 `changes/<name>/` 移动到 `changes/archive/<name>/`
- 如果 `commit_when_archive: true`，specs 变更会自动提交到主仓库 Git
- **子仓库的代码变更不会自动提交**，需手动在各子仓库中提交和推送

## 配置说明

主仓库使用 `monospecs.yaml` 配置子仓库信息：

```yaml
version: "1.0"              # 配置版本（字符串）
repo_dir: repos              # 子仓库目录
commit_when_archive: true    # 归档时自动提交 specs
repositories:                # 子仓库列表
  - path: repos/MaterialClient
    url: https://github.com/feewillowherb/MaterialClient.git
    displayName: MaterialClient
    type: Desktop
    optional: false
    tags: [avalonia, industrial]
```

详细配置说明见 `docs/monospecs-yaml-template.md`。

## 子仓库项目信息

### MaterialClient

- **类型**：Windows 桌面应用（Avalonia UI）
- **技术栈**：C# 13 / .NET 10.0 / Avalonia UI 11.3.9 / ReactiveUI / ABP Framework / SQLite
- **用途**：工业环境材料称重管理，支持有人/无人值守称重
- **架构**：MVVM + DDD + 分层架构
- **详情**：参见 `PROPOSAL_DESIGN_GUIDELINES.md`

### UrbanManagement

- **类型**：Web 应用（ABP Framework）
- **技术栈**：ABP Framework / .NET
- **用途**：城市管理 Web 应用

## 跨子仓库 C# 编码约定

以下约定适用于 `repos/MaterialClient` 与 `repos/UrbanManagement` 中的 C# 代码。各子仓库 `AGENTS.md` 中有更细的本地约定。

### Record 替代 Tuple（NON-NEGOTIABLE）

- 禁止使用 C# tuple（如 `(string, int)`、`(string? a, int b)`）及 `ValueTuple` / `System.Tuple<...>` 作为**方法返回值、方法参数、局部变量类型、字段类型**。
- 多值组合应使用**命名 `record`**，例如 `record SyncResult(bool Success, string? Message)`。
- OpenSpec 的 `design.md`、API 草图及 `tasks.md` 中的方法签名不得使用 tuple；实现与文档一致使用 `record`。
- **边界**：第三方/BCL API 若返回 tuple，仅在适配层解构并立即映射为项目内 `record`，不得将 tuple 类型向上层或跨模块传播。
- 架构图或设计叙述中的 “tuple” 仅表示概念上的多值组合，实现仍须使用命名 `record`。

### 代码审查检查项

- [ ] 未使用 tuple 作为返回值、参数、局部变量或字段类型
- [ ] 多值类型为命名 `record`（DTO、值对象、查询结果等）
- [ ] OpenSpec 设计文档中的 API 签名未使用 tuple

## 代码架构约束

> **关键规则：ViewModels 不得直接使用 Repository，必须通过 Service 层访问数据。**

### Repository 访问约束

**禁止在 ViewModels 中直接使用 Repository**

- **原因**：ViewModels 无法创建和管理 UnitOfWork，直接使用 Repository 会导致事务管理问题
- **正确做法**：所有 Repository 访问必须通过 Service 层进行
- **架构层级**：View → ViewModel → Service → Repository → DbContext

### Service 层要求

**Service 方法必须使用 UnitOfWork 修饰**

- **数据变更方法**：任何涉及数据写入的 Service 方法必须使用 `[UnitOfWork]` 特性修饰
- **事务边界**：UnitOfWork 自动管理事务开始、提交和回滚
- **异常处理**：方法中的异常会自动触发事务回滚

**Service 创建规则**

- 如果需要访问 Repository 但没有对应的 Service，必须创建新的 Service 类
- Service 通过构造函数注入所需的 Repository
- Service 实现应该使用 `ITransientDependency` 或 `ISingletonDependency` 标记

### 正确与错误示例

| 场景 | ❌ 错误做法 | ✅ 正确做法 |
|------|-----------|-----------|
| ViewModel 查询数据 | `var records = await _repository.GetListAsync()` | `var records = await _myService.GetRecordsAsync()` |
| ViewModel 保存数据 | `await _repository.InsertAsync(entity)` | `await _myService.CreateRecordAsync(dto)` |
| Service 定义 | 直接在 ViewModel 中实现业务逻辑 | 创建 `IMyService` 接口和 `MyService` 实现 |
| 事务管理 | 不使用 UnitOfWork 特性 | `[UnitOfWork] public async Task CreateAsync()` |
| 数据访问模式 | ViewModel → Repository | ViewModel → Service → Repository |

### 实现示例

**正确的 Service 层实现**：

```csharp
// Service 接口
public interface IWeighingRecordService : ITransientDependency
{
    Task<List<WeighingRecord>> GetRecordsByStatusAsync(SyncStatus status);
    Task<WeighingRecord> CreateAsync(CreateWeighingRecordDto dto);
}

// Service 实现
public class WeighingRecordService : IWeighingRecordService
{
    private readonly IRepository<WeighingRecord, long> _repository;
    private readonly IUnitOfWorkManager _unitOfWorkManager;

    public WeighingRecordService(
        IRepository<WeighingRecord, long> repository,
        IUnitOfWorkManager unitOfWorkManager)
    {
        _repository = repository;
        _unitOfWorkManager = unitOfWorkManager;
    }

    [UnitOfWork]
    public async Task<List<WeighingRecord>> GetRecordsByStatusAsync(SyncStatus status)
    {
        return await _repository
            .Where(r => r.SyncStatus == status)
            .ToListAsync();
    }

    [UnitOfWork]
    public async Task<WeighingRecord> CreateAsync(CreateWeighingRecordDto dto)
    {
        var record = new WeighingRecord
        {
            PlateNumber = dto.PlateNumber,
            TotalWeight = dto.TotalWeight,
            SyncStatus = SyncStatus.Pending
        };

        await _repository.InsertAsync(record);
        return record;
    }
}
```

**正确的 ViewModel 使用**：

```csharp
public class UrbanAttendedWeighingViewModel : ViewModelBase
{
    private readonly IWeighingRecordService _weighingRecordService;

    public UrbanAttendedWeighingViewModel(IWeighingRecordService weighingRecordService)
    {
        _weighingRecordService = weighingRecordService;
    }

    public async Task LoadRecordsAsync()
    {
        // ✅ 正确：通过 Service 访问数据
        var records = await _weighingRecordService.GetRecordsByStatusAsync(SyncStatus.Pending);
        Records.AddRange(records);
    }
}
```

### 违反约束的后果

- **事务管理混乱**：直接使用 Repository 可能导致数据不一致
- **业务逻辑分散**：业务逻辑散落在 ViewModels 中，难以测试和复用
- **违反 DDD 原则**：破坏了领域驱动设计的分层架构
- **测试困难**：ViewModel 直接依赖 Repository 使得单元测试复杂化

### 检查清单

在代码审查时，确认以下内容：

- [ ] ViewModel 中没有直接注入 `IRepository<TEntity, TKey>`
- [ ] ViewModel 中没有调用 `GetListAsync()`, `InsertAsync()`, `UpdateAsync()` 等 Repository 方法
- [ ] 所有数据访问都通过相应的 Service 接口进行
- [ ] Service 中涉及数据写入的方法都使用了 `[UnitOfWork]` 特性
- [ ] Service 的构造函数只注入 Repository 和其他服务，不注入 ViewModel

## 工具和验证

```bash
# 验证配置文件
powershell -ExecutionPolicy Bypass -File scripts/validate-config.ps1

# 验证迁移完整性
powershell -ExecutionPolicy Bypass -File scripts/validate-migration.ps1

# 验证 OpenSpec 实现是否符合 AGENTS.md（归档前建议执行）
# Cursor: /opsx-verify-agents <change-name>
powershell -ExecutionPolicy Bypass -File scripts/validate-agents-implementation.ps1 `
  -ChangeName "<change-name>" `
  -FileListPath ".cursor/.opsx-verify-<change-name>-files.txt" `
  -Repos "MaterialClient,UrbanManagement"
```

## OpenSpec 生成位置约束

> **关键规则：所有 OpenSpec 工件必须且只能在 MaterialMonospec 主仓库中生成和管理。**

### 约束说明

- **唯一的 OpenSpec 根目录**：`MaterialMonospec/openspec/` 是本项目唯一的 OpenSpec 工作目录
- **禁止在子仓库中生成 OpenSpec**：不得在 `repos/` 下的任何子项目（如 `repos/MaterialClient/`、`repos/UrbanManagement/`）中创建或修改 openspec 工件（proposal、design、specs、tasks 等）
- **子仓库中已有的 openspec 目录**：`repos/` 下子仓库中可能存在历史遗留的 openspec 目录，这些不应再被使用。所有新的变更提案、设计、规范和任务都必须在主仓库的 `openspec/` 目录中创建
- **变更范围覆盖所有子仓库**：无论变更涉及 MaterialClient、UrbanManagement 还是两者，对应的 OpenSpec 工件都统一在主仓库中管理

### 正确与错误示例

| 场景 | ✅ 正确位置 | ❌ 错误位置 |
|------|-----------|-----------|
| 创建变更提案 | `MaterialMonospec/openspec/changes/add-xxx/proposal.md` | `repos/MaterialClient/openspec/changes/add-xxx/proposal.md` |
| 编写设计文档 | `MaterialMonospec/openspec/changes/add-xxx/design.md` | `repos/UrbanManagement/openspec/changes/add-xxx/design.md` |
| 管理规范定义 | `MaterialMonospec/openspec/specs/` | `repos/*/openspec/specs/` |
| 编写实施任务 | `MaterialMonospec/openspec/changes/add-xxx/tasks.md` | `repos/*/openspec/changes/add-xxx/tasks.md` |

## OpenSpec 与技术债务

> **默认规则：除非用户或当前 change 的 proposal 明确要求，否则不要在 OpenSpec 流程中处理技术债务。**

### 默认不做（无明确要求时）

在 **propose、specs、design、tasks、apply、archive** 全过程中：

- 不将技术债务清理、大范围重构、「顺手」优化写入 `proposal.md` / `design.md` / `tasks.md`
- 不借机修改与当前 change **Why / What Changes** 无关的代码、目录结构或命名
- 不在 apply 阶段以「提高质量」「统一风格」「顺便整理」为由扩大实现范围

### 仅在以下情况可包含技术债务

- 用户在对话或需求中**明确要求**处理某项技术债务；或
- **proposal.md** 的 What Changes / Capabilities / Impact 中**明确列出**该技术债务项

若技术债务工作量大或与业务变更可分离，应**单独创建 change**（如 `refactor-*`），不要塞进当前功能 change。

### 发现技术债务时

- 可在对话中**简短备注**（可选），但不要自动加入当前 change 的 tasks
- 建议用户另开 change 或记入 backlog，待显式授权后再走 OpenSpec

## 最佳实践

- 所有非平凡的变更都应通过 OpenSpec 提案流程
- **所有 OpenSpec 工件只能在主仓库 `openspec/` 中创建，禁止在 `repos/` 子项目中生成**（参见「OpenSpec 生成位置约束」）
- 跨仓库的变更应在提案中明确说明影响的子仓库
- 代码实现完成后，更新 tasks.md 中的完成状态
- 保持 specs 与代码实现同步
- 变更名称使用动词引导（add-、update-、remove-、refactor-）
- 归档前确认所有任务已完成
- 定期运行验证脚本确保配置正确
- **无明确要求时，OpenSpec 不处理技术债务**（参见「OpenSpec 与技术债务」）
- **ViewModels 不得直接使用 Repository，必须通过 Service 层访问数据**（参见「代码架构约束」）
- **禁止使用 tuple 作为 API/字段类型；多值组合使用命名 `record`**（参见「跨子仓库 C# 编码约定」）
