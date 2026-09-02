## Why

客户端卡口/成品进出已本地入库，但 UrbanManagement 仍只接收称重并走历史单一 Gov `PostWeight`。进出既不上云也不按萧山三通道上报，地磅报文也未对齐 `lantu/saveRecord`。需要把「客户端 → UM → Gov」按记录种类拆开，并在 UM 提供卡口/成品查询页。

## What Changes

- UrbanManagement 新增进出实体（建议 `UrbanPassageRecord`，与客户端同名）：一张表、`PassageSource` 区分卡口/成品；无重量列；逻辑附件 Id，禁止库 FK。
- **两条独立上云入口**：**来自 LPR 卡口**、**来自 LPR 成品**（各自 ApplicationService，允许重复实现）。地磅继续现网 `ReceiveAsync`。禁止共用一个 Receive 靠重量或后缀分流。
- UM **新增卡口页、成品页**（与称重页并列；本期查看、不上审批）。列口径对齐客户端专用 tab；上报状态 SHOULD 与称重页对称。
- Gov 出站三条 **独立代码路径**（允许重复）：地磅 `lantu/saveRecord` + `buildLicenseNo=L` + `dataSource` 恒为 `WEIGHBRIDGE_XIAOSHAN`；卡口 `inoutRecord/save` + `L`；成品同 path + `L-02`（只拼一次）。平台凭后缀认成品。禁止把进出写入 `UrbanWeighingRecord` 再混打现网 `PostWeight`。
- 出站 **Converter** 仅在 UM 组 Gov 报文时使用（领域枚举 → 地磅 `inOutType` 0/1、卡口/成品 `deviceID` 01/02）；卡口与成品 Converter 分开；不注册 DI。去掉现网写死 `InOutType=0`。
- Gov **host** 在 UM 独立配置（默认三通道共用；现场可拆两个 BaseAddress）。
- MaterialClient：进出上云走新 API（先复用附件 multipart）；地磅上云不变。客户端 **仍不直连** 萧山 Gov。
- 不做心跳 `/sapi/sysdevicemng/heatBeat`。进出不上称重审批/异常流。
- Git：**Mode A**（各仓自 trunk 切同名分支 `add-urbanmanagement-passage-xiaoshan-upload`，squash 回 trunk）。

## Capabilities

### New Capabilities

- `urban-passage-cloud`: UM 进出落库、来自 LPR 卡口/成品的独立 Receive、卡口页与成品页。
- `xiaoshan-three-channel-gov-upload`: UM 三通道独立出站、Converter、`buildLicenseNo` 规则、host 配置。

### Modified Capabilities

- `gov-sync-worker`: 称重出队对齐地磅通道；卡口/成品独立出队，不再只用 `UrbanWeighingRecord` + 单一 `PostWeightAsync`。
- `urban-passage-record`: 撤销「本期不上云」；客户端进出上传 UM，仍不直连萧山。
- `urban-client-attachment-sync`: 进出上云前复用同一附件通道。

## Impact

- **UrbanManagement**：DbContext/migration、两个进出 ApplicationService、两个列表页、三条 Gov 出站（payload record + Converter）、Worker 分流、`appsettings` Gov host。
- **MaterialClient.Urban**：Polling/`SubmitRecordAsync` 对卡口/成品走新 API；附件 Guid；地磅 Receive 不变。
- **FdSoft.BasePlatform**：无本期变更。
- 研究笔记：`docs/2026-08-28-urbanmanagement-passage-xiaoshan-upload/`（Q1–Q5 已决）。
- 管线 Graph 不在本期改 cook；协议以设计稿 + 本 change 为准。
