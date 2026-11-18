## Why

Recycle Web 四页目前使用内存 mock，尚无独立、可持久保存的业务模型。用户已确认独立建表、项目隔离、材料与公司快捷填入及未来扩展、kg 无损重量，以及 Admin 独立查看 Recycle 在线状态，需要形成可实施的产品契约。

## What Changes

- 在 UrbanManagement 中新建 Recycle 专属业务模型、DbContext 和迁移，统一 Recycle 表名前缀；同库同表，以 ProId 隔离，不分库分表，不引入 PlantId。
- 建立材料、公司、车辆池、合同及独立合同明细、日产量、运输清单、附件元数据、同步尝试记录；采用 Guid 主键与 ABP 审计、软删除能力。
- 材料和公司当前用于快捷查找填入；单据保存可空逻辑引用和独立快照。数量、单价、金额归合同明细。
- 运输清单一次称重一单，保存来源幂等标识、毛重、皮重快照和净重。Recycle 重量统一 kg，上传按目标单位精确换算，保留小数。
- 将 Recycle Web 现有业务页面接到真实持久化服务；首个实施切片为材料、公司、车辆池和运输清单，再接合同与日产量。
- Admin 新增独立 Recycle 设备在线状态列表、查询入口和权限边界，与 Urban PageList 和数据分离。
- 不以 MaterialClient 或旧 Material 的模型作为设计模板，不清理既有技术债务。

## Capabilities

### New Capabilities

- `recycle-project-persistence`: Recycle 独立模型、ProId 隔离、审计、逻辑关联及迁移。
- `recycle-reference-catalogs`: 材料与公司独立维护、快捷填入和单据快照。
- `recycle-business-ledgers`: 车辆、合同、日产量、运输清单、附件与同步记录的持久化规则。
- `admin-recycle-device-status`: Admin 独立 Recycle 设备在线状态查询。

### Modified Capabilities

无。既有 mock change 保持历史范围，本 change 新增真实业务持久化能力。

## Impact

- 实现仓：`repos/UrbanManagement`（Core、XiaoShanResource、Admin、Migrator，按实际需要接入 Attachment / Realtime 的独立 Recycle 路由）。本轮仅生成主仓 OpenSpec。
- Mode B：沿用 `dev-recycle-resource-alignment`；Apply 前在实际改动仓创建同名 `add-recycle-business-persistence` 分支，squash 回 initiative。无提交或推送授权。
- 依据：`docs/2026-11-18-recycle-web-table-design/`、`docs/SyncDoc/杭州市资源化利用厂数据接入接口V1.0.md`，以及 2026-11-18 本次对话的 Human APPROVED 决策。
- 不包含：其他 Admin 业务表查询、MaterialClient 表模型改造、BasePlatform 改造、第二跳市平台 Worker/HMAC 的完整实现、宿主重命名。第一跳客户端联调由后续集成工作接入本 change 的持久化服务。
