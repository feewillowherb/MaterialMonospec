# MaterialClient.Recycle 称重 / 车牌 FEV（API，无人值守）

知识状态：协议 CONFIRMED（2026-11-17 Human）。

| Run | 验证什么 | Verdict |
|-----|----------|---------|
| `…/2026-11-17T152007` | 诊断 API 可注入（非磅单） | FEASIBLE（仅注入） |
| `…/2026-11-17T152142` | 离磅→车牌→稳重后 **WeighingRecords** 落库 | FEASIBLE（已有 Id=1/2；`Waybills=0`，完成运单另需 Complete） |

**说明**：单次 `weight`/`test-plate` 不等于磅单。形成 `WeighingRecords` 需：`weight≈0` → `test-plate` → 稳定吨位并保持判稳窗口。完整运单（`Waybills`）还要走完成，不是诊断注入自动生成。

## 可行性问题

> 采集化改造后，已启动的 `MaterialClient.Recycle` 能否在**无 UI 操作**的前提下，经诊断 API 驱动地磅/车牌，使本地产生 `WeighingRecords`（磅单行）？

分层：① 注入 API 可达；② 判稳后落 `WeighingRecords`；③ `Complete` 后落 `Waybills` / 第一跳上传——本 FEV 默认验到 ②。

## 已确认约定

| 项 | 约定 |
|----|------|
| UI | **不需要**点击称重窗；FEV **不**做人机 UI 脚本 |
| 启动 | 脚本/宿主启动 Recycle 即可 |
| 激活 | **仅首次**需用户输入激活码；之后视为无人值守 |
| 地磅 / 车牌 | 用诊断 API 控制，不操作 UI |
| 非路径 | 单元测试 / Mvc.Testing；不依赖市平台；不依赖 XiaoShanResource 接收（本单可另验） |

## 诊断 API（MinimalWebHost）

默认：`MinimalWebHost:Urls` = `http://localhost:9933`（`EnableOnStartup: true`）。

| 方法 | 路径 | 作用 |
|------|------|------|
| GET | `/` | 健康与端点列表 |
| POST | `/api/scale/weight` | 注入测试重量（吨）；**要求**设置里 `ScaleType = TestMode` |
| POST | `/api/lpr/test-plate` | 注入 `LicensePlateRecognizedEventData` |

请求示例：

```json
// POST /api/scale/weight
{ "weight": 32.5 }

// POST /api/lpr/test-plate
{ "plateNumber": "浙DE5145", "deviceName": "FevApi" }
```

实现：`repos/MaterialClient/src/MaterialClient.Recycle/Services/MinimalWebHostService.cs`。

## 实验步骤

1. 用户确保本机已完成首次激活（若未激活则只做这一步人工输入）。
2. `Start-MaterialClient.Recycle.ps1`（或已运行实例）；确认 `GET http://127.0.0.1:9933/` 返回 200。
3. 确认地磅为测试模式，否则 weight API 返回「当前不是地磅测试模式」。
4. 依次：`POST /api/scale/weight` → `POST /api/lpr/test-plate`；记录 HTTP 状态与 body。
5. 证据写入 `evidence/fev-recycle-desktop-capture/<RunId>/`（`summary.json` + `api-run.log`）。

## Verdict

| Verdict | 条件 |
|---------|------|
| `FEASIBLE` | `/`、weight、test-plate 均成功（或 weight 因非 TestMode 的失败已单独记为配置前置，且 plate 成功 + 日志有注入） |
| `INFEASIBLE` | 诊断口不可达且非激活门挡；或 API 恒 500 |
| `INCONCLUSIVE` | 卡在未激活 / 端口未起 / 非 TestMode 未改配置 |

`FEASIBLE` ≠ 产品交付（ICD）；≠ 第一跳上传已通。
