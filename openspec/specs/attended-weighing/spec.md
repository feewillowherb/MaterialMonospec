# 有人值守称重 规范

## 目的
待定 - 由变更 refactor-weighing-item-navigation 归档后创建。归档后更新目的。

## 需求

### 需求：操作后的条目导航

系统应在执行操作（保存、完成、匹配、作废）后，提供一致的、指向 WeighingListItemDto 的导航。

#### 场景：完成操作后的导航
- **WHEN** 用户在 AttendedWeighingDetailView 中将运单完成（首磅 → 已完成）
- **THEN** 系统应：
  - 刷新列表数据以反映已完成状态
  - 按以下优先级选择下一个条目：
    1. 优先选择下一个未完成的 Waybill（ItemType=Waybill, OrderType≠Completed）
    2. 若无未完成 Waybill，选择下一个未完成的 WeighingRecord（ItemType=WeighingRecord, OrderType≠Completed）
    3. 仅当所有条目均已完成时，选择最新已完成项
  - 若选中的是未完成项，在 AttendedWeighingDetailView 中打开该条目供继续操作
  - 若选中的是已完成项（fallback），在 AttendedWeighingMainView 中显示
  - 若目标条目不在当前页，则导航到正确页码
  - 遵循标签页切换规则（尊重 IsShowAllRecords 标志）

#### 场景：完成操作后存在未完成 Waybill
- **WHEN** 用户完成一个运单
- **AND** 列表中存在其他 OrderType≠Completed 的 Waybill
- **THEN** 系统应选择第一个未完成的 Waybill
- **AND** 在 AttendedWeighingDetailView 中打开该 Waybill

#### 场景：完成操作后无未完成 Waybill 但存在未完成 WeighingRecord
- **WHEN** 用户完成一个运单
- **AND** 列表中不存在未完成的 Waybill
- **AND** 列表中存在 OrderType≠Completed 的 WeighingRecord
- **THEN** 系统应选择第一个未完成的 WeighingRecord
- **AND** 在 AttendedWeighingDetailView 中打开该 WeighingRecord

#### 场景：完成操作后所有条目均已完成
- **WHEN** 用户完成一个运单
- **AND** 列表中不存在任何未完成的 Waybill 或 WeighingRecord
- **THEN** 系统应选择最新已完成项
- **AND** 在 AttendedWeighingMainView 中显示

#### 场景：保存操作后的导航
- **当** 用户在 AttendedWeighingDetailView 中保存称重记录或运单的修改
- **则** 系统应：
  - 刷新列表数据以反映保存后的变更
  - 在列表中保持已保存条目为选中状态
  - 保持在 AttendedWeighingDetailView（允许继续编辑）
  - 保持当前标签页（条目状态未变）
  - 若因排序导致条目移动，则导航到正确页码

#### 场景：匹配操作后的导航
- **当** 用户手动将一条称重记录与另一条记录匹配
- **则** 系统应：
  - 刷新列表数据以显示新生成的运单
  - 在列表中选中下一个未匹配条目
  - 在 AttendedWeighingDetailView 中显示下一个未匹配条目
  - 若当前在“已完成”标签且未显示全部记录，则切换到“未匹配”标签
  - 导航到下一个条目所在页

#### 场景：作废操作后的导航
- **当** 用户作废（删除）一条称重记录
- **则** 系统应：
  - 刷新列表数据以移除已作废记录
  - 在列表中选中下一个未匹配条目
  - 在 AttendedWeighingDetailView 中显示下一个未匹配条目
  - 保持当前标签页（条目被移除，未移动）
  - 导航到下一个条目所在页

### 需求：标签页切换规则

系统应实现尊重用户上下文的智能标签页切换，仅在必要时切换。

#### 场景：标签切换尊重“全部记录”模式
- **当** IsShowAllRecords 为 true（用户选择了“全部记录”标签）
- **则** 系统在任何操作后均不得自动切换标签
- **因为** 该标签下所有条目均可见，与完成状态无关

#### 场景：条目变为已完成时的标签切换
- **当** 某条目变为已完成（OrderType 变为 Completed）
- **且** IsShowUnmatched 为 true（用户在“未匹配”标签）
- **且** IsShowAllRecords 为 false
- **则** 系统应切换到 IsShowCompleted = true（“已完成”标签）

#### 场景：条目变为未匹配时的标签切换
- **当** 某条目变为未匹配（OrderType 变为 FirstWeight 或 Unmatch）
- **且** IsShowCompleted 为 true（用户在“已完成”标签）
- **且** IsShowAllRecords 为 false
- **则** 系统应切换到 IsShowUnmatched = true（“未匹配”标签）

#### 场景：当前标签已包含目标条目时不切换标签
- **当** 操作完成且结果条目的状态与当前标签筛选一致
- **则** 系统不得切换标签
- **示例**：用户在“已完成”标签下保存已完成的运单 → 保持在“已完成”标签

### 需求：跨页条目导航

系统应能查找并导航到分页边界之外的条目。

#### 场景：目标条目在当前页
- **当** 操作后导航到目标条目
- **且** 目标条目在当前页
- **则** 系统应：
  - 不翻页即选中该条目
  - 在 O(1) 时间内完成导航

#### 场景：目标条目在其他页
- **当** 操作后导航到目标条目
- **且** 目标条目不在当前页
- **则** 系统应：
  - 从第 1 页起跨页搜索
  - 导航到包含目标条目的页
  - 找到后选中该条目
  - 最多搜索 10 页，避免过度加载

#### 场景：搜索后未找到条目
- **当** 操作后导航到目标条目
- **且** 在可用页中搜索后仍无法找到目标条目
- **则** 系统应：
  - 回退为选中当前列表的第一条
  - 记录关于缺失条目的警告日志
  - 不向用户显示错误（优雅降级）

### 需求：按条目状态选择视图

系统应根据条目的类型与完成状态自动选择合适视图（MainView 或 DetailView）。

#### 场景：已完成运单在 MainView 中显示
- **当** 导航到的条目为运单（Waybill）
- **且** 运单的 OrderType 为 Completed
- **则** 系统应显示 AttendedWeighingMainView（只读摘要视图）

#### 场景：可编辑条目在 DetailView 中显示
- **当** 导航到的条目不是已完成的运单
- **示例**：未匹配的 WeighingRecord、OrderType = FirstWeight 的运单
- **则** 系统应显示 AttendedWeighingDetailView（可编辑表单视图）

#### 场景：完成操作后的视图选择
- **当** 用户完成运单（将 OrderType 从 FirstWeight 改为 Completed）
- **则** 系统应从 AttendedWeighingDetailView 切换到 AttendedWeighingMainView
- **因为** 条目已变为只读，适合在 MainView 中查看

### 需求：操作事件上下文

系统应在操作事件中提供完整上下文信息，以支持正确导航。

#### 场景：事件参数包含操作上下文
- **当** 在 AttendedWeighingDetailView 中完成某操作（保存、完成、匹配、作废）
- **则** 触发的事件应包含：
  - ItemId：结果条目的 ID
  - ItemType：条目是 WeighingRecord 还是 Waybill
  - OrderType：当前订单类型（Unmatch、FirstWeight、Completed）
  - IsCompleted：用于快速判断完成状态的布尔标志
  - OperationType：标识所执行操作的字符串

#### 场景：完成操作事件
- **当** 用户成功完成运单
- **则** 应触发 CompleteCompleted 事件，且包含：
  - ItemId = 运单 ID
  - ItemType = Waybill
  - OrderType = Completed
  - IsCompleted = true
  - OperationType = "Complete"

#### 场景：保存操作事件
- **当** 用户保存对记录或运单的修改
- **则** 应触发 SaveCompleted 事件，且包含：
  - ItemId = 已保存条目的 ID
  - ItemType = 条目当前类型
  - OrderType = 条目当前订单类型
  - IsCompleted = 根据 OrderType 得出
  - OperationType = "Save"

### 需求：统一导航逻辑

系统应使用单一统一方法处理所有操作后导航，以保证一致性。

#### 场景：所有操作均使用 NavigateToItemAsync
- **当** 任一操作事件处理被触发（保存、完成、匹配、作废、手动匹配）
- **则** 处理程序应调用统一的 NavigateToItemAsync 方法
- **且** NavigateToItemAsync 应负责：
  - 数据刷新
  - 是否切换标签的决策
  - 页码导航
  - 条目选中
  - 视图选择

#### 场景：导航逻辑可预测且可测
- **当** 测试导航行为时
- **则** 所有导航路径均应经过 NavigateToItemAsync
- **从而** 实现单点测试与维护
- **并** 保证各操作行为一致

### 需求：车牌颜色优先级匹配

系统应实现基于优先级的车牌号选择机制：被筛选的车牌颜色视为最低优先级，而非直接拒绝。

#### 场景：高优先级车牌覆盖低优先级车牌
- **假设** 地磅上为黄牌（低优先级颜色）车辆
- **且** 该车牌已被识别 10 次（缓存中 count=10）
- **当** 同时检测到蓝牌（高优先级颜色）车辆一次
- **则** 系统应选择蓝牌为最常出现车牌号
- **且** 黄牌保留在缓存中但不被选中

#### 场景：无高优先级时使用低优先级车牌
- **假设** 地磅上为黄牌（低优先级颜色）车辆
- **且** 未检测到其他车牌
- **当** 系统选择最常出现车牌号
- **则** 系统应返回该黄牌
- **且** 记录说明正在使用低优先级车牌的日志

#### 场景：低优先级车牌不能覆盖已有高优先级车牌
- **假设** 蓝牌（高优先级颜色）车辆已缓存且 count=1
- **当** 黄牌（低优先级颜色）被识别 100 次
- **则** 系统应继续返回蓝牌
- **且** 黄牌在缓存中累加 count 但不被选中

#### 场景：无颜色信息的车牌视为高优先级
- **假设** 识别的车牌无颜色信息（colorType 为 null）
- **当** 该车牌被缓存
- **则** 系统应默认将其视为高优先级
- **且** 其应能覆盖低优先级车牌

### 需求：车牌号缓存颜色跟踪

系统应在缓存中随车牌号存储颜色信息，以支持按优先级选择。

#### 场景：缓存中持久化颜色信息
- **假设** 某车牌被识别且颜色类型为 YELLOW
- **当** 该车牌加入缓存
- **则** 缓存记录应包含：
  - Count：识别次数
  - LastUpdateTime：最近一次识别时间戳
  - ColorType：YELLOW（检测到的颜色）

#### 场景：增加 count 时保留颜色信息
- **假设** 车牌“京A12345”颜色为 BLUE，已缓存且 count=1
- **当** 同一车牌再次以 BLUE 被识别
- **则** 缓存记录应更新为：
  - Count：2（递增）
  - LastUpdateTime：（更新为当前时间）
  - ColorType：BLUE（与首次识别一致）

#### 场景：缓存处理缺失的颜色信息
- **假设** 某车牌被识别但无颜色信息（colorType 为 null）
- **当** 该车牌加入缓存
- **则** 缓存记录应将 ColorType 存为 null
- **且** 该车牌应被视为高优先级

### 需求：车牌颜色优先级配置

系统应支持将特定车牌颜色配置为低优先级，将其视为备选而非完全拒绝。

#### 场景：低优先级颜色带标志存储
- **假设** 配置在 LowPriorityPlateColors 数组中指定了 YELLOW
- **当** 通过 OnPlateNumberRecognized 识别到黄牌
- **则** 系统不得拒绝该车牌
- **且** 应将其以 ColorType=YELLOW 存入缓存
- **且** 应在选择逻辑中将其标记为低优先级
- **且** 记录检测到低优先级颜色的日志

#### 场景：普通颜色按高优先级存储
- **假设** 配置在 LowPriorityPlateColors 数组中指定了 YELLOW
- **当** 通过 OnPlateNumberRecognized 识别到蓝牌
- **则** 系统应将其以 ColorType=BLUE 存入缓存
- **且** 在选择逻辑中标记为高优先级
- **且** 不记录与优先级相关的日志

#### 场景：配置加载使用新键名
- **假设** appsettings.json 包含 LowPriorityPlateColors 数组
- **当** AttendedWeighingService 启动
- **则** 系统应从配置键 LowPriorityPlateColors 加载颜色
- **且** 存入 _lowPriorityPlateColors HashSet
- **且** 用于区分低优先级与高优先级车牌
- **且** 在初始化时记录低优先级颜色日志

### 需求：配置键重命名

系统应使用 LowPriorityPlateColors 作为配置键名，以体现基于优先级的语义，而非基于拒绝的筛选。

#### 场景：使用新配置键加载
- **假设** 配置文件包含 LowPriorityPlateColors 键
- **当** AttendedWeighingService 初始化
- **则** 系统应从 LowPriorityPlateColors 键读取车牌颜色
- **且** 不得从旧键 FilteredPlateColors 读取
- **且** 在初始化时记录“低优先级车牌颜色：[列表]”

#### 场景：变量命名体现优先级语义
- **假设** 服务代码使用内部变量表示车牌颜色优先级
- **则** 变量应命名为 _lowPriorityPlateColors（而非 _filteredPlateColors）
- **且** 所有日志应使用“低优先级”术语
- **且** 代码注释应引用基于优先级的行为

### 需求：系统必须将文件路径以相对路径存储以实现数据库可移植性

系统应在数据库中使用相对路径（相对于应用程序根目录）存储文件路径，以便在不同服务器或目录间迁移数据库时不破坏文件引用。

**上下文**：当数据库文件迁移到新服务器或目录（例如从 `D:\MaterialClient\` 到 `E:\Apps\MaterialClient\`）时，绝对路径如 `D:\MaterialClient\Photos\car.jpg` 会失效。相对路径如 `Photos/car.jpg` 在迁移后仍然有效。

**实现约束**：适用于数据库中存储的所有 `AttachmentFile.LocalPath` 值。

#### 场景：照片路径以相对路径存储
**假设** 应用程序运行目录为 `D:\MaterialClient\`  
**当** 拍摄并保存照片到 `D:\MaterialClient\Photos\2026\01\23\bill.jpg`  
**则** 数据库中 `AttachmentFile.LocalPath` 必须存储 `"Photos/2026/01/23/bill.jpg"`（相对路径）  
**且** 不得存储 `"D:\MaterialClient\Photos\2026\01\23\bill.jpg"`（绝对路径）

#### 场景：数据库迁移到新位置
**假设** 数据库中存在 `AttachmentFile`，且 `LocalPath = "Photos/2026/01/23/car.jpg"`  
**且** 数据库文件从 `D:\MaterialClient\` 复制到 `E:\NewLocation\`  
**且** `Photos` 文件夹也复制到 `E:\NewLocation\Photos\`  
**当** 应用程序从 `E:\NewLocation\` 运行  
**则** `E:\NewLocation\Photos\2026/01/23/car.jpg` 处的照片必须能成功加载  
**且** 无需在数据库中更新路径

#### 场景：已有绝对路径仍可用
**假设** 数据库中存在旧版 `AttachmentFile`，且 `LocalPath = "D:\MaterialClient\Photos\car.jpg"`（绝对路径）  
**当** 应用程序从 `D:\MaterialClient\` 运行  
**则** 该照片仍须能成功加载  
**且** 之后新拍摄的照片必须使用相对路径

---

### 需求：图片转换器必须在加载前规范化路径

图片转换器在检查文件存在及加载图片前，应将相对路径规范化为绝对路径，以确保无论应用程序启动时的工作目录如何，图片都能正确显示。

**上下文**：当应用程序从 `C:\Windows\System32` 启动（例如通过任务计划程序）时，未规范化的数据库相对路径会错误地解析为 `C:\Windows\System32\Photos\...`。

**实现约束**：适用于整个 UI 中使用的 `CarNullOrEmptyImageConverter` 与 `NullOrEmptyImageConverter`。

#### 场景：从 System32 启动时从相对路径加载图片
**假设** 应用程序从 `C:\Windows\System32\` 启动  
**且** 数据库中存在 `AttachmentFile`，且 `LocalPath = "Photos/2026/01/23/car.jpg"`  
**当** UI 使用 `CarNullOrEmptyImageConverter` 显示图片  
**则** 转换器必须将路径规范化为 `{AppContext.BaseDirectory}\Photos\2026\01\23\car.jpg`  
**且** 图片必须成功显示  
**且** 不得尝试从 `C:\Windows\System32\Photos\2026\01\23\car.jpg` 加载

#### 场景：从绝对路径加载图片（向后兼容）
**假设** 数据库中存在旧版 `AttachmentFile`，且 `LocalPath = "D:\MaterialClient\Photos\car.jpg"`（绝对路径）  
**当** UI 尝试显示该图片  
**则** 转换器必须识别路径已是绝对路径  
**且** 直接使用、不做修改  
**且** 图片必须成功显示

#### 场景：文件缺失时显示默认图
**假设** 数据库中存在 `AttachmentFile`，且 `LocalPath = "Photos/missing.jpg"`  
**且** `{AppContext.BaseDirectory}\Photos\missing.jpg` 处不存在该文件  
**当** UI 尝试显示该图片  
**则** 转换器必须显示默认车辆图片占位符  
**且** 不得抛出异常

#### 场景：资源路径单独处理
**假设** ViewModel 提供资源路径 `"avares://MaterialClient/Assets/Car_Default.png"`  
**当** UI 使用 `CarNullOrEmptyImageConverter` 显示图片  
**则** 转换器必须识别为资源路径  
**且** 从嵌入资源加载  
**且** 不进行文件路径规范化

---

### 需求：系统必须提供统一的 PathManager 工具

系统应提供集中的 `PathManager` 工具，包含双向路径转换方法（`ToAbsolutePath`、`ToRelativePath`）及文件操作辅助方法，确保各服务中的路径处理一致。

**上下文**：路径转换逻辑曾分散在 `DatabaseConnectionStringFactory`、`AttachmentPathUtils` 及服务代码中。集中该逻辑可减少重复并保证一致性。

**实现约束**：`PathManager` 须为 `MaterialClient.Common/Utils/` 命名空间下的静态工具类，遵循项目中与配置无关的工具逻辑约定。

#### 场景：为文件操作将相对路径转为绝对路径
**假设** 应用程序根目录为 `D:\MaterialClient\`  
**当** 调用 `PathManager.ToAbsolutePath("Photos/2026/01/23/car.jpg")`  
**则** 必须返回 `"D:\MaterialClient\Photos\2026\01\23\car.jpg"`  
**且** 路径必须完全规范化（无 `..` 或多余斜杠）

#### 场景：为数据库存储将绝对路径转为相对路径
**假设** 应用程序根目录为 `D:\MaterialClient\`  
**当** 调用 `PathManager.ToRelativePath("D:\MaterialClient\Photos\2026\01\23\car.jpg")`  
**则** 必须返回 `"Photos\2026\01\23\car.jpg"`

#### 场景：幂等转换（已是绝对路径）
**假设** 绝对路径为 `"D:\MaterialClient\Photos\car.jpg"`  
**当** 调用 `PathManager.ToAbsolutePath("D:\MaterialClient\Photos\car.jpg")`  
**则** 必须原样返回输入：`"D:\MaterialClient\Photos\car.jpg"`

#### 场景：幂等转换（已是相对路径）
**假设** 相对路径为 `"Photos/car.jpg"`  
**当** 调用 `PathManager.ToRelativePath("Photos/car.jpg")`  
**则** 必须原样返回输入：`"Photos/car.jpg"`

#### 场景：应用程序目录外的路径保持为绝对路径
**假设** 绝对路径为 `"C:\Users\Admin\Desktop\export.pdf"`（在应用程序目录外）  
**当** 调用 `PathManager.ToRelativePath("C:\Users\Admin\Desktop\export.pdf")`  
**则** 必须原样返回输入（无法转为相对路径）  
**且** 返回 `"C:\Users\Admin\Desktop\export.pdf"`

#### 场景：带路径规范化的文件存在检查
**假设** 应用程序根目录为 `D:\MaterialClient\`  
**且** 文件存在于 `D:\MaterialClient\Photos\car.jpg`  
**当** 调用 `PathManager.FileExists("Photos/car.jpg")`  
**则** 必须在内部规范化为绝对路径  
**且** 返回 `true`

#### 场景：带路径规范化的目录创建
**假设** 应用程序根目录为 `D:\MaterialClient\`  
**当** 调用 `PathManager.EnsureDirectoryExists("Photos/2026/01/23")`  
**则** 必须在 `D:\MaterialClient\Photos\2026\01\23\` 创建目录  
**且** 返回绝对路径 `"D:\MaterialClient\Photos\2026\01\23"`  
**且** 创建所有缺失的父目录

### 需求：台账管理对话框按模式路由

系统 SHALL 根据当前 WeighingMode 决定"台账管理"按钮打开的对话框类型。

#### 场景：标准模式打开标准台账对话框
- **WHEN** 用户在 `AttendedWeighingWindow` 中点击"台账管理"按钮
- **AND WHEN** 当前 `WeighingMode` 为 Standard
- **THEN** 系统 SHALL 创建 `StandardDataManagementDialogViewModel` 并打开 `StandardDataManagementDialogWindow`

#### 场景：固废模式打开固废台账对话框
- **WHEN** 用户在 `AttendedWeighingWindow` 中点击"台账管理"按钮
- **AND WHEN** 当前 `WeighingMode` 为 SolidWaste
- **THEN** 系统 SHALL 创建 `DataManagementDialogViewModel` 并打开 `DataManagementDialogWindow`（保持现有行为不变）

### 需求：关闭车牌重写时称重记录创建使用锁定车牌
当 `WeighingConfiguration.EnablePlateRewrite = false` 时，系统在创建称重记录时 MUST 使用“当前推荐车牌”的锁定结果（基于 `finalPlateNumber` 的 `LockedAt` 规则）作为 `WeighingRecord.PlateNumber` 的初始值，从而保证同一称重周期内称重记录车牌稳定。

#### Scenario: 创建称重记录时使用锁定车牌
- **WHEN** 系统进入称重记录创建流程
- **AND WHEN** `EnablePlateRewrite = false`
- **AND WHEN** 当前存在可用的锁定车牌候选（`LockedAt != null`）
- **THEN** 系统 MUST 将 `LockedAt` 最早的车牌作为称重记录的 `PlateNumber`

#### Scenario: 无锁定候选时使用原有推荐规则
- **WHEN** 系统进入称重记录创建流程
- **AND WHEN** `EnablePlateRewrite = false`
- **AND WHEN** 当前不存在任何锁定车牌候选
- **THEN** 系统 MUST 退回到原有的推荐车牌选择逻辑来决定 `PlateNumber`

### Requirement: Newly created selection entities SHALL be locally queryable immediately
在人工称重流程中，用户新增 `Material` 或 `Provider` 成功后，系统 MUST 保证该记录已写入本地数据库，以便同一会话中的列表加载、搜索和再次打开选择框时可立即命中。

#### Scenario: Immediate re-query after creating provider
- **WHEN** 用户在人工称重界面新增 Provider 成功后立即触发 Provider 列表查询
- **THEN** 查询结果 MUST 包含该新建 Provider（无需等待后台轮询同步）

#### Scenario: Immediate re-query after creating material
- **WHEN** 用户在人工称重界面新增 Material 成功后立即触发 Material 列表查询
- **THEN** 查询结果 MUST 包含该新建 Material（无需等待后台轮询同步）

---

### Requirement: Attended weighing entity queries SHALL not use WeighingMode as enabled flag
在人工称重相关流程中，涉及 `Provider`、`Material`、`MaterialUnit` 的查询和选择 MUST NOT 将 `WeighingMode` 作为“启用”判定条件。`WeighingMode` 在该上下文仅视为遗留字段，不参与可用性过滤。

#### Scenario: Entity search in attended weighing returns all non-WeighingMode-filtered candidates
- **WHEN** 用户在人工称重流程中打开或搜索 Provider/Material/MaterialUnit 选项
- **THEN** 系统 MUST 基于既有业务条件返回结果，且 MUST NOT 添加 `WeighingMode` 过滤

---

### Requirement: State transitions follow defined rules

WeighingStateManager SHALL manage an AttendedWeighingStatus state machine with exactly 4 states: OffScale, WaitingForStability, WeightStabilized, WaitingForDeparture. All transitions SHALL follow these rules:
- OffScale + weight > threshold → WaitingForStability
- WaitingForStability + weight < threshold → OffScale (abnormal departure)
- WaitingForStability + stability.IsStable + no existing record → WeightStabilized
- WeightStabilized + existing record → WaitingForDeparture
- WeightStabilized + weight < threshold → OffScale (abnormal)
- WaitingForDeparture + weight < threshold → OffScale (normal completion)

#### Scenario: Truck drives onto scale
- **WHEN** current state is OffScale and weight exceeds MinWeightThreshold
- **THEN** state SHALL transition to WaitingForStability

#### Scenario: Truck leaves before weight stabilizes
- **WHEN** current state is WaitingForStability and weight drops below MinWeightThreshold
- **THEN** state SHALL transition to OffScale

#### Scenario: Weight stabilizes without existing record
- **WHEN** current state is WaitingForStability, stability.IsStable is true, and no weighing record has been created (lastCreatedWeighingRecordId is null)
- **THEN** state SHALL transition to WeightStabilized

#### Scenario: Record created after stabilization
- **WHEN** current state is WeightStabilized and a weighing record has been created (lastCreatedWeighingRecordId > 0)
- **THEN** state SHALL transition to WaitingForDeparture

#### Scenario: Truck departs normally
- **WHEN** current state is WaitingForDeparture and weight drops below MinWeightThreshold
- **THEN** state SHALL transition to OffScale

#### Scenario: Abnormal departure from WeightStabilized
- **WHEN** current state is WeightStabilized and weight drops below MinWeightThreshold without creating a record
- **THEN** state SHALL transition directly to OffScale

---

### Requirement: Force WaitingForDeparture when record exists and weight is above threshold

WeighingStateManager SHALL prevent regression from WaitingForDeparture to WeightStabilized or WaitingForStability when a weighing record already exists and weight remains above threshold.

#### Scenario: State forced to WaitingForDeparture
- **WHEN** a weighing record exists (recordId > 0), weight > MinWeightThreshold, and computed state is WeightStabilized or WaitingForStability
- **THEN** state SHALL be forced to WaitingForDeparture

---

### Requirement: Current status query

WeighingStateManager SHALL expose GetCurrentStatus() returning the current AttendedWeighingStatus value synchronously.

#### Scenario: Query current status
- **WHEN** GetCurrentStatus is called
- **THEN** SHALL return the most recent status value

---

### Requirement: Status change notification

WeighingStateManager SHALL accept status updates via UpdateStatus(AttendedWeighingStatus) and track previous status for transition detection.

#### Scenario: Status updated with previous tracking
- **WHEN** UpdateStatus(WaitingForStability) is called from OffScale
- **THEN** previous status SHALL be OffScale and current status SHALL be WaitingForStability

---

### Requirement: Delivery type management

WeighingStateManager SHALL manage a DeliveryType value (Receiving/Sending) with change notification via ILocalEventBus.

#### Scenario: Delivery type changed
- **WHEN** SetDeliveryType(Sending) is called and current type is Receiving
- **THEN** DeliveryTypeChangedEventData SHALL be published via ILocalEventBus

#### Scenario: Delivery type unchanged
- **WHEN** SetDeliveryType(Receiving) is called and current type is already Receiving
- **THEN** no event SHALL be published

---

### Requirement: Construct weight stream from raw scale data

WeighingStreamPipeline SHALL create a buffered weight stream (IObservable<decimal>) from ITruckScaleWeightService.WeightUpdates, using Buffer(StabilityCheckIntervalMs) and taking the last value from each buffer.

#### Scenario: Weight stream buffers correctly
- **WHEN** raw weight updates arrive at intervals shorter than StabilityCheckIntervalMs
- **THEN** SHALL emit one value per interval window (the last value in the buffer)

---

### Requirement: Construct stability stream with valid-data filtering

WeighingStreamPipeline SHALL create a stability stream (IObservable<WeightStabilityInfo>) that:
1. Buffers weight data over StabilityWindowMs with StabilityCheckIntervalMs sliding interval
2. Filters data points above MinWeightThreshold for stability calculation
3. Requires minimum data points (max(8, windowMs/intervalMs * 0.5))
4. Determines stability when range (max-min of valid points) <= WeightStabilityThreshold * 2 AND has enough valid data points
5. Emits DistinctUntilChanged on IsStable property

#### Scenario: Sufficient valid stable data
- **WHEN** 20 data points arrive within StabilityWindowMs, all above MinWeightThreshold, with range <= threshold*2
- **THEN** IsStable SHALL be true, StableWeight SHALL be (min+max)/2

#### Scenario: Insufficient valid data points
- **WHEN** only 3 valid data points arrive within StabilityWindowMs
- **THEN** IsStable SHALL be false regardless of range

#### Scenario: No valid data points above threshold
- **WHEN** all data points in the window are below MinWeightThreshold
- **THEN** IsStable SHALL be false, StableWeight SHALL be null

---

### Requirement: Construct combined status stream

WeighingStreamPipeline SHALL create a status stream by combining weightStream, stabilityStream, recordIdStream, and current status using CombineLatest, applying state transition rules, and emitting DistinctUntilChanged on status.

#### Scenario: Status transition triggered by weight threshold
- **WHEN** status is OffScale and weight transitions above MinWeightThreshold
- **THEN** combined stream SHALL emit WaitingForStability

#### Scenario: Status transition triggered by stability
- **WHEN** status is WaitingForStability and stability.IsStable becomes true and no record exists
- **THEN** combined stream SHALL emit WeightStabilized

---

### Requirement: Share source stream to avoid multiple subscriptions

WeighingStreamPipeline SHALL use Publish().RefCount() on the raw weight source to ensure only one subscription to ITruckScaleWeightService.WeightUpdates regardless of how many derived streams exist.

#### Scenario: Multiple derived streams from single source
- **WHEN** weightStream and stabilityStream are both active
- **THEN** ITruckScaleWeightService.WeightUpdates SHALL have exactly one subscriber

---

### Requirement: StartWith initial values

WeighingStreamPipeline SHALL ensure weight stream starts with 0m and stability stream starts with IsStable=false, to provide immediate initial state to subscribers.

#### Scenario: Immediate initial emission
- **WHEN** pipeline is constructed and subscribed
- **THEN** weight stream SHALL emit 0m and stability stream SHALL emit IsStable=false without waiting for data

---

### Requirement: Replay latest stability value

WeighingStreamPipeline SHALL apply Replay(1).RefCount() to the stability stream so new subscribers immediately receive the latest stability state.

#### Scenario: Late subscriber gets latest stability
- **WHEN** a new subscriber attaches to the stability stream after it has already emitted values
- **THEN** SHALL immediately receive the most recent WeightStabilityInfo

---

### Requirement: Create weighing record on weight stabilization

WeighingRecordService SHALL create a WeighingRecord entity with the stabilized weight, current plate number from PlateNumberService, current DeliveryType, and WeighingMode from settings. The record SHALL be persisted via IRepository<WeighingRecord, long> within a UnitOfWork.

#### Scenario: Record created with all fields
- **WHEN** weight stabilizes at 1.5t, plate is "京A12345", DeliveryType is Receiving, WeighingMode is Standard
- **THEN** SHALL insert WeighingRecord with Weight=1.5t, PlateNumber="京A12345", DeliveryType=Receiving, WeighingMode=Standard

#### Scenario: Record created with no plate number
- **WHEN** weight stabilizes but no plate has been recognized (plate is null)
- **THEN** SHALL create record with PlateNumber=null

---

### Requirement: Publish WeighingRecordCreatedEventData after creation

WeighingRecordService SHALL publish WeighingRecordCreatedEventData(weighingRecordId) via ILocalEventBus after successful record creation and UoW completion.

#### Scenario: Event published after record creation
- **WHEN** a weighing record is created with ID 42
- **THEN** SHALL publish WeighingRecordCreatedEventData with WeighingRecordId=42

---

### Requirement: Save captured photos as attachments

WeighingRecordService SHALL save captured photo paths as AttachmentFile entities (AttachType.UnmatchedEntryPhoto) linked to the WeighingRecord via WeighingRecordAttachment, using relative paths for database portability.

#### Scenario: Photos saved as attachments
- **WHEN** 2 photo paths are provided for weighing record ID 42
- **THEN** SHALL create 2 AttachmentFile entries and 2 WeighingRecordAttachment link entries, converting to relative paths

#### Scenario: Photo file does not exist
- **WHEN** a photo path in the list does not exist on disk
- **THEN** SHALL skip that photo and log warning, continue with remaining photos

---

### Requirement: Rewrite plate number on departure

WeighingRecordService SHALL support rewriting the plate number and DeliveryType of the most recently created weighing record when the weighing cycle completes. If EnablePlateRewrite is true and the most frequent plate differs from the record's plate, update the record and publish UpdatePlateNumberEventData.

#### Scenario: Plate number rewritten
- **WHEN** EnablePlateRewrite=true, record has plate "京A00000", and most frequent plate is "京A12345"
- **THEN** SHALL update record plate to "京A12345" and publish UpdatePlateNumberEventData

#### Scenario: Plate rewrite disabled
- **WHEN** EnablePlateRewrite=false
- **THEN** SHALL skip plate number update and log debug

#### Scenario: Delivery type changed during weighing
- **WHEN** record has DeliveryType=Receiving but current DeliveryType is Sending
- **THEN** SHALL update record DeliveryType to Sending

---

### Requirement: Publish TryMatchEvent after rewrite cycle

WeighingRecordService SHALL publish TryMatchEvent(weighingRecordId) via ILocalEventBus after the rewrite cycle completes (whether or not changes were made), to trigger automatic matching.

#### Scenario: TryMatch published with no changes
- **WHEN** plate and delivery type are unchanged
- **THEN** SHALL still publish TryMatchEvent with the record ID

---

### Requirement: Prevent duplicate record creation

WeighingRecordService SHALL use a record ID tracker (BehaviorSubject<long?>) to ensure only one weighing record is created per weighing cycle. A null value means no record exists; a non-null value means a record was already created.

#### Scenario: Duplicate creation prevented
- **WHEN** CreateWeighingRecordAsync is called but recordId is already non-null
- **THEN** SHALL not create a second record

---

### Requirement: Reset record tracker for new cycle

WeighingRecordService SHALL provide ResetCycle() that clears the record ID tracker to null, enabling a new weighing cycle.

#### Scenario: Cycle reset
- **WHEN** ResetCycle() is called
- **THEN** record ID tracker SHALL be set to null

---

### Requirement: Implement IAttendedWeighingService interface

AttendedWeighingOrchestrator SHALL implement IAttendedWeighingService, providing StartAsync(), StopAsync(), GetCurrentStatus(), GetMostFrequentPlateNumber(), SetDeliveryType(), CurrentDeliveryType, and DisposeAsync() by delegating to extracted services.

#### Scenario: Interface methods delegate correctly
- **WHEN** StartAsync() is called
- **THEN** SHALL initialize WeighingStreamPipeline, subscribe to ILocalEventBus events, and start the async operation queue

#### Scenario: GetMostFrequentPlateNumber delegates
- **WHEN** GetMostFrequentPlateNumber() is called
- **THEN** SHALL return PlateNumberService.GetMostFrequentPlateNumber()

#### Scenario: GetCurrentStatus delegates
- **WHEN** GetCurrentStatus() is called
- **THEN** SHALL return WeighingStateManager.GetCurrentStatus()

---

### Requirement: Subscribe to ILocalEventBus external events on StartAsync

AttendedWeighingOrchestrator SHALL subscribe to:
- LicensePlateRecognizedEventData → delegate to PlateNumberService
- GhostGateSessionResetEventData → remove abandoned plate and publish updated plate
- SettingsSavedEventData → refresh runtime configuration (EnableLatestPlateNumber, EnablePlateRewrite)

#### Scenario: License plate event triggers plate cache update
- **WHEN** LicensePlateRecognizedEventData with plate "京A12345" is received
- **THEN** SHALL call PlateNumberService recognition method and publish PlateNumberChangedEventData

#### Scenario: Ghost gate session reset
- **WHEN** GhostGateSessionResetEventData with AbandonedPlateNumber="京A12345" is received
- **THEN** SHALL remove the plate from cache and publish PlateNumberChangedEventData with updated most frequent plate

#### Scenario: Settings saved refreshes runtime config
- **WHEN** SettingsSavedEventData is received
- **THEN** SHALL reload EnableLatestPlateNumber and EnablePlateRewrite from settings

---

### Requirement: Manage async operation queue

AttendedWeighingOrchestrator SHALL provide an async operation queue using Subject<Func<Task>> with Merge(maxConcurrent:5) for executing async side-effects (capture, record creation, cache reset) with retry(3) and error handling.

#### Scenario: Async operation enqueued
- **WHEN** EnqueueAsyncOperation(operation) is called
- **THEN** operation SHALL execute within the Merge(5) concurrency limit

#### Scenario: Fallback when stream not initialized
- **WHEN** EnqueueAsyncOperation is called but async stream is null
- **THEN** SHALL fall back to Task.Run with try/catch error logging

---

### Requirement: Handle status change side-effects

AttendedWeighingOrchestrator SHALL process status transition side-effects:
- OffScale → WaitingForStability: trigger Vzvision capture, log entry
- WaitingForStability → WeightStabilized: create weighing record with stable weight
- WaitingForStability → OffScale: capture all cameras, reset cycle
- WeightStabilized → OffScale: trigger capture, reset cycle
- WaitingForDeparture → OffScale: trigger capture, reset cycle, log completion

#### Scenario: Weight stabilized triggers record creation
- **WHEN** status transitions from WaitingForStability to WeightStabilized
- **THEN** SHALL enqueue WeighingRecordService.CreateWeighingRecordAsync with stable weight

#### Scenario: Normal departure resets cycle
- **WHEN** status transitions from WaitingForDeparture to OffScale
- **THEN** SHALL enqueue WeighingCaptureService.CaptureOnOffScale, then WeighingRecordService.RewriteAndResetCycle

---

### Requirement: Play audio announcements on status transitions

AttendedWeighingOrchestrator SHALL play audio announcements via ISoundDeviceService for specific transitions:
- OffScale → WaitingForStability: "车辆已上磅，正在称重"
- WaitingForDeparture → OffScale: "车辆已下磅，称重已完成"
- WaitingForStability → OffScale: "车辆已下磅"
- * → WeightStabilized: "称重已结束"

#### Scenario: Audio played on truck entry
- **WHEN** status transitions from OffScale to WaitingForStability
- **THEN** SHALL enqueue ISoundDeviceService.PlayTextV2Async("车辆已上磅，正在称重")

---

### Requirement: Graceful shutdown with pending operation completion

AttendedWeighingOrchestrator SHALL on StopAsync: dispose all Rx subscriptions, complete the async operation stream, and wait up to 5 minutes for pending operations to complete.

#### Scenario: Pending operations complete before shutdown
- **WHEN** StopAsync is called with 3 pending operations
- **THEN** SHALL wait for all to complete (up to 5 minutes timeout)

#### Scenario: Timeout on pending operations
- **WHEN** pending operations do not complete within 5 minutes
- **THEN** SHALL log warning and proceed with shutdown

---

### Requirement: Idempotent start

AttendedWeighingOrchestrator SHALL ignore duplicate StartAsync() calls if already started.

#### Scenario: Multiple start calls
- **WHEN** StartAsync() is called twice
- **THEN** SHALL only initialize streams and subscriptions once

---

### Requirement: Complete resource disposal

AttendedWeighingOrchestrator SHALL on DisposeAsync: call StopAsync, dispose all ILocalEventBus subscriptions, and dispose all internal BehaviorSubjects.

#### Scenario: Full disposal
- **WHEN** DisposeAsync is called
- **THEN** all subscriptions SHALL be disposed, all subjects SHALL be completed and disposed

---

### Requirement: AttendedWeighingService 内部扩展 UrbanMode 支持

AttendedWeighingService SHALL 在内部查询当前 `WeighingMode`，并在 `ProcessStatusTransition` 中根据模式走不同分支。当 `WeighingMode = UrbanMode (201)` 时，跳过 `TryMatchEvent` 相关的触发链路。

#### Scenario: UrbanMode 状态转换跳过匹对
- **WHEN** `ProcessStatusTransition` 处理状态转换
- **AND WHEN** 当前 `WeighingMode = UrbanMode (201)`
- **THEN** SHALL NOT 触发 `RewriteAndResetCycleAsync` 中的 `TryMatchEvent` 发布
- **AND** SHALL 执行车牌重写和周期重置（保留这部分逻辑）
- **AND** SHALL 记录 Debug 日志表明处于 UrbanMode 分支

#### Scenario: 非 UrbanMode 保持现有行为
- **WHEN** `ProcessStatusTransition` 处理状态转换
- **AND WHEN** 当前 `WeighingMode` 不为 UrbanMode
- **THEN** SHALL 保持现有全部行为不变（包括 TryMatchEvent）

### Requirement: WeighingRecordService 内部模式感知

WeighingRecordService SHALL 在内部查询当前 `WeighingMode`，在 `TryReWritePlateNumberAsync` 中根据模式决定是否发布 `TryMatchEvent`。

#### Scenario: UrbanMode 不发布 TryMatchEvent
- **WHEN** `TryReWritePlateNumberAsync` 执行完成
- **AND WHEN** 当前 `WeighingMode = UrbanMode (201)`
- **THEN** SHALL NOT 调用 `_localEventBus.PublishAsync(new TryMatchEvent(...))`
- **AND** SHALL 记录 Debug 日志表明跳过了匹对

#### Scenario: 非 UrbanMode 正常发布 TryMatchEvent
- **WHEN** `TryReWritePlateNumberAsync` 执行完成
- **AND WHEN** 当前 `WeighingMode` 不为 UrbanMode
- **THEN** SHALL 正常发布 `TryMatchEvent`（保持现有行为不变）

### Requirement: ViewModel 订阅 ILocalEventBus 已有事件

WeighingSystemViewModel SHALL 通过 `ILocalEventBus` 订阅 `WeighingRecordCreatedEventData` 和 `StatusChangedEventData`，驱动 UI 更新。不新建 MessageBus 消息类型。

#### Scenario: 订阅 WeighingRecordCreatedEventData 刷新列表
- **WHEN** ViewModel 初始化完成
- **THEN** SHALL 通过 `ILocalEventBus.Subscribe<WeighingRecordCreatedEventData>` 订阅记录创建事件
- **AND** 收到事件后 SHALL 从本地仓储查询完整记录并添加到 WeighingRecords 集合顶部

#### Scenario: 订阅 StatusChangedEventData 更新状态文案
- **WHEN** ViewModel 初始化完成
- **THEN** SHALL 通过 `ILocalEventBus.Subscribe<StatusChangedEventData>` 订阅状态变更事件
- **AND** 收到事件后 SHALL 更新 WeightStatus 和 WeightStatusColor

#### Scenario: 列表更新在 UI 线程执行
- **WHEN** 收到 ILocalEventBus 事件
- **THEN** SHALL 通过 ObserveOn(RxApp.MainThreadScheduler) 确保在 UI 线程更新集合

### Requirement: 实时更新重量区显示

WeighingSystemViewModel SHALL 实时绑定称重设备的当前重量值到主界面重量区。

#### Scenario: 重量实时更新
- **WHEN** 称重设备推送新重量值 8500kg
- **THEN** SHALL 在 500ms 内更新 CurrentWeight 为 "8,500"
- **AND** SHALL 通过 ReactiveUI 属性变更通知 UI

#### Scenario: 无设备数据时显示零
- **WHEN** 称重管线未启动或设备断开
- **THEN** SHALL 显示 CurrentWeight 为 "0.00"

### Requirement: 状态文案联动

WeighingSystemViewModel SHALL 根据称重状态显示对应文案和颜色。

#### Scenario: 等待上磅状态
- **WHEN** 称重状态为 OffScale
- **THEN** SHALL 显示 WeightStatus = "等待上磅"
- **AND** SHALL 设置 WeightStatusColor = "#94A3B8"（灰色）

#### Scenario: 正在称重状态
- **WHEN** 称重状态为 WaitingForStability
- **THEN** SHALL 显示 WeightStatus = "正在称重"
- **AND** SHALL 设置 WeightStatusColor = "#FBBF24"（黄色）

#### Scenario: 称重已结束状态
- **WHEN** 称重状态为 WeightStabilized 或 WaitingForDeparture
- **THEN** SHALL 显示 WeightStatus = "称重已结束"
- **AND** SHALL 设置 WeightStatusColor = "#4ADE80"（绿色）

### Requirement: 列表 Tab 筛选

WeighingSystemViewModel SHALL 支持按 Tab 切换筛选称重记录列表。

#### Scenario: 全部记录 Tab
- **WHEN** 用户选择"全部"Tab
- **THEN** SHALL 查询并显示所有 WeighingRecord（当前 WeighingMode = UrbanMode）

#### Scenario: 正常记录 Tab
- **WHEN** 用户选择"正常"Tab
- **THEN** SHALL 查询并显示 SyncStatus != Failed 的 WeighingRecord

#### Scenario: 异常记录 Tab
- **WHEN** 用户选择"异常"Tab
- **THEN** SHALL 查询并显示 SyncStatus = Failed 的 WeighingRecord

### Requirement: 列表搜索与分页

WeighingSystemViewModel SHALL 支持按车牌号和称重时间搜索，并支持分页查询。

#### Scenario: 按车牌号搜索
- **WHEN** 用户输入车牌号 "京A"
- **THEN** SHALL 查询 PlateNumber LIKE "%京A%" 的记录

#### Scenario: 按称重时间范围搜索
- **WHEN** 用户选择时间范围 2026-01-01 至 2026-01-31
- **THEN** SHALL 查询 CreationTime 在该范围内的记录

#### Scenario: 分页查询
- **WHEN** 查询结果超过 PageSize（默认 20）
- **THEN** SHALL 返回第一页数据
- **AND** SHALL 计算总页数

### Requirement: WeighingRecord 新增 SyncStatus 字段

WeighingRecord 实体 SHALL 新增 SyncStatus 属性，用于跟踪记录的同步状态。

#### Scenario: 新记录默认为 Pending
- **WHEN** 创建新的 WeighingRecord
- **THEN** SHALL 设置 SyncStatus = Pending

#### Scenario: SyncStatus 枚举值
- **WHEN** 系统使用 SyncStatus
- **THEN** SHALL 支持三个值：Pending（待上传）、Synced（已同步）、Failed（上传失败）

### Requirement: 启动时初始化 IAttendedWeighingService

MaterialClient.Urban App.axaml.cs SHALL 在应用启动后调用 `IAttendedWeighingService.StartAsync()` 启动称重管线。

#### Scenario: 应用启动后启动称重管线
- **WHEN** MaterialClient.Urban 应用启动完成，主窗口已显示
- **THEN** SHALL 解析 IAttendedWeighingService
- **AND** SHALL 调用 StartAsync() 启动称重管线
- **AND** SHALL 将 ViewModel 注入到 ILocalEventBus 订阅链路
