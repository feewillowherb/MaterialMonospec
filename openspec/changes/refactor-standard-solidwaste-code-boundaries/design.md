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

## Rollout and Risks

先核对调用矩阵，再拆共享宿主，随后切换产品入口与数据权威，最后移除旧调用。只在隔离副本上验证数据操作；现有启动预检、排他、备份和恢复要求持续有效。当前方案不授权现场升级或旧 exe 回退。主要风险是跨 Context 事务未共用、共享 UI 引用环、标准历史展示丢失、保留列 NOT NULL 插入失败；均需对应验证。若必须改变业务语义或扩大历史兼容范围，先更新本 change 并交用户裁决，禁止以空值/假成功代替。
