## Context

MaterialClient 在 `MaterialClient/Converters/` 维护 12 个 `IValueConverter` / `IMultiValueConverter` 实现，并在 `MaterialClient/App.axaml` 的 `Application.Styles` 中注册为 `x:Key` 静态资源。`MaterialClient.Urban` 仅引用 `MaterialClient.Common` 与 `MaterialClient.UI`，不引用主应用 exe 项目，因此无法使用这些转换器。

近期已建立 `MaterialClient.UI` 共享库（主题 `SharedTheme.axaml`、DeviceStatusBar 等）。转换器与主题同属跨变体 UI 基础设施，适合放入同一程序集。

Urban 主窗口右侧照片区当前为固定 emoji（🚛）占位；主应用在 `ImageViewerWindow`、`ManualMatchWindow` 等场景使用 `CarNullOrEmptyImageConverter`，在路径为空或加载失败时显示 `Car_Default.png`。

`CarNullOrEmptyImageConverter` 当前硬编码 `avares://MaterialClient/Assets/Car_Default.png`，迁移后必须改为 UI 程序集资源 URI。

## Goals / Non-Goals

**Goals:**

- Urban 与主应用可通过相同 `StaticResource` 键使用全部共享转换器
- Urban 照片区使用 `CarNullOrEmptyImageConverter` 绑定路径字符串，空/失败时显示默认车辆图
- 单一注册点（`SharedConverters.axaml`），避免双应用重复维护

**Non-Goals:**

- 不将转换器移入 `MaterialClient.Common`（Common 为非 UI 层）
- 不让 Urban 引用 `MaterialClient` 主项目
- 不统一 `PhotoGridView` 的 `NullableBitmapToImageConverter` 用法（仅保证资源可用）
- 不在本变更中实现完整照片下载管线（若 ViewModel 属性尚缺，任务中仅接线绑定与占位路径）

## Decisions

### 决策 1：转换器归属 MaterialClient.UI

**选择：** 将 `MaterialClient/Converters/*.cs` 整体迁移到 `MaterialClient.UI/Converters/`，命名空间 `MaterialClient.UI.Converters`。

**备选：**

- *留在主应用、Urban 新增 ProjectReference 到 MaterialClient：* 已否决——exe 项目不宜被另一 exe 引用，且违反变体隔离
- *放入 MaterialClient.Common：* 已否决——依赖 Avalonia、Bitmap、AssetLoader

**理由：** 与已归档的 `materialclient-urban-shared-ui-components-library` 决策一致；Urban 已引用 UI 库。

### 决策 2：SharedConverters.axaml 集中注册

**选择：** 新建 `MaterialClient.UI/Styles/SharedConverters.axaml`，在 `Style.Resources` 中注册全部转换器；两应用 `App.axaml` 增加：

```xml
<StyleInclude Source="avares://MaterialClient.UI/Styles/SharedConverters.axaml" />
```

**理由：** 与 `SharedTheme.axaml` 模式一致；键名保持不变（如 `CarNullOrEmptyImageConverter`），现有主应用 XAML 仅需调整命名空间（若局部声明）即可编译。

### 决策 3：默认车辆图随 UI 库发布

**选择：** 将 `MaterialClient/Assets/Car_Default.png` 复制到 `MaterialClient.UI/Assets/`，在 UI csproj 中 `AvaloniaResource Include="Assets\**"`；转换器常量改为 `avares://MaterialClient.UI/Assets/Car_Default.png`。

**理由：** Urban 运行时无法解析 `avares://MaterialClient/...`；资源与转换器同程序集避免跨程序集资源泄漏。

**兼容：** 主应用可保留原图副本或删除重复资源（实现阶段二选一，以 UI 程序集为唯一来源）。

### 决策 4：Urban 照片 XAML 绑定模式

**选择：** 将两个照片 `Border` 内 `TextBlock` emoji 替换为：

```xml
<Image Source="{Binding LprPhotoPath, Converter={StaticResource CarNullOrEmptyImageConverter}}"
       Stretch="UniformToFill" />
```

（摄像头区域绑定 `CameraPhotoPath` 或等价属性名，与 ViewModel 一致。）

ViewModel 在 `SelectedRecord` 变化时更新路径（从记录附件/ExtraProperties/管线字段读取，与 Urban 照片加载 spec 对齐；若字段尚未落地，可先绑定可空字符串，由转换器显示默认图）。

**理由：** 用户明确要求使用 `CarNullOrEmptyImageConverter`；与 `ManualMatchWindow` 等主应用用法一致。

### 决策 5：avares 路径前缀兼容

**选择：** `CarNullOrEmptyImageConverter` / `NullOrEmptyImageConverter` 中 `/Assets/` 相对路径前缀，除 `MaterialClient` 外增加 `MaterialClient.UI` 解析：

```csharp
path.StartsWith("/") ? new Uri($"avares://MaterialClient.UI{path}") : ...
```

或统一要求完整 `avares://` URI（实现时择一并在 tasks 中验证）。

**理由：** 避免迁移后既有 `/Assets/...` 绑定失效。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 主应用 XAML 仍引用 `MaterialClient.Converters` 命名空间 | 全局搜索替换为 `MaterialClient.UI.Converters`；编译验证 |
| 双份 `Car_Default.png` 导致资源不一致 | 以 UI 程序集为唯一来源，主应用删除重复 |
| Urban 照片路径属性未接管线，仅显示默认图 | 符合转换器设计；后续变更接下载逻辑 |
| `ProductCodeConverter` 未在 App 注册 | 迁移时一并注册，保持 API 完整 |

## Migration Plan

1. 在 `MaterialClient.UI` 添加 Converters、Assets、SharedConverters.axaml
2. 更新 UI csproj 资源项
3. 两应用 App.axaml 引入 StyleInclude，主应用删除内联转换器块
4. 删除 `MaterialClient/Converters/`，修复主应用命名空间引用
5. Urban XAML + ViewModel 接线
6. `dotnet build` MaterialClient.sln（Release/Debug）

**回滚：** 恢复 Converters 目录与 App.axaml 内联注册；Urban 恢复 emoji 占位。

## Open Questions

- Urban 记录上 LPR/摄像头图片路径的具体字段名（ExtraProperties vs AttachmentFile）——实现时以 Common 实体/管线现有字段为准，若无则 ViewModel 暂返回 `null` 由转换器显示默认图。
