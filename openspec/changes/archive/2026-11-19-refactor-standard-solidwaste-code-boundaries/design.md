## Context

Topic 为候选设计与历史证据，不能当作当前分支审计结果。2026-11-18 本轮只读核对仍发现：SolidWaste csproj 链接标准 exe 的三个服务源码；SolidWasteExtensionStore 从内核旧 getter 投影四字段及净重标记，BackfillMissingAsync 只补缺失行；标准 Module 注册 StreetsConfig/SolidWasteTypeConfig。上述路径是 Cursor 的入口，不代表完整缺陷清单。

用户确认当前业务 ExtraProperties 仅有 UseIndependentDisplayedNet。本 change 不实施历史旧键迁移或删除。若实际目标库不满足这个基线，记录不匹配并停止该库写入，保留原库，交由独立升级决策处理；不能用空值覆盖扩展表或擅自清理。

## Goals / Non-Goals

目标：四字段的唯一权威、产品实现从 Common 收拢、两个 exe 不互为源码依赖、宿主组合明确，原业务行为可核对。

非目标：重新设计称重内核、换 MVVM 框架、重做 UI、抽象所有产品、整理全仓 mapper、清理历史数据库、修改现有升级保护或安装流程。标准读取混合模式历史记录的现有能力不得因本次拆分丢失。

## Decisions

### 1. 数据所有权

SolidWasteWeighingExtension/SolidWasteWaybillExtension 持有四项业务字段，逻辑 Id + 唯一索引关联内核；Service 二次查询组合，无 EF 关系导航或数据库 FK。新增/编辑采用产品输入 record，类型自身 Apply/其他意图方法维护状态；读取返回目标类型 From* 构建的 record。不再从 Waybill/WeighingRecord 的旧 ExtraProperties 重建扩展。

UseIndependentDisplayedNet 的 getter/setter 和默认值保持单一实现，运单 ExtraProperties 是唯一来源；扩展实体/快照移除其业务属性，EF 映射忽略旧物理列。保留已发布 migration；不删除或重写旧列，不回填标记，不从旧列恢复。若忽略旧 NOT NULL 列会影响 INSERT，先核对其数据库默认值：必要时追加产品 migration，为保留列提供兼容默认值或调整产品表定义，完整保留四字段、Id 和索引；不得仅忽略映射导致新建失败。

现有缺失扩展行：不能用缺失的旧键伪造四字段。读取应明确表达“无扩展数据”；默认展示逻辑不持久化为历史事实。对必须有扩展的写操作，缺失输入应返回可识别失败，禁止写入半成品。正常新建使用本次业务输入创建扩展。

### 2. Common 与产品模块

Common 保留称重内核与最小产品中立生命周期接口；创建、匹配/取消匹配、编辑、删除等实际需要维护扩展的操作，通过可等待的同步编排调用产品实现。输入/结果使用命名 record；不传产品专属字段到公共聚合，不给公共服务增加 SolidWaste 分支。

产品持久化与四字段操作位于 Common.SolidWaste。共享 UI 所需的专用查询/命令契约和快照放入不含 EF/产品实现的契约类库（优先复用已有合适边界，必要时新建 MaterialClient.Product.Contracts）；Common 不引用此产品专用契约。固废导出实现移入产品模块；标准的历史查询/导出入口若需展示固废数据，可由不加载固废运行模块的只读适配实现契约，禁止初始化 SolidWasteDbContext、创建产品表或启动固废任务。只读适配遇到无扩展表应报告数据不可用，不回退旧四键。

接口、空实现与模块替换必须核对 ABP 实际解析结果：标准使用中立 no-op 写扩展，固废使用持久化实现；不能因扫描顺序同时执行两套实现。无实际生命周期动作不新增空泛回调。

### 3. 事务与失败

内核与扩展持久化的编排 Service 使用 [UnitOfWork]，同库跨 Context 显式共用连接/事务；异常传播并整体回滚。不得用 fire-and-forget LocalEventBus 实现必须原子的扩展写入，也不能吞错后继续主流程。取消匹配、删除沿用已核对的业务语义，不擅自新增级联删除；在调用矩阵中写清四字段保留/转移规则。

### 4. 共享宿主与组合

新增 MaterialClient.Desktop.Hosting 类库容纳三项确实共用的服务（若仓内已有等价类库则复用），依赖 Common 与现有共享 UI/AttendedWeighing 边界，不引用任何 exe 或产品实现程序集。UI 启动协调放这里，不下沉无 UI Common。两 exe 引用共享类库并独立注册身份、产品 DbContext、配置及产品服务；删除 Compile Link，更新命名空间与使用方，不复制同一实现。

标准只组合 Standard，固废只组合 SolidWaste。StreetsConfig/SolidWasteTypeConfig 的绑定与默认值属于固废组合，标准不再注册无用途的产品配置。公共 HTTP/授权客户端按实际公共依赖注册，两宿主均完整解析。StartupService 持有窗口状态，其生命周期由两个宿主一致显式配置，保持启动一次与退出清理语义。

本次沿用现有 HostProductIdentity/HostBootstrap/PathManager，不重写全局状态。共享服务消费宿主已经确定的身份和路径，不自行推断或修改产品。

### 5. 约束与并行工作

仅纯逻辑不注册 DI；需要持久化、I/O、生命周期或既有 UI 约定的类型才注册。字段 mutation 用类型实例方法，projection 用 From*/To*，禁止 Mapper Service/tuple。UI 数据入口必须经过 Service。涉及窗口/绑定实现前按 avalonia-docs trait 查文档，保留 ReactiveUI/Semi/Ursa。

Cursor 开始前核对两仓 HEAD、dirty files 与相关活动 change；不得覆盖其他人的修改。以 trunk 已具备独立宿主/Context 为前提；缺少前置实现时记录依赖，先解决基线协调，不把其他未合入 change 自动合入当前分支。

## Verification and Acceptance

目标 ICD L3，仅限本 change 声明的边界及失败行为；当前未验收。构建不等于交付，也不要求重跑安装发布矩阵。

- 静态依赖证据：两 exe 无源码互链；Common 无固废专属 Store/导出/四字段操作；标准无固废运行模块依赖；契约类库无实现依赖。
- 两宿主 Windows 运行证据：授权/登录/主窗、公共 HTTP 客户端、轮询开关与关闭清理，以及各自配置绑定。
- 隔离副本库证据：四字段创建、匹配/取消、编辑、查询、导出/打印与重启后一致；净重标记 true/false/缺失默认行为一致。标准仍可读取原有混合模式历史记录。
- 故障证据：扩展写入失败时内核与扩展一起回滚；缺失扩展明确表达；旧冗余列不影响 INSERT；重复启动不重写现有扩展；不符合目标数据基线的库不被修改。
- 回归范围覆盖共享代码被 Urban/Recycle 引用的编译影响，不改它们的业务链。证据记录命令、提交/工作区身份、环境与结果于本 change；未执行项保持未验收。

## 调用矩阵（2026-11-19 实现前核对）

依赖：Standard 与 SolidWaste 都引用 `MaterialClient.Desktop.Hosting`。该库只引用 Common、UI、AttendedWeighing。SolidWaste 不再 Compile Link 标准 exe。Urban / Recycle 仍使用各自的轮询类型。标准宿主注册只读扩展读取器；固废宿主注册 `SolidWasteExtensionStore`；Urban / Recycle 保持 `NullSolidWasteExtensionStore`。

| 操作 | 原行为 | 实现后的边界 | 事务 |
|------|--------|--------------|------|
| 创建/编辑固废记录或运单 | `UpdateSolidWasteModeAsync` 把四字段写入 ExtraProperties，再按 getter 投影扩展 | 内核字段仍由匹配服务更新；四字段只以 `SolidWasteFieldValues` 写入扩展。空输入不新建扩展，已有扩展不被空输入覆盖 | 匹配服务 `[UnitOfWork]`，扩展保存加入同一工作单元 |
| 匹配生成运单 | 从称重记录 ExtraProperties 复制四字段，Shipper 缺省会写成默认发货单位 | 只继承 `WeighingMode`。扩展行按 join 优先、out 补缺合并；两侧都没有扩展则不插入 | 运单插入与 `CopyMatchedFieldsAsync` 同一工作单元 |
| 取消匹配/删除 | 不删除扩展行，无级联 | 保持不新增级联删除 | 沿用原内核事务 |
| 查询/详情 | 详情 ViewModel 直接读 Repository 和 ExtraProperties | 详情经匹配服务读内核，经扩展存储读四字段。缺失扩展显示为空，不回读旧键 | 只读 |
| 导出/打印 | 四字段和净重标记都可从 ExtraProperties 或扩展回退 | 四字段只来自扩展快照。`UseIndependentDisplayedNet` 只读运单 ExtraProperties | 导出服务 `[UnitOfWork]` |
| 同步 | `FromWaybill` 从 ExtraProperties 取四字段 | 同步前按运单 Id 读扩展；没有扩展时产品字段为空 | 同步流程原事务 |
| 启动回填 | `BackfillMissingAsync` 从旧键补缺失行 | 已移除。固废启动先只读检查四个旧键；命中则停止写入并记录原因 | 检查不写库 |

工作区没有可核对的既有业务库副本。1.3 不打开现场库。隔离验证只用测试库和 `.build-verify` 新库。

主规范里“启动从 ExtraProperties 复制四字段且不得删除旧键”由本 change 的 schema delta 取代。历史归档不改。安装与升级验收不在本次范围。

2026-11-19 在 `.build-verify` 空库上启动，停在授权界面，未进入授权后流程：

| 宿主 | 结果 |
|------|------|
| MaterialClient | 窗口「软件授权」，进程保持响应。轮询开启时后台任务可启动。 |
| MaterialClient.SolidWaste | 窗口「软件授权」。固废迁移完成，未拒绝基线。 |
| MaterialClient.Urban | 窗口「激活」。 |
| MaterialClient.Recycle | 仓库配置没有 `Encryption:AesKey`。隔离目录补了一把一次性密钥后，窗口为「软件授权」。 |

四台都没有现场串口。日志里的 COM3 缺失不阻止授权窗口。1.3、5.3、5.4 仍未勾选：没有现场库副本，也没有做授权后的业务操作。`openspec validate refactor-standard-solidwaste-code-boundaries --strict` 通过。这不是 ICD L3。

## Rollout and Risks

先核对调用矩阵，再拆共享宿主，随后切换产品入口与数据权威，最后移除旧调用。只在隔离副本上验证数据操作；现有启动预检、排他、备份和恢复要求持续有效。当前方案不授权现场升级或旧 exe 回退。主要风险是跨 Context 事务未共用、共享 UI 引用环、标准历史展示丢失、保留列 NOT NULL 插入失败；均需对应验证。若必须改变业务语义或扩大历史兼容范围，先更新本 change 并交用户裁决，禁止以空值/假成功代替。
