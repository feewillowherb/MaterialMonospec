## Why

`MaterialClient` 主应用在 `App.axaml` 中注册了 11 个 Avalonia 值转换器（`MaterialClient/Converters/`），但 `MaterialClient.Urban` 未引用主应用项目，无法在 XAML 中使用这些转换器。Urban 右侧照片区目前用静态 emoji 占位，与主应用通过 `CarNullOrEmptyImageConverter` 显示默认车辆图的行为不一致。在已有 `MaterialClient.UI` 共享 UI 库的基础上，应将转换器提升为跨变体共享资源，并统一 Urban 照片绑定。

## What Changes

- 将 `MaterialClient/Converters/` 下全部 12 个转换器类迁移至 `MaterialClient.UI/Converters/`，命名空间改为 `MaterialClient.UI.Converters`
- 在 `MaterialClient.UI` 新增 `Styles/SharedConverters.axaml`，集中注册所有转换器为应用级静态资源
- `MaterialClient` 与 `MaterialClient.Urban` 的 `App.axaml` 通过 `StyleInclude` 引入 `SharedConverters.axaml`，移除主应用内联转换器注册
- 将 `Car_Default.png` 默认车辆图作为 `MaterialClient.UI` 的 `AvaloniaResource`，并更新 `CarNullOrEmptyImageConverter` 的 `avares://` URI
- Urban `UrbanAttendedWeighingWindow.axaml`：车牌识别抓拍、摄像头抓拍区域改为 `Image` + `CarNullOrEmptyImageConverter` 绑定
- Urban ViewModel 暴露照片路径属性（绑定选中记录的 LPR/摄像头图片路径），与主应用路径解析逻辑对齐

## Capabilities

### New Capabilities

- `shared-value-converters`: MaterialClient.UI 中的共享 Avalonia 值转换器及 `SharedConverters.axaml` 资源字典，供 MaterialClient 与 MaterialClient.Urban 消费

### Modified Capabilities

- `shared-ui-project`: 扩展共享 UI 项目规范，要求包含转换器资源字典与默认图片资源
- `materialclient-urban-desktop`: 照片显示区域在无有效路径时使用 `CarNullOrEmptyImageConverter` 默认车辆图，而非 emoji 占位

## Impact

**受影响的代码（MaterialClient 子仓库）：**

- `MaterialClient.UI/` — 新增 `Converters/`、`Styles/SharedConverters.axaml`、`Assets/Car_Default.png`
- `MaterialClient/App.axaml` — 改为引用共享转换器，删除内联注册
- `MaterialClient/Converters/` — 删除（迁移至 UI 库）
- `MaterialClient.Urban/App.axaml` — 引入 `SharedConverters.axaml`
- `MaterialClient.Urban/Views/UrbanAttendedWeighingWindow.axaml` — 照片 `Image` 绑定
- `MaterialClient.Urban/ViewModels/UrbanAttendedWeighingViewModel.cs` — 照片路径属性与选中记录联动

**依赖关系：**

- 无新 NuGet 包；`MaterialClient.UI` 已引用 `MaterialClient.Common`（转换器依赖 `PathManager` 等）
- 主应用 XAML 中 `xmlns:converters` 命名空间需更新为 `MaterialClient.UI.Converters`（若窗口级引用）

**非目标：**

- 不迁移 `PhotoGridView` 或重构主应用称重窗口布局
- 不改变 `MaterialClient.Demo`（超出 Urban/主应用范围，除非构建失败需最小修复）
