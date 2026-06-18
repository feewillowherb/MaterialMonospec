## Why

MaterialClient 主项目已通过 `ProjectInfoWindow` 对话框提供授权信息展示（项目名称、产品名称、到期时间、机器码、授权码），但 MaterialClient.Urban 尚无此功能。Urban 用户无法在模块内查看设备授权状态与有效期，导致两套系统的用户体验不一致。需参照主项目实现，为 Urban 补齐授权信息展示能力。

## What Changes

- 在 MaterialClient.Urban 顶部菜单栏（`WeighingWindowBase.MenuItems`）"系统设置"按钮旁新增"项目信息"按钮
- 在 MaterialClient.UI 共享层创建 `ProjectInfoWindow`（Window + ViewModel），与主项目 `ProjectInfoWindow` 功能和视觉风格一致
- 将主项目现有 `ProjectInfoWindow` / `ProjectInfoWindowViewModel` 迁移至 MaterialClient.UI，使主项目和 Urban 通过 DI 共用同一实现
- Urban 通过 `ILicenseService.GetCurrentLicenseAsync()` 获取已缓存的 `LicenseInfo` 实体（JWT 声明在启动时已提取并持久化），无需重新解析 JWT

## Capabilities

### New Capabilities
- `urban-project-info-display`: Urban 模块中通过顶部菜单"项目信息"按钮打开授权信息对话框，展示项目名称、产品名称、到期时间、机器码、授权码，数据来源为 `IAuthenticationService`、`ILicenseService`、`ISettingsService`

### Modified Capabilities
- `settings-ui`: 将 `ProjectInfoWindow` 和 `ProjectInfoWindowViewModel` 迁移至 MaterialClient.UI 共享层，参照 `SettingsWindow` 共享模式，主项目和 Urban 均通过 DI 解析使用

## Impact

### Code Change Map

| 模块 | 文件 | 变更类型 | 说明 |
|------|------|----------|------|
| MaterialClient.UI | `Views/ProjectInfoWindow.axaml` | **新增** | 从主项目迁移的项目信息窗口（500×300 固定尺寸，无边框，蓝色标题栏） |
| MaterialClient.UI | `Views/ProjectInfoWindow.axaml.cs` | **新增** | Code-behind，实现 ITransientDependency，关闭按钮处理 |
| MaterialClient.UI | `ViewModels/ProjectInfoWindowViewModel.cs` | **新增** | 从主项目迁移的 ViewModel，依赖 IAuthenticationService / ILicenseService / ISettingsService |
| MaterialClient（主项目） | `Views/ProjectInfoWindow.axaml` | **删除** | 迁移至 UI 层后移除 |
| MaterialClient（主项目） | `Views/ProjectInfoWindow.axaml.cs` | **删除** | 迁移至 UI 层后移除 |
| MaterialClient（主项目） | `ViewModels/ProjectInfoWindowViewModel.cs` | **删除** | 迁移至 UI 层后移除 |
| MaterialClient（主项目） | 称呼 ProjectInfoWindow 的代码 | **修改** | 更新 namespace 引用为 MaterialClient.UI |
| MaterialClient.Urban | `Views/UrbanAttendedWeighingWindow.axaml` | **修改** | 在 MenuItems 中"系统设置"旁添加"项目信息"按钮 |
| MaterialClient.Urban | `Views/UrbanAttendedWeighingWindow.axaml.cs` | **修改** | 添加按钮点击事件处理，从 DI 解析 ProjectInfoWindow 并 ShowDialog |

### Interaction Flow

```mermaid
flowchart TD
    U[Urban 用户] -->|点击"项目信息"| Btn[UrbanAttendedWeighingWindow 菜单按钮]
    Btn --> DI[DI 解析 ProjectInfoWindow]
    DI --> VM[ProjectInfoWindowViewModel.InitializeAsync]
    VM --> AS[IAuthenticationService.GetCurrentSessionAsync → CompanyName]
    VM --> SS[ISettingsService.GetSettingsAsync → ProductNameDisplay]
    VM --> LS[ILicenseService.GetCurrentLicenseAsync → LicenseInfo]
    LS --> LE[LicenseInfo 实体]
    LE --> LE1[ProName / AuthEndTime]
    LE --> LE2[MachineCode / AuthToken]
    VM --> WIN[ProjectInfoWindow 显示]
    WIN --> U2[用户查看授权信息]
    U2 -->|关闭| WIN
```

### ASCII Interface Prototype

```
┌──────────────────────────────────────────────┐
│  项目信息                              [✕]   │  ← 蓝色标题栏 #6498FE
├──────────────────────────────────────────────┤
│                                              │
│  项目信息:   XX建设工程有限公司              │
│                                              │
│  产品名称:   凡东城管地磅系统                  │  ← 可点击（隐藏重置功能）
│                                              │
│  到期时间:   2026-12-31                       │  ← 红色 #DC3545
│                                              │
│  机器码:     ABCD****EFGH                     │  ← 部分遮掩
│                                              │
│  授权码:     a1b2****c3d4                     │  ← 部分遮掩
│                                              │
└──────────────────────────────────────────────┘
  500 × 300, CanResize=False, 无系统装饰
```

Urban 菜单栏入口:

```
┌──────────────────────────────────────────────────┐
│  [Logo] 凡东城管地磅系统                          │
│            [项目信息]  [系统设置]                   │  ← 新增"项目信息"按钮
├──────────────────────────────────────────────────┤
│              ┌──────────┐                        │
│              │  1234.56 │  ← 称重显示区           │
│              └──────────┘                        │
├──────────────────────┬───────────────────────────┤
│  车辆记录表格         │  照片侧栏                   │
│                      │                           │
└──────────────────────┴───────────────────────────┘
```

---

## Delivery Tier

| Field | Value |
|-------|-------|
| Tier | Core |
| Role in path | 首次实现 Urban 授权信息展示能力 |
| Out of scope (vs tier ladder) | 不含异常路径全覆盖（如服务不可达时的降级 UI）、不含运行时授权状态轮询、不含授权即将过期预警 |

## Facts

- 主项目 `ProjectInfoWindow` 展示 5 个字段：项目名称（来自 `UserSession.CompanyName`）、产品名称（来自 `SystemSettings.DefaultWeighingMode`）、到期时间（来自 `LicenseInfo.AuthEndTime`）、机器码（部分遮掩）、授权码（部分遮掩）
- Urban 通过 `MaterialClientUrbanModule` 启动时已将 JWT 声明提取并存储至 `LicenseInfo` 实体（`ILicenseService.GetCurrentLicenseAsync()` 可用）
- Urban 项目引用 `MaterialClient.Common` 和 `MaterialClient.UI`，不引用主 `MaterialClient` 项目
- Urban 主窗口 `UrbanAttendedWeighingWindow` 的 `WeighingWindowBase.MenuItems` 区域当前仅有"系统设置"一个按钮
- `MaterialClient.UI` 已有共享窗口先例：`SettingsWindow`（主项目和 Urban 均通过 DI 解析使用）
- `ProjectInfoWindowViewModel` 依赖 `IAuthenticationService`、`ILicenseService`、`ISettingsService`，三者均在 Common 层定义，Urban 可直接使用
- Urban `LicenseInfo` 中无 `MachineCode` 和 `AuthToken` 字段（JWT 声明不含此二项），该两字段在 Urban 中将显示为空或隐藏

## Assumptions

| ID | Assumption | L-level | Risk | Off-switch / degrade |
|----|------------|---------|------|----------------------|
| A-01 | Urban `LicenseInfo` 中 `MachineCode` 和 `AuthToken` 始终为空，Urban 版 ProjectInfoWindow 可隐藏或留空这两个字段 | L2 | 1×2×1=2 | 显示为空文本，不隐藏行；后续可按需调整 |
| A-02 | 产品名称隐藏重置功能（20 次点击清除授权数据）在 Urban 版中保留 | L1 | 1×1×1=1 | 移除该功能不影响核心显示 |
| A-03 | ProjectInfoWindow 迁移至 MaterialClient.UI 后主项目 namespace 引用更新不会引入编译或运行时问题 | L1 | 1×1×2=2 | 回退迁移，恢复主项目原始文件 |

## Decisions Needed

- **D-01**: `MachineCode` 和 `AuthToken` 在 Urban 中无数据，选择处理方式： (a) 隐藏对应行，(b) 显示为空文本，(c) 替换为 Urban 特有字段（如施工许可证号 `BuildLicenseNo`、对接码 `FdBuildLicenseNo`）

## Guess Governance Summary

| Guess Count | Guess Ratio | High-risk (≥40) | Validation plan | Rollback | Degrade |
|-------------|-------------|-----------------|-----------------|----------|---------|
| 3 | 3/7 = 43% | 0 | D-01 确认后降至 ≤20% | 恢复迁移前的原始文件 | MachineCode/AuthToken 留空不隐藏 |
