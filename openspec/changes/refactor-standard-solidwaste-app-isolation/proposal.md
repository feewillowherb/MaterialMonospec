## Why

数据库拆分已经验收：同一个 SQLite 文件里，内核保留称重和运单，Standard 与 SolidWaste 各自拥有 Context。两个产品仍由同一个 `MaterialClient.exe` 启动，固废变更还会带动标准端一起发布和验收。已部署的固废现场也还在运行这个主程序，拆出独立宿主后必须能接着用原来的库、附件和授权。

## What Changes

- 新增 `MaterialClient.SolidWaste` WinExe。它只装配 SolidWaste 产品模块，产品身份固定为固废，单独构建、安装和发布。
- **BREAKING** `MaterialClient.exe` 收回为 Standard 宿主：只装配 Standard 产品模块，不再迁移 SolidWaste，也不再把固废当作可选产品。
- 两个宿主使用不同的单实例互斥名。已保存的默认称重模式属于另一产品时，宿主不改这条设置，也不进入称重。
- 升级支持范围先限定到已完成 495aa3e3 数据库拆分的结构基线；更旧版本先经已验证的数据库升级版本接续。未知结构拒绝启动。
- 旧现场配置按明确优先级接续，迁移和后台启动前先只读验证数据库与产品身份，防止误建空库。
- 安装器与运行期均使用产品独立自启动项，并对旧固废入口执行有归属校验的接续。
- 升级前制作一致性恢复备份，失败按程序、数据、配置和入口成套恢复，不保证旧程序直接打开新库。
- 数据目录默认仍是 exe 目录。升级时可以显式指定旧安装目录，相对数据库路径和相对附件路径都相对该目录解析，避免新目录里生成空库或找不到照片。
- 固废安装包使用独立的安装身份。卸载不删除现场数据库和附件。标准端安装不把已有固废快捷方式和自启动改回 `MaterialClient.exe`。
- 不复制称重界面。新宿主引用现有 UI 与有人值守项目，只保留自己的启动壳。
- Urban / Recycle 宿主不引用、不迁移 Standard 或 SolidWaste。

## Capabilities

### New Capabilities

- `standard-solidwaste-app-isolation`: Standard 与 SolidWaste 各自拥有桌面宿主、固定产品身份、启动迁移和安装升级边界。

### Modified Capabilities

- `product-dbcontext-isolation`: 标准宿主在内核之后只迁移 Standard；固废宿主在内核之后只迁移 SolidWaste。两边都不迁移 Urban / Recycle。
- `product-common-layers`: 标准宿主不引用 SolidWaste 产品程序集；固废宿主只引用 SolidWaste 产品程序集。

## Impact

- **MaterialClient**：新增固废 WinExe、安装脚本和数据目录解析；标准宿主去掉 SolidWaste 模块依赖与启动迁移。内核称重、运单和已验收的扩展表保持不变。
- **Urban / Recycle**：项目引用和启动迁移不变。
- 同一数据目录不作为两个宿主同时运行的支持方式。不重写称重算法、合同、主数据来源或设备生命周期，也不做进程内热更新。
