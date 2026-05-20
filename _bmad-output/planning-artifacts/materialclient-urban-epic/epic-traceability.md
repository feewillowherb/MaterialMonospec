# Epic 追溯：materialclient-urban-epic

| PRD 需求 | 架构决策 | OpenSpec Slice | 主要子仓库 |
|----------|----------|----------------|------------|
| FR-1 新增 Urban 宿主 | ADR-1 | `01-materialclient-urban-host` | MaterialClient |
| FR-2 静态授权占位 | ADR-3 | `01-materialclient-urban-host` | MaterialClient |
| FR-3 ProductCode/Mode | ADR-2 | `01-materialclient-urban-host` | MaterialClient |
| FR-3 仅 WeighingRecord、无 waybill | ADR-4 | `02-urban-weighing-record-pipeline` | MaterialClient |
| FR-4 上传客户端 | ADR-6 | `03-urban-weighing-upload-api` | MaterialClient + UrbanManagement |
| FR-5 服务端接收记录 | ADR-5 | `03-urban-weighing-upload-api` | UrbanManagement |
| FR-5 设备/软件状态、错误日志 | ADR-5 | `04-urban-device-telemetry` | MaterialClient + UrbanManagement |

## 建议实施顺序

```
01-materialclient-urban-host
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
| `01-materialclient-urban-host` | `add-materialclient-urban-host` |
| `02-urban-weighing-record-pipeline` | `add-urban-weighing-record-pipeline` |
| `03-urban-weighing-upload-api` | `add-urban-weighing-upload-api` |
| `04-urban-device-telemetry` | `add-urban-device-telemetry` |
