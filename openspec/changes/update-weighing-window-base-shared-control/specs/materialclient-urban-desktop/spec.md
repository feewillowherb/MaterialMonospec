## MODIFIED Requirements

### Requirement: 主界面布局四行结构

MaterialClient.Urban 主界面 MUST 基于 `MaterialClient.UI` 的 `WeighingWindowBase` 共享控件构建四行结构。底部状态栏（Row 3）MUST 使用共享 `DeviceStatusBar`。标题栏样式 MUST 与 MaterialClient 主应用保持一致。

#### Scenario: 主界面布局
- **WHEN** 主界面加载完成
- **THEN** SHALL 通过 `WeighingWindowBase` 显示标题栏（Row 0, PrimaryBlue 统一风格）
- **AND** SHALL 显示重量区（Row 1, 与主应用一致的样式规范）
- **AND** SHALL 显示 Urban 内容区（Row 2, *），并支持 Urban 专用内容布局
- **AND** SHALL 显示 MaterialClient.UI `DeviceStatusBar` 控件（Row 3, Auto height）

#### Scenario: 重量区显示真实称重数据
- **WHEN** 称重管线正在运行
- **THEN** 重量区 SHALL 显示 `CurrentWeight`（由 ViewModel 绑定驱动）
- **AND** SHALL 显示 `WeightStatus` 文案和对应颜色
- **AND** SHALL NOT 显示 mock 数据

#### Scenario: 窗口配置
- **WHEN** 主界面首次显示
- **THEN** SHALL 设置窗口大小为 1280×800
- **AND** SHALL 设置最小大小为 900×600
- **AND** SHALL 居中显示在屏幕上
- **AND** SHALL 使用 `SystemDecorations="None"`（与 MaterialClient 一致）
- **AND** SHALL 设置窗口 Icon（`/Assets/fd-ico.ico`）
