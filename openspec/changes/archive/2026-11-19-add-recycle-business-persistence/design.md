## Context

现有资源化 Web 为内存 mock。独立建表方向和本设计业务决策已由用户于 2026-11-18 明确确认；不是从旧 Material / MaterialClient 实体推导。杭州 API 是外部字段语义参考，不作为本地数据库模型。目标接口支持小数。

## Goals / Non-Goals

目标：项目内持久化业务、可演进的材料公司目录、历史快照、kg 无损重量和独立在线状态查询。非目标见 proposal；不把 mock 状态作为真实上报成功。

## Decisions

### 1. 存储、项目与审计

同一 SQL Server Database 内新建 RecycleDbContext 及独立迁移归属，由 Migrator 执行；不 ReplaceDbContext，不修改旧 Urban 业务表。表名前缀 Recycle。不分库分表，无 PlantId。

所有新表使用 Guid Id、必填 Guid ProId；ProId 对应现有项目标识，不将 GovProject.Id 与 SourceProId 混用。实施前核实授权声明到 ProId 的映射，服务统一解析可信项目上下文，不接受客户端自行声明项目即取得访问权。

聚合根继承 FullAuditedAggregateRoot<Guid>；明细和元数据使用相应 FullAuditedEntity<Guid>，复用 CreationTime/CreatorId、LastModificationTime/LastModifierId、IsDeleted/DeletionTime/DeleterId。IsEnabled 与软删除独立。同步尝试是保留的历史记录，不随业务删除物理清除。

所有关联仅标量逻辑 Id，无数据库 FK、EF 关系导航或级联删除。服务验证关联对象存在且 ProId 一致。索引以前导 ProId 组织，幂等唯一键为 ProId + SourceClientId + SourceRecordId；软删除不能使相同上传变成新单。材料名称、公司名称不默认强制唯一。可选编码若使用唯一约束，只在项目内对非空有效编码约束。

### 2. 候选表及业务列

以下各表均含上一节公共列，长度、精度和索引由迁移检查固定；不复制旧模型。

| 表 | 业务列 |
|---|---|
| RecycleMaterials | Name 必填、Code 可空、DefaultUsage 可空、Unit 必填默认 kg、IsEnabled |
| RecycleCompanies | Name 必填、Address 必填、ContactPhone 可空字符串、ContactName 可空、IsEnabled |
| RecycleVehicles | PlateNumber、OwnerName 车主、TransporterName 运输人、ContactPhone、TareWeightKg、IsEnabled |
| RecycleContracts | ContractNo、SignDate、生产方/购买方/运输方的可空公司逻辑引用及名称快照、ShipAddress、最新同步状态/时间 |
| RecycleContractDetails | ContractId、MaterialId 可空、MaterialName/Unit/Usage 快照、QuantityKg、UnitPrice、Amount |
| RecycleDailyProductions | MaterialId 可空、MaterialName 快照、ProductionDate、ProductBatch、QuantityKg、最新同步状态/时间 |
| RecycleTransportRecords | SourceClientId、SourceRecordId、PlateNumber、WeighedAt、GrossWeightKg、TareWeightKg 可空、NetWeightKg 可空、车辆快照、ContractId/ContractDetailId/MaterialId 可空、合同编号和材料名称快照、卸点、收货时间、最新同步状态/时间 |
| RecycleAttachments | BusinessType、BusinessId、Purpose、StorageKey、FileName、ContentType、Size；用途区分合同/现场/收货凭据 |
| RecycleSyncAttempts | BusinessType、BusinessId、AttemptedAt、Target、Result、脱敏错误摘要、CorrelationId |

设备在线数据见第 6 节。公司角色由合同使用位置决定，不固定在公司表。多运输方用显式明细记录 RecycleContractTransporters（ContractId、CompanyId 可空、CompanyName 快照），不用逗号分隔逻辑 Id。

### 3. 快捷目录与合同快照

材料、公司是独立可维护目录，当前仅帮助查找和自动填入。引用可空，允许手工填写；公司地址必填。保存时以单据实际字段为准，后续目录编辑/停用/软删除不更改历史单据。未来业务属性可扩展，当前不引入库存、定价或公司角色规则。

公司地址仅用于收货地址默认值，用户可改；合同 ShipAddress 独立保存并按杭州要求至少细化到街道/乡镇。DefaultUsage 仅默认值，合同 Usage 才是该交易用途。QuantityKg、UnitPrice、Amount 归合同明细。单价明确为元/kg；与目标元/吨字段转换时乘 1000，数量 kg 转吨除 1000，金额不随单位转换。历史数据导入必须显式说明源单位。

### 4. 称重与精度

一次称重一单。工控来源记录 Id 保持来源协议类型，通过稳定字符串规范化保存，不要求客户端改用 Guid。同一幂等键的重试返回已有结果，不重复建单；不同内容冲突明确报错。

接收时按项目和车牌查询启用车辆，快照当时皮重并计算净重。未找到或无可用皮重时保存毛重、净重留空并显示待补全，禁止用 0 伪造。净重负数不标为可上报；补录通过实体方法完成。车辆以后修改不得静默重算旧单。日产量与出厂净重无自动加减关系。ownerName 是车主，不是运输人。

所有重量和数量使用 decimal，设计起点 decimal(28,9)；单价采用 decimal(28,9)、金额 decimal(28,2)。写入前检查可表示范围与小数位，超出时明确拒绝，禁止让 SQL 隐式舍入。禁止 double、整数强转、Math.Truncate 或按页面位数改写重量。金额仅按明确金额规则处理，不用于反向改写重量。

外发 DTO 在目标类型 FromEntity 内根据每个接口声明的单位转换，目标吨字段使用 kg / 1000m 并保留换算后的全部有效小数，不使用整数模型或固定小数格式截断。单位映射需有 API 字段级检查，避免重复转换。目标拒绝时记录失败，不能截断后重试。

### 5. 服务、附件和同步

页面 → AppService → Repository → RecycleDbContext；写方法使用 UnitOfWork，跨表原子操作共享事务。AppService 按仓库要求继承 ApplicationService；内部需 I/O 的领域编排使用 Manager。状态由类型自身方法修改；DTO FromEntity / 输入 ToEntity 委托类型工厂，纯换算不注册 DI、不新增 Mapper，组合输入用命名 record 不用 tuple。

附件物理根沿用 StorageOptions，但使用 Recycle/ProId/业务Id 命名空间和独立元数据，下载校验项目归属，不复用城管附件业务表。业务行保存最新同步状态和发送时间，尝试历史独立保存；只有真实外部成功响应才能标成功。本 change 不启动市平台发送 Worker；保留后续发送器对接边界。

### 6. Admin 独立设备在线列表

新增 Recycle 专属状态查询 AppService、权限和页面路由（例如 /recycle/device-status），不进入 Urban 的 PageList。按 ProductCode 5020 与 ProId 校验设备归属，Urban 查询也不得混入 Recycle。

在线状态使用可信 Recycle 心跳的服务端接收时间，不以“项目已授权”推断在线。若现有 Realtime 管道可按产品与 ProId 严格区分则复用传输设施；否则加独立 Recycle 心跳入口，不改写 Urban 判定规则。状态实体 RecycleDeviceStatuses 使用公共审计列、DeviceId/DeviceName、LastSeenAtUtc；ProId + DeviceId 唯一。超时阈值使用明确 Recycle 配置；无心跳显示未知，超过阈值显示离线。页面显示项目、设备标识、最近在线时间和状态。不得将授权令牌或激活码展示为设备标识。

## Migration / Rollback

新增独立迁移，先建表再部署服务和页面；空库启动、既有 Urban 数据库升级均验证。不得导入 mock 作为真实业务。失败回滚应用路由，保留新业务表与数据，禁止自动删除已接收记录。Apply 前核实部署宿主 DbContext 注册、项目标识映射和心跳能力；发现能力缺失须留下真实阻断，不伪造状态。

## Acceptance

目标 ICD L3：项目隔离、跨项目攻击、目录快照、称重幂等、精度失败路径与 Recycle/Urban 在线列表隔离均提供可追溯证据。当前仅设计，无交付声明。
