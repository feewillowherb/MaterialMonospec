## Why

MaterialClient 的海康 LPR 回调将 `HikvisionSdk.cs` 中手写的 P/Invoke 结构体（如 `NET_ITS_PLATE_RESULT`）与 `HCNetSDK.h` / 官方 `CHCNetSDK.cs` 布局不一致，导致车牌乱码、一次抓拍产生多条无效事件、设备 IP 无法匹配。该问题已在现场日志（`log4.log`）与调研文档（`docs/HikLpr/`）中确认；GovClient 使用官方 Demo 结构体可正常工作。需在修复实现的同时建立约束，防止再次手写错误的 SDK 类型定义。

## What Changes

- 用官方 SDK Demo（`CHCNetSDK.cs`，来源 GovClient 或 `CH-HCNetSDKV6.1.9.48` 交通产品 Demo）**替换** `HikvisionSdk.cs` 中错误的 LPR 相关结构体定义
- 删除自创类型：`NET_ITS_PLATE_INFO`、`NET_DVR_PLATE_INFO_EX` 及错误的 `NET_ITS_PLATE_RESULT` 数组布局
- 修正 `HikvisionLprService` 回调解析：从 `struPlateInfo.sLicense` 读取车牌（GBK），ITS 路径只处理单条结果，不再遍历假数组
- 修正 `NET_DVR_ALARMER` 解析，使设备 IP/名称与配置匹配
- 修正 LPR 图片提取路径（`struPicInfo[]` / `pBuffer1`），与 GovClient 行为对齐
- 增加结构体布局防回归措施（`Marshal.SizeOf` 断言或 golden test）
- 评估并收敛 `HikvisionService.cs` 内 `NET_DVR` 与 `HikvisionSdk.cs` 的重复 P/Invoke 定义（LPR 相关类型统一到单一模块）

## Capabilities

### New Capabilities

（无 — 本变更为既有 LPR 能力的正确性修复，不引入新业务域。）

### Modified Capabilities

- `license-plate-recognition`: 明确海康 SDK 结构体必须来自官方 `CHCNetSDK.cs`/`HCNetSDK.h` 对齐定义；修正 ITS/旧版车牌回调的解析行为与验收场景（单次抓拍单条有效事件、正确 GBK 车牌、正确设备 IP）

## Impact

- **子仓库**：`repos/MaterialClient`
  - `MaterialClient.Common/Services/Hikvision/HikvisionSdk.cs`（结构体重写）
  - `MaterialClient.Common/Services/Hikvision/HikvisionLprService.cs`（回调逻辑修正）
  - 可能触及 `HikvisionService.cs`（P/Invoke 去重）
  - 测试：`MaterialClient.Common.Tests`（可选 SizeOf / marshalling 断言）
- **参考实现**：`Fdsoft.Weight.GovClient/BLL/CaptureDevice.cs`、`BLL/CHCNetSDK.cs`
- **调研依据**：`docs/HikLpr/00-调研总览.md` 至 `04-修复建议.md`
- **无 API 契约变更**：`LicensePlateRecognizedEventData` 字段不变；修复后事件内容从不正确变为正确
- **无 UrbanManagement 变更**
