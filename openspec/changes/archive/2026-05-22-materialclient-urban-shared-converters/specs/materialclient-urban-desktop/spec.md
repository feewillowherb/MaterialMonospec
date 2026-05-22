## MODIFIED Requirements

### Requirement: 照片显示区域

MaterialClient.Urban 右侧照片区 MUST 显示两张照片：车牌识别抓拍和摄像头抓拍，MUST 支持从本地缓存或服务器加载。照片 MUST 通过 Avalonia `Image` 控件绑定，并使用 MaterialClient.UI 提供的 `CarNullOrEmptyImageConverter` 处理空路径与加载失败。

#### Scenario: 照片区域布局
- **WHEN** 用户查看称重记录详情
- **THEN** SHALL 显示"车牌识别抓拍"照片区域（高度 120px）
- **AND** SHALL 显示"摄像头抓拍"照片区域（高度 120px）
- **AND** SHALL 显示照片拍摄时间
- **AND** 每个照片区域 SHALL 使用 `Image` 控件（非 emoji `TextBlock` 占位）

#### Scenario: 照片加载逻辑
- **WHEN** 用户选择一条称重记录
- **THEN** SHALL 优先从本地缓存加载照片
- **AND** 如果本地缓存不存在，SHALL 从服务器加载照片
- **AND** SHALL 将下载的照片保存到本地缓存
- **AND** ViewModel SHALL 向 UI 暴露可绑定的照片路径字符串属性（车牌识别、摄像头各一）

#### Scenario: 照片 XAML 绑定
- **WHEN** UrbanAttendedWeighingWindow 显示照片区域
- **THEN** 车牌识别 `Image.Source` SHALL 绑定到 ViewModel 车牌照片路径
- **AND** SHALL 使用 `Converter={StaticResource CarNullOrEmptyImageConverter}`
- **AND** 摄像头 `Image.Source` SHALL 绑定到 ViewModel 摄像头照片路径
- **AND** SHALL 使用同一 `CarNullOrEmptyImageConverter` 静态资源

#### Scenario: 照片加载失败
- **WHEN** 照片路径为空、无效或文件不存在
- **THEN** `CarNullOrEmptyImageConverter` SHALL 显示默认车辆图片（`Car_Default.png`）
- **AND** SHALL NOT 使用 emoji（🚛）作为占位
- **AND** 照片容器 MAY 保留灰色边框背景样式
