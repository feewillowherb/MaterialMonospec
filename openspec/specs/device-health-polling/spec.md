# device-health-polling Specification

## Purpose
TBD - created by archiving change enhance-device-health-and-camera-polling. Update Purpose after archive.
## Requirements
### Requirement: 摄像头、LPR 与道闸 IO 定时健康巡检

客户端 SHALL 定期巡检已配置的摄像头、车牌识别设备与道闸 IO 状态，并发布结构化健康快照。

#### Scenario: 摄像头定时巡检与多路明细聚合
- **WHEN** 定时巡检周期到达且客户端配置了多路摄像头
- **THEN** 系统 SHALL 逐路调用 `IHikvisionService.IsOnline` 探测连通性
- **AND** 若全部在线则聚合状态为 `Online`，部分在线为 `Degraded`，全部离线为 `Offline`
- **AND** 系统 SHALL 在 `AdditionalData` 中以结构化 JSON 携带 `onlineCount`、`totalCount` 与每路 `name`、`endpoint`、`isOnline`、`detail`

#### Scenario: 道闸 IO 纳入统一设备健康上报
- **WHEN** 客户端存在启用 `EnableGateIo` 的车牌识别配置
- **THEN** 系统 SHALL 结合 `IGateIoControlService.GetHealthSnapshot()` 与关联 LPR 在线状态生成 `DeviceType = "GateIo"` 的健康快照并上报
- **WHEN** 客户端未配置任何 `EnableGateIo` 设备
- **THEN** 系统 SHALL 不上报 `GateIo` 离线告警，避免无道闸站点产生误报

### Requirement: 服务端支持 GateIo 与结构化明细解析

服务端与 Admin SHALL 接受 `GateIo` 设备类型与 `Degraded` 状态，并解析展示多路外设明细与异常筛选视图。

#### Scenario: Admin 设备详情弹窗展示多路明细与异常筛选
- **WHEN** 管理员在项目管理页打开设备详情弹窗
- **THEN** 弹窗 SHALL 正确显示 `GateIo`（道闸IO）与 `Degraded`（部分离线）状态
- **AND** 当 `AdditionalData` 包含结构化 `items` 时 SHALL 列出每路设备的名称、地址与在线/离线状态
- **AND** 管理员 SHALL 可切换「仅看异常」筛选视图以快速定位离线或部分离线设备
- **AND** 对 1.0 客户端无结构化 `AdditionalData` 的记录 SHALL 正常降级展示基础状态，不报错

