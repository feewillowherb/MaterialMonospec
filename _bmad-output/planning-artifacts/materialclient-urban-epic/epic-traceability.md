# Epic 追溯：materialclient-urban-epic

| PRD 需求 | 架构决策 | OpenSpec Slice | 主要子仓库 |
|----------|----------|----------------|------------|
| FR-1 Urban 桌面端 + 单界面 UI | ADR-1, ADR-2, ADR-7 | `01-materialclient-urban-desktop` | MaterialClient |
| FR-2 静态授权（无 UI） | ADR-4 | `01-materialclient-urban-desktop` | MaterialClient |
| FR-3 ProductCode/Mode | ADR-3 | `01-materialclient-urban-desktop` | MaterialClient |
| FR-3 仅 WeighingRecord、无 waybill | ADR-5 | `02-urban-weighing-record-pipeline` | MaterialClient |
| FR-4 上传 | ADR-6 | `03-urban-weighing-upload-api` | MaterialClient + UrbanManagement |
| FR-5 服务端 + 设备/日志 | ADR-6 | `03` / `04-urban-device-telemetry` | UrbanManagement + MaterialClient |

## 建议实施顺序

```
01-materialclient-urban-desktop
        ↓
02-urban-weighing-record-pipeline
        ↓
03-urban-weighing-upload-api
        ↓
04-urban-device-telemetry
```

## 建议 OpenSpec change-id

| Slice 目录 | `openspec create` 名称 |
|------------|------------------------|
| `01-materialclient-urban-desktop` | `add-materialclient-urban-desktop` |
| `02-urban-weighing-record-pipeline` | `add-urban-weighing-record-pipeline` |
| `03-urban-weighing-upload-api` | `add-urban-weighing-upload-api` |
| `04-urban-device-telemetry` | `add-urban-device-telemetry` |

> 若已创建 `add-materialclient-urban-host`，可重命名 change 或沿用目录仅更新 proposal 语义为「桌面端」。
