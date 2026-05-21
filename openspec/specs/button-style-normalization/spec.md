## ADDED Requirements

### Requirement: 主操作按钮必须通过样式类统一定义
系统中的主操作按钮 MUST 通过 MaterialClient.UI SharedTheme.axaml 中的全局样式类定义视觉样式，禁止在页面中以 `Button` 内联 `Background/Foreground` 作为主样式来源。

#### Scenario: 新增主按钮遵循类样式
- **WHEN** 开发者在页面中新增主操作按钮
- **THEN** 按钮 MUST 使用 SharedTheme.axaml 中的全局 class 定义主样式，而不是内联颜色属性

#### Scenario: 已有孤立主按钮被改造
- **WHEN** 页面存在”蓝底白字”但未使用主按钮 class 的按钮
- **THEN** 该按钮 MUST 被迁移到 SharedTheme.axaml 中的统一 class（或专用 class）并移除主样式内联颜色

### Requirement: 主按钮禁用态文字颜色必须可预测
系统 MUST 在 MaterialClient.UI SharedTheme.axaml 中为主按钮样式类定义禁用态文字规则，确保禁用时文本颜色不回落为不可控的主题默认值。

#### Scenario: primary-button 在禁用态显示统一文字颜色
- **WHEN** `primary-button` 按钮进入 `:disabled` 状态
- **THEN** 文本颜色 MUST 命中 SharedTheme.axaml 中定义的禁用态规则并在 DevTools 中可验证来源

#### Scenario: 模板层覆盖下仍保持禁用态一致
- **WHEN** 主题模板对内容呈现层（如 `ContentPresenter`/`AccessText`）存在覆盖竞争
- **THEN** 系统 MUST 通过 SharedTheme.axaml 中的模板层样式补充确保最终文字颜色一致

### Requirement: 特例主按钮必须采用专用类而非内联颜色
当页面需要区别于 `primary-button` 的品牌主按钮颜色时，系统 MUST 通过 SharedTheme.axaml 中的专用 class 承载 normal/disabled 规则，不得仅通过页面内联颜色实现。

#### Scenario: 需要品牌蓝按钮时定义专用类
- **WHEN** 页面要求主按钮颜色与标准 `primary-button` 不同（例如 `#4A85F9`）
- **THEN** 开发者 MUST 使用 SharedTheme.axaml 中的专用 class 并在其中定义 normal/disabled 行为

### Requirement: 样式定义单一来源
所有共享样式类和颜色资源 MUST 仅在 MaterialClient.UI 的 SharedTheme.axaml 中定义一次，各消费应用 MUST NOT 重复定义相同的样式规则。

#### Scenario: 无重复样式定义
- **WHEN** 检查 MaterialClient 和 MaterialClient.Urban 的 App.axaml
- **THEN** MUST NOT 包含与 SharedTheme.axaml 重复的按钮样式类定义
- **AND** MUST NOT 包含与 SharedTheme.axaml 重复的颜色资源定义

#### Scenario: 样式导入方式
- **WHEN** 消费应用需要使用共享样式
- **THEN** SHALL 通过 ResourceDictionary.MergedDictionaries 导入 SharedTheme.axaml
- **AND** MAY 在导入后添加应用特定的覆盖资源
