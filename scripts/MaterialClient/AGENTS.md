# scripts/MaterialClient

MaterialClient 各**独立宿主**的构建 / 启动入口。共享逻辑在 `_common.ps1`。输出一律落在 `repos/MaterialClient/.build-verify/<leaf>/`。

约定权威仍以仓库根 [`scripts/AGENTS.md`](../AGENTS.md) 与 `repos/MaterialClient/AGENTS.md` 为准。本文件只索引本目录脚本。

## 宿主对照

| 宿主 | Build | Start | 输出目录 | 诊断口默认 |
|------|-------|-------|----------|------------|
| **Standard** | `Build-MaterialClient.Standard.ps1` | `Start-MaterialClient.Standard.ps1` | `.build-verify/MaterialClient` | `http://localhost:9960` |
| **SolidWaste** | `Build-MaterialClient.SolidWaste.ps1` | `Start-MaterialClient.SolidWaste.ps1` | `.build-verify/MaterialClient.SolidWaste` | `http://localhost:9961` |
| Urban | `Build-MaterialClient.Urban.ps1` | `Start-MaterialClient.Urban.ps1` | `.build-verify/Urban` | `http://localhost:9933` |
| Recycle | `Build-MaterialClient.Recycle.ps1` | `Start-MaterialClient.Recycle.ps1` | `.build-verify/Recycle` | （按该脚本） |

兼容：无后缀的 `Build-MaterialClient.ps1` / `Start-MaterialClient.ps1` **只**转发到 `.Standard`；新用法请写带后缀名。

Standard 与 SolidWaste **不得**混用对方身份的 `MaterialClient.db`（隔离 preflight：错产品 / 缺身份会停启）。

## MUST / MUST NOT

- **MUST** 用对应宿主脚本（`.Standard` / `.SolidWaste` / …）；**MUST NOT** 用 Standard 脚本启动固废库，或反之。
- **MUST NOT** 在本目录脚本里改写现场库的产品身份或 `Client:DataDirectory`（由用户 / 安装器处理）。
- 目录说明入口是本 `AGENTS.md`；**MUST NOT** 用 `README.md`。
