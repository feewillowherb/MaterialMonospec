## MODIFIED Requirements

### Requirement: Urban 应用启动进入唯一主界面

MaterialClient.Urban 应用启动时 MUST 直接显示称重主界面（WeighingSystemWindow），MUST NOT 显示登录窗口或授权窗口。启动完成后 SHALL 初始化称重管线服务。

#### Scenario: 正常启动流程
- **WHEN** 用户启动 MaterialClient.Urban 应用
- **THEN** SHALL 直接显示称重主界面（1280×800）
- **AND** SHALL NOT 显示登录窗口
- **AND** SHALL NOT 显示授权窗口
- **AND** SHALL 记录授权检查结果到日志（Debug 模式）
- **AND** SHALL 注册并启动 UrbanWeighingService

#### Scenario: 启动失败处理（TODO：默认成功，此场景暂不触发）
- **WHEN** 静态授权检查失败（TODO：当前实现默认返回成功，此场景不会触发）
- **THEN** SHALL 记录错误日志
- **AND** SHALL 继续启动应用（不阻止用户使用）

### Requirement: 主界面布局四行结构

MaterialClient.Urban 主界面 MUST 采用四行布局：标题栏 / 重量区 / 列表+照片侧栏 / 设备状态栏。重量区数据 SHALL 由称重管线实时驱动。

#### Scenario: 主界面布局
- **WHEN** 主界面加载完成
- **THEN** SHALL 显示标题栏（高度 48px，包含logo、标题、最小化、关闭按钮）
- **AND** SHALL 显示重量区（高度 72px，绑定 CurrentWeight 和 WeightStatus）
- **AND** SHALL 显示列表+照片侧栏（剩余空间，左侧记录列表、右侧照片显示）
- **AND** SHALL 显示设备状态栏（高度 36px，显示设备在线状态）

#### Scenario: 重量区显示真实称重数据
- **WHEN** 称重管线正在运行
- **THEN** 重量区 SHALL 显示 CurrentWeight（由 ViewModel 绑定驱动）
- **AND** SHALL 显示 WeightStatus 文案和对应颜色
- **AND** SHALL NOT 显示 mock 数据
