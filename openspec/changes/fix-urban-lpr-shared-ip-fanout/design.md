## Context

Vzvision / Hikvision LPR 服务以 **IP** 为 SDK 连接与配置字典的唯一键：`AddOrUpdateDevice` 后写覆盖，回调只解析出一条 `cfg.Name`，再发布单条 `LicensePlateRecognizedEventData`。

消费端按 `DeviceName` → `FindByDeviceName` → `LprSiteType` 分流：

- `AttendedWeighingService`：非 `Scale` 则跳过
- `UrbanPassageLprHandler`：`Scale` 则跳过；`FinishedProduct` / `Checkpoint` 建通行

同 IP 配地磅 + 成品时，UI/`UrbanLprCapabilities` 可两边都启用，但事件只有赢家 `SiteType`，另一侧永远吃不到。

方案 A：**保持一 IP 一连接**，在发布层按 settings 中同 IP 的配置行扇出多条事件。

## Goals / Non-Goals

**Goals:**

- 同 IP 多 LPR 行时，一次物理识别 → 每条有效配置各发一条事件（同车牌/图片，`DeviceName` 不同）。
- 地磅与成品/卡口可同时消费，无需改消费者的 `SiteType` 语义。
- 道闸不因扇出重复开闸；主动触发不因同 IP 多行重复 ForceTrigger。
- 单行同 IP、非 Urban、测试注入 API 行为可预期且向后兼容。

**Non-Goals:**

- 不改为按 IP 多开 SDK 句柄。
- 不强制合并/禁止同 IP 多行（允许配置，靠扇出表达意图）。
- 不改 UrbanManagement 上传契约或通行实体模型。
- 不在本 change 清扫无关 LPR 技术债。

## Decisions

### D1 — 发布端扇出，而非消费端按 IP 匹配

**选择**: 在 Vz / Hik 回调（及共享发布辅助）中，用识别到的 IP 在当前 settings 的 `LicensePlateRecognitionConfigs` 中收集同 IP 行，对每行 `PublishAsync` 一次。

**理由**: 现有 `FindByDeviceName` + `SiteType` 过滤可原样工作；测试注入若指定单一 `DeviceName` 仍只发一条。

**备选（否决）**: 消费端 `FindAllByIp` — 要改称重与通行两处，且道闸仍绑单一 `DeviceName`，语义更散。

### D2 — 扇出数据源与去重规则

**选择**:

1. SDK 仍用 IP map 保存「连接用」配置（登录/回调绑定不变）。
2. 扇出名单来自 **settings 快照**（或启动时缓存的全量列表），按规范化 IP 字符串匹配（trim，比较忽略大小写若适用）。
3. 仅对 `IsValid()` 的行扇出；同 IP **同 `Name`** 只发一次（防御重复行）。
4. 同 IP **无任何 settings 行**时回退：仅用 SDK map 中的那条配置发一条（与今日一致）。
5. 若 settings 有同 IP 行但 SDK map 赢家不在列表中（异常），仍按 settings 列表扇出；图片路径等来自本次回调一次提取后复用。

**API 草图**（命名 record，无 tuple）:

```csharp
public static class LicensePlateRecognitionConfig
{
    public static IReadOnlyList<LicensePlateRecognitionConfig> FindAllByIp(
        IReadOnlyList<LicensePlateRecognitionConfig>? configs,
        string? ip);
}

public sealed record LprRecognitionPublishBatch(
    string PlateNumber,
    /* color/vehicle fields */,
    LprDeviceType DeviceType,
    DateTime Timestamp,
    string? LprImagePath,
    IReadOnlyList<string> DeviceNames);
```

实现可为 static helper（如 `LprRecognitionEventPublisher`）被两家 LPR 服务调用；**禁止**为纯扇出逻辑新建 DI Transient「MappingService」。若 helper 仅依赖 `ILocalEventBus` + settings 读取，可挂在现有 LPR 服务内 private 方法，或最小 static + 由服务传入 configs。

### D3 — 道闸去重

**选择**: `GateIoControlService` 在处理 `LicensePlateRecognizedEventData` 时，对同一物理识别做短时去重：键为 `(规范化车牌, 设备 IP 或同一秒内的扇出批次)`。

具体：

- 事件可增加可选 `DeviceIp`（推荐）便于闸控与日志，**不改变**消费者按 `DeviceName` 路由。
- 去重窗口建议 **2 秒内同车牌只开闸一次**；若多行均 `EnableGateIo`，优先处理 **`SiteType == Scale`** 且 `EnableGateIo` 的行，否则取扇出中第一条启用道闸的行，其余跳过并打 Debug。

**理由**: 扇出两条事件时 `_configByName` 可能对两条都 EnableGateIo，不设去重会双开。

### D4 — 主动触发按 IP 去重

**选择**: `WeighingCaptureService.TriggerLprCaptureForAllAsync`（或等价）遍历配置时按 **IP** 去重：每个 IP 只 `TriggerCaptureAsync` 一次；回调扇出仍覆盖所有同 IP 业务行。

### D5 — MessageBus / UI

**选择**: `EventBusToMessageBusBridge` 仍转发每条扇出事件。设置页/调试 UI 可能看到同车牌多条提示；可接受。若后续要合并展示，另开 change。

### D6 — 测试注入 API

**选择**: `/api/lpr/test-*` 等显式指定 `DeviceName` 的路径 **不扇出**（只发指定行），避免测试误建双记录。仅 SDK 物理回调路径走扇出。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 道闸双开 | D3 短时去重 + Scale 优先 |
| 主动触发双拍 | D4 按 IP 去重 |
| settings 与 SDK map 短暂不一致 | 扇出以 settings 为准；连接仍 map |
| UI 重复车牌消息 | 接受；文档说明 |
| 同 IP 配两个成品行 | 扇出两次 → 两条通行；属配置错误，日志可 Warn 同 IP 同 SiteType 多行 |
| 性能 | 同 IP 通常 2 行；Publish 同步开销可忽略 |

## Migration Plan

1. 部署含扇出的 MaterialClient 版本；无需数据迁移。
2. 现场保持地磅 + 成品两条同 IP 配置即可生效。
3. 回滚：旧版本恢复「仅赢家消费」；配置无需回滚。

## Open Questions

- 无阻塞项。道闸优先 Scale 已在 D3 拍板；若现场道闸只挂在成品行，去重仍会选「第一条 EnableGateIo」，Scale 优先仅在同时启用时生效。
