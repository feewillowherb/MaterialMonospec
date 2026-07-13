## Context

MaterialClient 的 `HikvisionLprService` 通过 `HikvisionSdk.cs` 中的 P/Invoke 结构体解析海康 SDK 回调。当前实现中 `NET_ITS_PLATE_RESULT`、`NET_DVR_PLATE_RESULT`、`NET_DVR_ALARMER` 等类型为手写简化版，与 `HCNetSDK.h`（V6.1.9.48）及官方 Demo `CHCNetSDK.cs` 布局不一致。

现场表现（`docs/HikLpr/`、`log4.log`）：
- 一次抓拍产生 ~11 条乱码 LPR 事件
- 车牌字段出现时间戳（`yyyyMMddHHmmssfff`）、UUID 片段等非车牌内容
- 设备 IP 解析失败，显示 `Unknown (设备名...&192.168.1.100)`

GovClient（`CaptureDevice.cs` + `BLL/CHCNetSDK.cs`）使用官方 Demo 结构体，同一设备解析正常。

约束：
- SDK 版本固定为 `CH-HCNetSDKV6.1.9.48`（与 `MaterialClient.Common/HCNetSDK/` 中 DLL 一致）
- 不改变 `LicensePlateRecognizedEventData` 公共契约
- OpenSpec 工件仅在 MaterialMonospec 主仓库；代码在 `repos/MaterialClient`
- 禁止使用 tuple；多值组合使用命名 `record`

## Goals / Non-Goals

**Goals:**
- 将 LPR 相关 P/Invoke 结构体替换为与官方 `CHCNetSDK.cs` / `HCNetSDK.h` 对齐的定义
- 修正 `HandleItsPlateResult` / `HandlePlateResult` 字段读取路径与事件发布逻辑
- 修正 `NET_DVR_ALARMER` 解析，使设备 IP 可匹配配置
- 建立防回归机制（禁止自创 `NET_*` 类型、SizeOf 校验）
- 与 GovClient 抓拍结果行为对齐（车牌 GBK、`struPlateInfo.sLicense`、ITS 单条处理）

**Non-Goals:**
- 不升级 HCNetSDK 大版本
- 不重构 `HikvisionService` 预览/JPEG 全量 P/Invoke（除非 LPR 去重所需的最小合并）
- 不修改 UrbanManagement / Web API
- 不处理与本次修复无关的技术债务（如全面合并 `NET_DVR` 与 `HikvisionSdk` 的全部 API）

## Decisions

### 1. 结构体来源：裁剪官方 `CHCNetSDK.cs`，禁止手写

**决策**：从以下来源之一复制 LPR 相关类型及依赖类型到 `MaterialClient.Common`：
- 首选：`CH-HCNetSDKV6.1.9.48` → `Demo示例/12-交通产品/TrafficDemo/CHCNetSDK.cs`
- 备选：`Fdsoft.Weight.GovClient/BLL/CHCNetSDK.cs`（同 SDK 版本，已验证）

**裁剪范围**（最小集）：
- 常量：`COMM_UPLOAD_PLATE_RESULT`、`COMM_ITS_PLATE_RESULT`、`MAX_LICENSE_LEN` 等
- 结构体：`NET_DVR_ALARMER`、`NET_DVR_PLATE_INFO`、`NET_DVR_PLATE_RESULT`、`NET_ITS_PLATE_RESULT`、`NET_ITS_PICTURE_INFO`、`NET_DVR_VEHICLE_INFO`、`NET_DVR_TIME_V30`、`NET_VCA_RECT`（若 `NET_DVR_PLATE_INFO` 依赖）
- 删除 MaterialClient 自创类型：`NET_ITS_PLATE_INFO`、`NET_DVR_PLATE_INFO_EX`

**理由**：官方 Demo 与 `HCNetSDK.h` 一致；GovClient 已证明可用。  
**备选**：构建时用 ClangSharp 从头文件生成 — 成本高、过滤复杂，本次不采用。

### 2. 模块组织：扩展 `HikvisionSdk.cs`，不引入新 NuGet

**决策**：将裁剪后的结构体放入现有 `HikvisionSdk.cs`（或拆为 `HikvisionSdk.Structs.cs` partial），命名空间 `MaterialClient.Common.Services.Hikvision`。

**理由**：与现有 `HikvisionLprService` 引用一致；海康无官方 .NET 包。  
**备选**：独立 `MaterialClient.Hikvision.Native` 项目 — 过度设计。

### 3. 回调解析逻辑

**决策**：

| 命令 | 结构体 | 车牌路径 | 图片 | 事件数 |
|------|--------|----------|------|--------|
| `COMM_ITS_PLATE_RESULT` (0x3050) | `NET_ITS_PLATE_RESULT` | `struPlateInfo.sLicense` (GBK) | `struPicInfo[i]`, `i < dwPicNum`, `byType == 1` 场景图 | **1 条** |
| `COMM_UPLOAD_PLATE_RESULT` (0x2800) | `NET_DVR_PLATE_RESULT` | `struPlateInfo.sLicense` (GBK) | `pBuffer1`/`dwPicLen` 或 `pBuffer5`/`dwFarCarPicLen` | **1 条** |

- 过滤：`string.IsNullOrWhiteSpace(plate)` 或 `plate.Contains("车牌")` 时跳过（与 GovClient 一致）
- 设备 IP：`NET_DVR_ALARMER.sDeviceIP`（UTF-8/ASCII），参考 `byDeviceIPValid`
- **删除** `for (i < dwResultNum && i < struPlateInfo.Length)` 循环

### 4. 编码：保留 `HikvisionEncodingHelper` + `CodePagesEncodingInitializer`

**决策**：继续用 `HikvisionEncodingHelper.GetString(bytes, logger)` 做 GBK 解码；应用入口已注册 CodePages。

**理由**：结构体修复后 GBK 层已验证正确；无需改动编码策略。

### 5. 防回归

**决策**：
- 在测试中断言关键结构体 `Marshal.SizeOf<T>()` 与官方 `CHCNetSDK.cs` 同版本值一致
- `HikvisionSdk.cs` 文件头注释标明 SDK 版本与来源路径
- Code Review 检查：新增 `NET_*` 类型名必须在 `HCNetSDK.h` 中存在

### 6. 与 `HikvisionService.NET_DVR` 的关系

**决策**：本次仅确保 LPR 路径使用正确结构体；登录相关结构体（`NET_DVR_USER_LOGIN_INFO` 等）若与 `HikvisionService` 重复且布局一致可暂保留，若不一致则 LPR 模块以裁剪后的定义为准。

**理由**：最小范围修复；避免牵动预览/JPEG 大面积改动。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 裁剪遗漏依赖类型导致编译失败 | 按 `CHCNetSDK.cs` 依赖链逐步添加；编译 + SizeOf 测试 |
| SDK 小版本差异导致 SizeOf 变化 | 锁定 V6.1.9.48；文件头注明版本 |
| `CHCNetSDK.cs` 使用 `AlarmCSharpDemo` 命名空间习惯 | 迁入时改命名空间，不改布局 |
| 部分设备仅发旧版 `COMM_UPLOAD_PLATE_RESULT` | 同时修复 `HandlePlateResult` |
| 真机环境无法自动化 CI | 手工验收清单写入 `tasks.md` |

## Migration Plan

1. 在 `repos/MaterialClient` 分支实现并本地构建
2. 部署到测试地磅，连接 iDS-TCM204-E，验证单次抓拍单条有效事件
3. 对比 GovClient 同设备车牌字符串
4. 无数据库迁移；无配置变更
5. 回滚：还原 `HikvisionSdk.cs` 与 `HikvisionLprService.cs` 即可

## Open Questions

- （无阻塞项）是否在后续单独 change 中合并 `HikvisionService.NET_DVR` 与 `HikvisionSdk` 全部 P/Invoke — 建议 backlog，不纳入本次。
