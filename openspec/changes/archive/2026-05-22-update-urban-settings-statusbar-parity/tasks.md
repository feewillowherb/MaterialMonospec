## 1. 审计与准备

- [x] 1.1 对比主应用 `MaterialClient/Views/Settings/` 与 Urban `MaterialClient.Urban/Views/Settings/` 的 7 vs 4 个 Section，列出字段与 `ISettingsService` 键差异
- [x] 1.2 对比主应用与 Urban 的 `DeviceStatusBarViewModel`（或等效）设备列表与事件订阅
- [x] 1.3 审计 `MaterialClient.Urban` ABP 模块：确认打印机、音频、称重相关服务已注册（与主应用一致）

## 2. 共享设置分区（MaterialClient.UI）

- [x] 2.1 在 `MaterialClient.UI/Settings/Sections/` 创建目录结构
- [x] 2.2 将主应用 7 个 Section（Scale、Weighing、Camera、Lpr、System、SoundDevice、Printer）迁移至 `MaterialClient.UI`，保持 `ISettingsSection` + `ITransientDependency`
- [x] 2.3 更新 `MaterialClient` 项目：删除已迁移的 Section 文件，确认 DI 仍发现 7 分区
- [x] 2.4 验证主应用 SettingsDialog：打开、导航 7 分区、load/save 回归通过

## 3. Urban 设置对齐

- [x] 3.1 删除 `MaterialClient.Urban/Views/Settings/` 下 Urban 专用 Section 实现
- [x] 3.2 确认 Urban 程序集扫描到 `MaterialClient.UI` 中 7 个 Section（无需 Urban 副本）
- [x] 3.3 验证 Urban SettingsDialog：7 分区显示、字段与主应用一致、保存后重启可加载

## 4. 设备状态栏对齐

- [x] 4.1 在 `MaterialClient.UI` 集中设备 catalog 逻辑（统一 scale、camera、USB camera、printer、sound、LPR 项）
- [x] 4.2 移除 Urban 侧设备子集硬编码（若有）
- [x] 4.3 验证主应用状态栏：6 类设备指示器显示与插拔更新
- [x] 4.4 验证 Urban 状态栏：与主应用相同设备项、1 秒内事件更新、绿/红指示器

## 5. Urban 模块与服务

- [x] 5.1 若审计发现缺失：在 Urban 模块补齐打印机/音频/称重服务注册
- [x] 5.2 在无外设环境下确认离线指示器行为与主应用一致（不崩溃、可保存设置）

## 6. 清理与验证

- [x] 6.1 删除废弃的 Urban Settings 文件与未使用的 using/引用
- [x] 6.2 `dotnet build` MaterialClient 解决方案（含 Urban）通过
- [x] 6.3 端到端：Urban 打开设置 → 修改打印机/音频/称重项 → 保存 → 状态栏反映设备变化
- [x] 6.4 运行 `openspec validate update-urban-settings-statusbar-parity --strict`
