# Standard / SolidWaste 独立应用宿主拆分

日期：2026-11-12。Lifecycle：ACTIVE。知识状态：现状 CONFIRMED；拆分方向 INFERRED；升级与运行结果 PENDING_VALIDATION。

## 目标与背景

用户在数据库拆分完成后提出继续拆分应用程序。本轮补充需求描述与调查入口，不创建应用项目、不修改客户端代码、不执行安装升级。

目标是让 Standard 与 SolidWaste 分别拥有可独立装配、构建、安装、升级和发布的桌面宿主，减少产品专属变更对另一产品发布与验收的牵连。共享模块发生变化时，仍须按影响范围执行回归；两个 EXE 本身不构成业务完全隔离的证明。

## 当前基线

MaterialClient HEAD：`495aa3e3ba5c514dc705061ba4886533566f0ba5`，提交为 `refactor-standard-solidwaste-schema-isolation` 的 squash 合入。用户确认数据库拆分任务已完成；本次未重新执行其验收。

- `repos/MaterialClient/src/MaterialClient/MaterialClient.csproj` 同时引用 Common.Standard 与 Common.SolidWaste。
- `repos/MaterialClient/src/MaterialClient/MaterialClientModule.cs:43` 同时依赖两个产品 Module；启动方法 MigrateStandardProductContextsAsync 迁移两套产品 Context，并接续固废扩展数据。
- `repos/MaterialClient/src/MaterialClient.UI/ViewModels/AuthCodeWindowViewModel.cs:41` 仍提供 Standard / SolidWaste 选择，ResolveProductCode 根据模式选择产品码。
- `repos/MaterialClient/scripts/installer/MaterialClient.iss` 是现有主程序安装脚本；Urban、Recycle 已有单独安装脚本，可作为结构参考，不能直接推定适用于固废旧安装身份。

数据库拆分的实际范围是新增产品专属 Context、扩展表与迁移；内核 WeighingRecords、Waybills 仍保留共用模型。应用拆分应基于该事实，不额外承诺完整业务主表隔离。

## 候选宿主边界

| 部分 | 建议职责 |
|---|---|
| MaterialClient | 保留为 Standard 宿主，尽量延续标准端既有程序身份 |
| MaterialClient.SolidWaste | 新增固废宿主，独立产品码、模式、启动装配、配置与发布产物 |
| Common / 内核 EF | 复用稳定称重、设备、持久化和公共契约 |
| Common.Standard / Common.SolidWaste | 对应产品数据、规则与扩展实现 |
| UI / AttendedWeighing | 复用公共称重交互；识别并隔离固废专属入口、表单与规则 |

以上项目命名与分配是候选方向，正式设计需核对现有 UI 复用关系、ABP 注册与依赖，避免宿主之间直接引用，也避免复制完整称重流程。

## 拆分内容

1. 分离启动组合根：各宿主明确装配的产品模块、服务、窗口、配置和后台任务。
2. 固定产品身份：Standard 与 SolidWaste 分别使用对应产品码与默认模式；旧设置和既有授权的冲突需要明确处理，不能静默切成另一产品。
3. 明确 UI 归属：产品专属入口与表单由对应产品选择；公共控件和交互继续复用。新增宿主不意味着复制所有 AXAML 和 ViewModel。
4. 分离迁移入口：通常内核后执行本产品迁移，但必须先核对旧库兼容接续和跨产品查询路径，不能简单删除现有启动迁移步骤。
5. 分离构建与交付：建立独立发布命令、安装包、应用标识、图标/名称、快捷方式和自启动入口。产品版本与对应验证证据可追溯。
6. 明确业务行为保持范围：首期以应用与装配拆分为主，不顺带重写称重算法、合同业务、主数据来源或设备生命周期。

## 旧固废客户端升级接续

现有固废用户也运行 MaterialClient 主程序。新增 EXE 后，必须有从旧安装到新固废宿主的明确升级路线。

调查并设计：

- 原安装身份、安装目录、卸载项及新安装包如何衔接；标准用户不能被自动替换为固废客户端。
- 原 SQLite 路径、相对附件路径、模板、日志和配置的定位方式；避免新进程基目录变化后创建空库或找不到附件。
- 既有授权、会话与产品码如何接续；不能以让所有用户重新激活作为默认方案。
- 旧快捷方式、自启动注册、更新入口与进程互斥如何切换，避免两个宿主误同时操作同一现场数据库或设备。
- 升级前安全关闭旧进程、验证备份可用；迁移/安装失败时如何恢复可用程序与数据。只替换旧 EXE 不等于数据库可安全降级。
- 新库安装与存量库升级分别验证；混合模式历史数据的读取规则不能因产品固定而被静默过滤丢失。

此处目标是停止旧程序后升级并重启，不要求进程内热更新。是否支持两个产品在同一机器并存、是否共享数据目录，为待决项。

## 后续验证范围

| 场景 | 需要证明 |
|---|---|
| Standard 全新安装 | 产品身份正确、模块可解析、迁移与称重核心路径可运行 |
| SolidWaste 全新安装 | 固废身份、专属字段/表单、称重与导出打印路径可运行 |
| 旧 Standard 升级 | 原数据、配置、授权与附件可接续，新增数据可写 |
| 旧 SolidWaste 升级到独立宿主 | 启动正确产品，历史和新业务均可用，旧入口完成衔接 |
| 重复启动与升级中断 | 不重复迁移、不损坏数据，有可执行恢复路线 |
| Urban / Recycle 回归 | 共享模块变化的影响有检查证据，不因本次宿主拆分误装配其他产品 |

构建成功不等于安装升级和设备流程通过。优先复用自动测试；窗口、授权及设备路径按真实环境取证，不以全量 headless 作为前置要求。

## OpenSpec 交接

用户已于 2026-11-13 确认数据库拆分验收，并要求拆分独立客户端。对应 change 为 `refactor-standard-solidwaste-app-isolation`。宿主依赖、产品身份、迁移顺序和旧数据目录接续以该 change 的 design 为准。此文仍是调查入口，不代替该 change 的验收。
