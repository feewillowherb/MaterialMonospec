## Why

`UrbanAttendedWeighingWindow.axaml` 左侧称重记录列表的分页栏当前仅提供「上一页」和「下一页」两个导航按钮。在大量记录场景下（如数百条异常记录积压），操作员需要逐页点击才能到达目标页码，操作效率低下。新增「首页」、「尾页」导航按钮以及页码输入跳转功能，使操作员可以一键到达任意页码，显著提升列表浏览效率。

## What Changes

- **UrbanAttendedWeighingWindow.axaml**: 在现有分页栏中新增「首页」和「尾页」按钮，以及页码输入框和「跳转」按钮
- **UrbanAttendedWeighingViewModel.cs**: 新增 `GoToFirstPageCommand`、`GoToLastPageCommand`、`GoToPageCommand` 导航命令

## Capabilities

### New Capabilities
- `list-pagination-enhancement`: 在称重记录列表分页栏中提供首页/尾页/页码跳转导航能力

### Modified Capabilities
_无_（现有分页逻辑 `PreviousPageCommand`/`NextPageCommand` 保持不变）

## Impact

### File Change Map

| File | Module | Change Type | Rationale |
|------|--------|-------------|-----------|
| `Views/UrbanAttendedWeighingWindow.axaml` | MaterialClient.Urban | **修改** | 分页栏新增首页/尾页按钮 + 页码输入跳转控件 |
| `ViewModels/UrbanAttendedWeighingViewModel.cs` | MaterialClient.Urban | **修改** | 新增首页/尾页/跳转页命令，复用现有 `ReloadRecordsAsync` 数据加载 |

### ASCII Interface Prototype

```
修改前:
┌─────────────────────────────────────────────────────────────┐
│  共 180 条  第 3 / 9 页              [上一页] [下一页]       │
└─────────────────────────────────────────────────────────────┘

修改后:
┌──────────────────────────────────────────────────────────────────────┐
│  共 180 条  第 3 / 9 页   [首页][上一页][下一页][尾页]  [  5  ][跳转]│
└──────────────────────────────────────────────────────────────────────┘
```

### Interaction Flow

```mermaid
flowchart TD
    A[操作员在列表分页栏操作] --> B{操作类型}

    B -->|点击"首页"| C[GoToFirstPageCommand<br/>CurrentPage = 1<br/>ReloadRecordsAsync]
    B -->|点击"上一页"| D[PreviousPageCommand<br/>CurrentPage--<br/>ReloadRecordsAsync]
    B -->|点击"下一页"| E[NextPageCommand<br/>CurrentPage++<br/>ReloadRecordsAsync]
    B -->|点击"尾页"| F[GoToLastPageCommand<br/>CurrentPage = TotalPages<br/>ReloadRecordsAsync]
    B -->|输入页码+跳转| G[GoToPageCommand<br/>验证范围 1..TotalPages<br/>CurrentPage = 输入值<br/>ReloadRecordsAsync]

    C --> H[列表刷新显示对应页数据]
    D --> H
    E --> H
    F --> H
    G --> H
```

### Architecture Overview

```mermaid
graph LR
    subgraph "MaterialClient.Urban"
        UAWV[UrbanAttendedWeighingViewModel<br/>分页状态: CurrentPage/TotalPages<br/>导航命令]
        UAWVAX[UrbanAttendedWeighingWindow.axaml<br/>分页栏 UI]
        UAWV -->|数据绑定| UAWVAX

        subgraph "新增命令"
            GF[GoToFirstPageCommand]
            GL[GoToLastPageCommand]
            GP[GoToPageCommand]
        end

        UAWVAX -->|绑定| GF
        UAWVAX -->|绑定| GL
        UAWVAX -->|绑定| GP

        UAWV -->|调用| GF
        UAWV -->|调用| GL
        UAWV -->|调用| GP

        GF -->|ReloadRecordsAsync| SVC[IUrbanWeighingExtensionService]
        GL -->|ReloadRecordsAsync| SVC
        GP -->|ReloadRecordsAsync| SVC
    end
```

### API Sequence: 分页导航调用流程

```mermaid
sequenceDiagram
    participant Op as 操作员
    participant View as UrbanAttendedWeighingWindow
    participant VM as UrbanAttendedWeighingViewModel
    participant SVC as IUrbanWeighingExtensionService

    Note over View,VM: 现有分页栏结构: "共 N 条 第 X / Y 页 [上一页] [下一页]"

    Op->>View: 点击"首页"
    View->>VM: GoToFirstPageCommand
    VM->>VM: CurrentPage = 1
    VM->>SVC: ReloadRecordsAsync(PageIndex=1)
    SVC-->>VM: 返回第 1 页数据
    VM->>VM: 更新 ListItems, TotalCount, TotalPages
    VM-->>View: 属性变更通知

    Op->>View: 输入 "5" + 点击"跳转"
    View->>VM: GoToPageCommand(5)
    VM->>VM: 验证 1 ≤ 5 ≤ TotalPages
    VM->>VM: CurrentPage = 5
    VM->>SVC: ReloadRecordsAsync(PageIndex=5)
    SVC-->>VM: 返回第 5 页数据
    VM-->>View: 属性变更通知
```
