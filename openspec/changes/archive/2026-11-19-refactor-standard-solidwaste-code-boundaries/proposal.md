## Why

标准与固废客户端已有独立宿主和产品 DbContext，但固废宿主仍源码链接标准 exe 内部的启动、WebHost、轮询实现；Common 仍持有固废 Store、字段访问和导出语义。物理项目拆分尚未完整表达数据所有权和依赖方向，需要完成有明确范围的代码隔离与标准化。

依据为 `docs/2026-11-17-standard-solidwaste-isolation-quality/`。用户在 2026-11-18 明确当前 ExtraProperties 仅有 `UseIndependentDisplayedNet` 这一个业务字段，并要求生成 change 交给 Cursor 执行。本提案以此为目标基线，不将历史样本中的旧键再次作为待清理负担；实际源码残留需在 apply 时核对。

## What Changes

- 四项固废业务字段（SolidWasteType、Street、SolidWasteOrderNumber、Shipper）仅由固废扩展表承载；退出正常业务对旧 ExtraProperties getter/setter、回退和复制写入的依赖。
- `UseIndependentDisplayedNet` 继续以运单 ExtraProperties 为唯一权威；退出扩展实体及快照对此标记的业务依赖，保留旧物理列而不读取、不写入，避免不必要的破坏性 schema 迁移。
- 将 StartupService、MinimalWebHostService、PollingBackgroundService 共用实现移至稳定共享类库，取消固废对标准 exe 源文件的 Compile Link；两宿主独立组合产品配置与依赖。
- 固废字段操作、扩展持久化、导出实现归固废模块；公共称重链只通过最小、产品中立的生命周期契约接入事务内产品操作。共享 UI 所需服务契约与只读 record 位于独立契约边界，不反向依赖固废实现。
- 标准化限于上述触达代码的职责、事务、类型归属方法、DI 和依赖方向，不进行全仓技术债务清理。

## Capabilities

### New Capabilities
- `standard-solidwaste-code-boundaries`: 两产品的宿主共享、公共流程接入与产品实现归属边界。

### Modified Capabilities
- `standard-solidwaste-schema-isolation`: 明确固废扩展为四字段权威、净重标记单独保留，以及新宿主不再以旧键补数的边界。

## Impact

- 代码仅在 `repos/MaterialClient` 实施；涉及 Standard/SolidWaste 宿主、Common、产品 Common、共享 UI/AttendedWeighing 的相关调用点，以及新共享类库（如现有边界无法容纳）。UrbanManagement、FdSoft.BasePlatform 不改动。
- Git 使用 Mode A；apply 首次改代码前从该仓 origin/HEAD 指向的 trunk 创建 `refactor-standard-solidwaste-code-boundaries` 同名分支。未授权 commit、push、merge、archive。
- 与现有 app/schema isolation change 协调：不改它们的历史任务与证据，不接管安装器、现场升级和恢复矩阵；本 change 的 delta 专门取代当前 schema spec 中仍描述标准宿主迁移固废、从旧键补数的要求。
- 不做历史键扫描清理、旧物料/数量恢复、数据搬库、安装器改造、界面重设计、Urban/Recycle 重构、通用插件框架或全局宿主状态重写。已部署迁移文件保持不变。
