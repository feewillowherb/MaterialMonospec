# 政府平台 PostWeightAsync 联调日志分析报告

> **依据日志**：`_temp/post-weight-result-20260615-110808.txt`（成功用例）及同目录早期失败用例  
> **分析对象**：`repos/UrbanManagement` 政府同步链路（`IGovSyncHttpClient` / `GovSyncManager`）  
> **分析日期**：2026-06-15

## 1. 日志摘要

### 1.1 成功用例（110808）

| 项 | 值 |
|---|---|
| 接口 | `POST http://191.12.15.58:8899/sapi/v1/inoutRecord/save` |
| HTTP 状态 | 200 |
| 业务响应 | `{ "code": 200, "msg": "操作成功", "data": null }` |
| 关键请求字段 | `snapImages: []`，`carType: "小车"`，`grossWeight: 1000` |

政府平台在 payload 格式正确时可正常入库。

### 1.2 失败用例对照（联调过程）

| 时间 | 现象 | 根因（已确认） |
|---|---|---|
| 11:02:22 | `code: 500`, `msg: "JSON parse error"` | `snapImages` 为字符串 `""`，平台期望 JSON 数组 |
| 11:02:22（同期） | 同上 | `carType: "Large"`，平台期望中文 `"大车"` / `"小车"` |
| 11:06:20 | `code: 200` 但 `msg` 显示乱码 | 测试脚本编码问题，**非业务错误**（已修脚本） |

---

## 2. 当前代码仍存在的错误

以下问题基于**成功日志中的政府平台真实响应格式**与**现有 C# 实现**对比得出。部分 payload 字段问题已在工作区修过，但若未部署仍会复现。

### 2.1 【严重】成功判定字段与政府 API 不一致

**现象**：日志显示政府 API 仅返回 `code` / `msg` / `data`，**没有** `success` 字段。

**代码**（`GovSyncManager.ProcessRecordAsync`）：

```csharp
if (response.Success)  // ← 依赖 GovResponseBase.Success
{
    record.SyncType = 1;
    ...
}
else
{
    record.SyncType = 2;  // 标记失败并重试
    ...
}
```

**模型**（`IGovSyncHttpClient.cs`）：

```csharp
public class GovResponseBase<T>
{
    public bool Success { get; set; }  // 政府响应中不存在此字段
    public string? Msg { get; set; }
    public int Code { get; set; }
    public T? Data { get; set; }
}
```

**后果**：

- Refit 反序列化后 `Success` 恒为 `false`（默认值）
- 即使政府平台返回 `code: 200`、`msg: "操作成功"`，服务端仍会把记录标为 **同步失败**（`SyncType = 2`），并递增 `RetryCount`
- 与日志中「平台已成功」的事实直接矛盾，属于**误判成功为失败**的逻辑缺陷

**建议修复**：

- 以 `Code == 200`（或平台文档约定的成功码）作为成功条件；或
- 为 `Success` 增加 `[JsonPropertyName("success")]` 并确认平台是否真有该字段（当前日志证明没有）；或
- 使用自定义 `JsonConverter` / 包装类型，在反序列化后根据 `Code` 填充 `Success`

**涉及文件**：

- `repos/UrbanManagement/src/UrbanManagement.Core/Api/IGovSyncHttpClient.cs`
- `repos/UrbanManagement/src/UrbanManagement.Core/Services/GovSyncManager.cs`

---

### 2.2 【严重】`snapImages` 类型错误（修复前必现 500）

**现象**：早期 payload 使用 `"snapImages": ""`，政府平台返回 `JSON parse error`。

**原因**：

- 政府平台（Jackson）将 `snapImages` 定义为 **字符串数组**（`string[]` / `List<String>`）
- 空字符串无法反序列化为数组，触发解析异常

**代码问题**（修复前 `BuildGovPayload`）：

```csharp
snapImages = string.Empty,  // 错误：string
```

**正确格式**（110808 日志已验证）：

```json
"snapImages": []
```

有图片时应为 Base64 字符串数组，与 `GovRequestWeightDto.SnapImages`（`string?[]`）及 `LegacyApiController` 的数组解析逻辑一致。

**当前工作区状态**：已改为 `snapImages = snapImages.ToArray()`。若生产环境未包含该提交，仍会 500。

**涉及文件**：

- `repos/UrbanManagement/src/UrbanManagement.Core/Services/GovSyncManager.cs`

---

### 2.3 【严重】`carType` 枚举值与政府平台不匹配（修复前）

**现象**：早期 payload 使用 `"carType": "Large"`，在政府平台侧可能参与校验或入库映射。

**规范与实现冲突**：

| 来源 | `carType` 约定 |
|---|---|
| `openspec/specs/gov-sync-worker/spec.md` | `"大车"` / `"小车"`（按 `TotalWeight > 4500`） |
| `openspec/specs/urban-weighing-api/spec.md` | `"Large"` / `"Small"` |
| 政府平台（联调日志） | `"小车"` 可成功（`grossWeight: 1000`） |
| 修复前 `BuildGovPayload` | `"Large"` / `"Small"` |

**结论**：

- 政府平台接受中文车型；英文 `Large`/`Small` 与平台/旧版客户端（`mGovRequestWeight`）不一致
- `urban-weighing-api` spec 与政府平台契约**漂移**，易误导后续实现

**当前工作区状态**：已改为 `record.TotalWeight > 4500 ? "大车" : "小车"`。

**涉及文件**：

- `repos/UrbanManagement/src/UrbanManagement.Core/Services/GovSyncManager.cs`
- `openspec/specs/urban-weighing-api/spec.md`（需对齐）

---

### 2.4 【中等】`BuildGovPayload` 曾忽略已读取的附件 Base64

**现象**：`ProcessRecordAsync` 调用 `ReadAttachmentFilesAsync` 获取 `base64Images`，但修复前的 `BuildGovPayload` 未使用该参数，始终发送空字符串。

**后果**：

- 即使本地附件存在，政府平台也收不到图片
- 与 `gov-sync-worker` spec「`snapImages` 从附件加载为 Base64 数组」不符

**当前工作区状态**：已改为 `snapImages.ToArray()`，逻辑与 spec 一致。

---

### 2.5 【中等】Payload 使用匿名对象 + `object` Body，缺少契约约束

**代码**：

```csharp
Task<GovResponseBase<string>> PostWeightAsync([Body] object payload);
// ...
private static object BuildGovPayload(...) => new { ... };
```

**问题**：

- 已有 `GovRequestWeightDto`（`UrbanManagement.App/Models`）定义完整字段与 `[JsonPropertyName]`，但 Refit 出站未复用
- 匿名类型在编译期无契约检查，易出现字段类型漂移（如 `snapImages` 字符串 vs 数组）
- Refit 默认序列化行为与 MVC `JsonOptions`（`WhenWritingNull`）不一致，`carColor: null` 是否出现在 JSON 取决于 Refit 配置，增加联调不确定性

**建议**：出站 payload 统一使用 `GovRequestWeightDto` 或 Core 层专用 record/DTO，并为 Refit 显式配置 `System.Text.Json` 选项。

---

### 2.6 【低】`carType` 仅按重量推导，忽略实体 `VehicleType`

**代码**：

```csharp
carType = record.TotalWeight > 4500 ? "大车" : "小车",
```

**spec 原文**同时提到 `VehicleType→CarType` 与重量阈值规则，实现只保留后者。

**风险**：旧版客户端上报的 `VehicleType`（如 `"大车"`）在 `TotalWeight` 与车型不一致时被覆盖。110808 用例中 `1000` kg → `"小车"` 与阈值一致，未暴露此问题。

---

### 2.7 【低】`equipmentNumber` / `equipmentType` / `inOutType` 硬编码

`BuildGovPayload` 固定：

- `inOutType = 0`
- `equipmentNumber = ""`
- `equipmentType = ""`

旧版 `LegacyGovSyncAppService` 会从客户端请求透传这些字段；经 Urban 链路入库后再同步时，政府平台收到的始终是默认值，可能与原始 `sourceData` 不一致。

---

## 3. 问题与代码映射总表

| 优先级 | 问题 | 日志/证据 | 代码位置 | 工作区修复状态 |
|---|---|---|---|---|
| P0 | 用 `response.Success` 判断成功，与政府 `code` 不一致 | 响应仅有 `code:200`，无 `success` | `GovSyncManager.cs:70` | **未修复** |
| P0 | `snapImages` 传字符串导致 JSON parse error | 早期 500 日志 | `GovSyncManager.BuildGovPayload` | **已修复** |
| P0 | `carType` 英文值不符合政府平台 | 早期 500 / 规范 | `GovSyncManager.BuildGovPayload` | **已修复** |
| P1 | 附件 Base64 未写入 payload | 代码审查 | `GovSyncManager.BuildGovPayload` | **已修复** |
| P1 | 出站 DTO 无类型约束 | 架构 | `IGovSyncHttpClient` + `BuildGovPayload` | **未修复** |
| P2 | 忽略 `VehicleType` | 规范 | `BuildGovPayload` | **未修复** |
| P2 | 设备字段硬编码 | 规范对比 | `BuildGovPayload` | **未修复** |
| P2 | OpenSpec `urban-weighing-api` 与 `gov-sync-worker` 车型约定冲突 | 文档 | `openspec/specs/*.md` | **未修复** |

---

## 4. 正确 Payload 契约（联调确认）

以 `_temp/post-weight-result-20260615-110808.txt` 为准，政府平台可接受的请求体示例：

```json
{
  "carNo": "浙A12345",
  "carColor": null,
  "carNoColor": "蓝",
  "buildLicenseNo": "XNXS20260611001",
  "inOutType": 0,
  "equipmentNumber": "",
  "equipmentType": "",
  "grossWeight": 1000,
  "tareWeight": 0,
  "snapTime": "2026-06-11 19:55:57",
  "snapImages": [],
  "carType": "小车",
  "deviceID": "01",
  "siteType": "1",
  "goodsWeight": "1000"
}
```

**政府响应契约**：

```json
{
  "code": 200,
  "msg": "操作成功",
  "data": null
}
```

注意：业务成功应读 **`code`**，不能读不存在的 **`success`**。

---

## 5. 建议修复顺序

1. **立即**：修改 `GovSyncManager` 成功判定为 `response.Code == 200`（或平台统一成功码），并补充单元测试覆盖「仅有 code/msg/data 的响应」。
2. **部署**：确保 `BuildGovPayload` 的 `snapImages` 数组与 `carType` 中文值已发布到生产。
3. **短期**：Refit 出站改用强类型 DTO；为 `IGovSyncHttpClient` 配置与联调一致的 JSON 序列化选项。
4. **文档**：将 `openspec/specs/urban-weighing-api/spec.md` 中 `carType: Large/Small` 改为与政府平台一致的 `"大车"`/`"小车"`，或明确「仅内部使用、出站时映射」。

---

## 6. 关联文件

| 文件 | 说明 |
|---|---|
| `_temp/post-weight-result-20260615-110808.txt` | 成功联调日志 |
| `_temp/post-weight-payload.json` | 联调请求体模板 |
| `repos/UrbanManagement/src/UrbanManagement.Core/Services/GovSyncManager.cs` | 载荷组装与成功判定 |
| `repos/UrbanManagement/src/UrbanManagement.Core/Api/IGovSyncHttpClient.cs` | Refit 客户端与响应模型 |
| `repos/UrbanManagement/src/UrbanManagement.App/Models/GovRequestWeightDto.cs` | 旧版客户端/契约 DTO |
| `openspec/specs/gov-sync-worker/spec.md` | 政府同步规范 |
| `openspec/specs/urban-weighing-api/spec.md` | 车型阈值规范（存在漂移） |
