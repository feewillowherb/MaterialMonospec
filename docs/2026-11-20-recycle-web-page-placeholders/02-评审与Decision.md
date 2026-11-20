# Recycle Web 页面占位字段评审与 Decision

2026-11-20 · 建议第一批进入 OpenSpec Propose，实施待 Human `APPROVED`。源码核对基线为 UrbanManagement `5e45981`。

## 评审发现

| 优先级 | 发现 | 对第一批的影响 |
|---|---|---|
| P1 | 运输单的 `SyncStatus` 是汇总字段，出厂和收货都会写它。上报服务现在还会因缺出场或进场照片跳过发送。现有按钮依赖接口没有返回的 `loopPhase`，这个字段还用于收货弹窗的只读分支。 | 移除占位筛选时同时处理弹窗分支。第一批暂时隐藏运输批量上报按钮，保留两个后端路由。上报方向、前置条件和重试归现有 `add-recycle-web-platform-reporting`。 |
| P2 | 车辆 `CreationTime`、运输人 `TransporterName` 都没有经过对应读 DTO。运输 DTO 已有 `WeighedAt` 和 `UnloadPoint`。日产量 `LastSyncedAt` 同样未投影，但生产管理当前版本隐藏。 | 第一批只补仍显示页面的投影，核对 DTO 的现有调用方。无需数据库迁移。 |
| P2 | 合同列表用原始枚举值，筛选却使用中文。日产量列表有同样问题，该页当前版本隐藏。 | 合同上报状态的标签与筛选共用枚举到中文的映射。 |

源码依据：[Recycle DTO](../../repos/UrbanManagement/src/UrbanManagement.Core/Models/Recycle/RecycleDtos.cs)、[页面投影](../../repos/UrbanManagement/src/UrbanManagement.Recycle/RecycleWebEndpoints.cs)、[运输页面](../../repos/UrbanManagement/src/UrbanManagement.Recycle/client/src/views/Transports.vue)、[市平台上报服务](../../repos/UrbanManagement/src/UrbanManagement.Core/Services/RecycleCityReportAppService.cs)。

## Decision

**第一批修复真实字段的显示和筛选，移除无效控件。生产管理在当前版本隐藏，不进入第一批。**

当前版本侧栏不显示「生产管理」，`/productions` 回到车辆管理。日产量接口和 `Productions.vue` 保留。这一页重新打开时再处理标识编号、发送时间和上报状态文案。

- 车辆显示 `CreationTime`。移除可编辑的车辆状态、对应列表列和筛选项、批量导入入口，以及固定显示「未上报」的市上报列。车辆上报动作沿用现有行为。
- 合同状态使用三种中文标签。 `None`、`Pending` 为「未上报」，`Succeeded` 为「已上报」，`Failed` 为「上报失败」。用原始枚举值做筛选，「未上报」同时匹配两态。只有已记录平台业务 `code` 200 才显示「已上报」。
- 运输显示 `WeighedAt`、运输记录中的 `TransporterName` 快照及 `UnloadPoint`。原「出货时间」改称「过磅时间」，原「收货方」列表列改为「卸点」。收货表单仍预览合同购买方和地址，服务按所选合同的 `ShipAddress` 保存卸点。运输状态依次按 `AwaitingTare`、`ReceivingTime` 显示「待补皮重」「待收货」「已收货」。移除旧阶段筛选、运输批量上报按钮及仅供该按钮使用的勾选列。
- 移除弹窗依赖 `loopPhase` 的 `closedOnly` 分支。保存时仍提交 `ContractId`、`ContractDetailId`、`MaterialId` 并执行服务校验。`ReceivingTime` 表示收货事实，本批沿用现有的编辑权限，收货状态不产生新的只读规则。保存提示以实际 HTTP 结果和错误体为准。详见 [运输补全 change](../../openspec/changes/fix-recycle-web-transport-completion/proposal.md)。
- 移除合同 PDF 和收货凭证的文件选择控件，以及合同列表中只弹出文件名的「查看」入口和占位列。同步清理这几项的页面状态和无效写入字段。新建合同的生产方与手动过磅车牌、毛重从空值开始，校验必填项后再提交，保留既有重量精度。
- 合同批量上报失败或部分成功时也重新读取列表，因为服务可能已写入状态。

**后续两项各自提案。** 附件走现有文件存储和元数据，验证项目隔离及容器重建后仍可读取。车辆「运输中」由同项目、同车牌、已称重且尚未收货的记录推导，提案时明确异常净重和历史未闭合记录的处理。

## Cursor 交接

在 MaterialMonospec 运行 `/opsx-propose fix-recycle-web-page-placeholders`，以本 Decision 的第一批为范围，为 `recycle-web-persistence-api` 编写 delta 并运行 `openspec validate fix-recycle-web-page-placeholders --strict`。核对 [现行规范](../../openspec/specs/recycle-web-persistence-api/spec.md) 及 [平台上报 change](../../openspec/changes/add-recycle-web-platform-reporting/proposal.md)。获得 Human `APPROVED` 后再执行 Apply。

验收任务覆盖车辆、合同、运输清单刷新后真实字段回读、空值、上报失败或部分成功后状态与筛选一致、三种运输事实状态、收货主路径及跨项目拒绝。侧栏不出现「生产管理」，打开 `/productions` 进入车辆管理。核对新接入时间字段的序列化与显示时区，覆盖 UTC 跨日样例。检查首次和再次打开新建弹窗时的空默认值，并检查无效控件、筛选和勾选列已经移除。涉及界面和 API 的验证使用现有项目数据或隔离测试数据，记录构建及测试结果。138 的页面验证安排在 Recycle 前端重新构建且镜像更新之后，按现有发布流程执行。
