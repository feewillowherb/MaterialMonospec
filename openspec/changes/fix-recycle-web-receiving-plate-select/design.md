## Context

`RecycleTransportRecord` 没有 `VehicleId`，与车辆唯一的联系是 `PlateNumber` 字符串。皮重、净重、所有人与运输人快照只在 `Receive` 时由私有的 `ApplyTareSnapshot` 写入一次。收货保存走 `PUT /api/transports/{id}` → `CompleteAsync`，目前不碰车牌。

车辆管理只有 `GET /api/vehicles?plateNumber=`（包含匹配，项目内）一个查询参数，返回结果带 `Enabled`（「启用」/「停用」）。客户端没有现成的车辆下拉组件，收货面板的合同下拉（`el-select filterable`）是最接近的样式。

## Goals / Non-Goals

**Goals**

- 收货时能看到并纠正车牌。
- 车牌只能选车辆管理里已有的车。
- 换车后皮重、净重、运输人与新车一致。
- 已收货记录不可改。

**Non-Goals**

- 不新增手动输入车牌的入口。
- 不改「过磅」弹窗的自由车牌输入。
- 不同步修改客户端本地记录的车牌。
- 不改市平台上报。

## Decisions

### 车牌并入收货保存，不单开端点

`PUT /api/transports/{id}` 的 `TransportEnrichWrite` 增加可选 `plateNo`。未传或与当前车牌相同时不处理；传了不同的车牌才换车。这样一次保存完成合同、毛重、车牌，避免页面分两次提交出现半成功。

### 只能选已有且启用的车辆

- 下拉用 `el-select` + `filterable` + `remote`，输入时请求 `GET /api/vehicles?plateNumber=<关键字>`，打开面板时用当前车牌预载。
- 端点增加 `enabledOnly` 参数；收货面板传 `true`，车辆管理页不传，行为不变。
- 服务端 `CompleteAsync` 以 `ProId + IsEnabled + PlateNumber` 查车辆，查不到抛 `RECYCLE:VEHICLE`（「车辆不在当前项目或已停用」），整次保存不落库。页面不能绕过。

### 换车由实体自己完成

`RecycleTransportRecord` 增加实例方法 `ChangeVehicle(RecycleVehicle vehicle)`：写 `PlateNumber`，并复用 `ApplyTareSnapshot` 刷新皮重、净重、所有人与运输人。`CompleteAsync` 只负责查车辆、调用该方法、保存，不逐字段赋值。`QuantityKg` 不随换车变化。

主规格要求「事后编辑车辆不得改写已有运输单的快照」，那针对的是后台静默改写；这里是用户在收货时显式换车，属于本次保存的一部分。

### 已收货不可改

`ReceivingTime` 已有值时，服务端拒绝带不同车牌的保存（`RECYCLE:TRANSPORT_RECEIVED`），与页面的「查看」模式一致。此前「已收货只读」只在页面上实现，本单在服务端补上对车牌的校验；合同与毛重的服务端校验不在本单范围。

## 待确认决策（Decision Needed）

已收货的服务端校验范围尚未由用户拍板；当前工件按「建议」一栏书写。

| # | 问题 | 建议 | 其他选项 |
|---|------|------|----------|
| 1 | 已收货的服务端校验范围 | 只对换车牌补服务端拒绝；合同与毛重仍由页面拦 | 服务端同时拒绝已收货记录的合同与毛重变更 |

子仓未提交改动已定：并入本次提交，与同名分支上的新实现一起提交，后续 squash 进主干。

## Risks / Trade-offs

- **重复车牌**：`(ProId, PlateNumber)` 索引不唯一，同一项目可能有两辆同车牌的车。换车时取其中任一辆，快照可能取自另一条；车辆管理页应避免重复录入，本单不加唯一约束。
- **客户端本地车牌不同步**：Web 改了车牌后，客户端本地记录仍是原车牌。两边不一致是已知并接受的，Web 台账为准。
- **与在途 change 的关系**：`fix-recycle-web-transport-completion` 与 `add-recycle-web-transport-delete` 的实现尚未提交，随本 change 一并提交（见 tasks 第 0 节）；本单在其之上实施，delta 只新增 requirement，不复制它们正在修改的 requirement。
