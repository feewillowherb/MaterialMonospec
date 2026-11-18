# scripts/FdSoft.BasePlatform.PublicApi

`FdSoft.BasePlatform.PublicApi` 发布到 **135** IIS 目录的入口。共享 robocopy / UNC 逻辑复用 [`../UrbanManagement/_publish-common.ps1`](../UrbanManagement/_publish-common.ps1)。模式对齐 CloudPlaftfromMonospec 的 `Publish-*-PublicApi.ps1`。

约定权威仍以仓库根 [`scripts/AGENTS.md`](../AGENTS.md) 为准。本文件只索引本目录脚本。

## 脚本

| 脚本 | 作用 | 默认目标（135） |
|------|------|-----------------|
| `Publish-PublicApi.ps1` | 凭据 → `dotnet publish` → `robocopy /MIR` | `\\DESKTOP-P2S0F3O\WebSites\base.api.findong.com` |

135 本机路径：`E:\TestServer\WebSites\base.api.findong.com`  
凭据：`TERMSRV/192.168.3.135` / 用户 `yiye`（`cmdkey`，不写进仓库）

```powershell
powershell -ExecutionPolicy Bypass -File scripts/FdSoft.BasePlatform.PublicApi/Publish-PublicApi.ps1
powershell -ExecutionPolicy Bypass -File scripts/FdSoft.BasePlatform.PublicApi/Publish-PublicApi.ps1 -OverwriteAppSettings
# 在 135 本机磁盘路径:
powershell -ExecutionPolicy Bypass -File scripts/FdSoft.BasePlatform.PublicApi/Publish-PublicApi.ps1 `
  -TargetPath "E:\TestServer\WebSites\base.api.findong.com" -SkipShareConnect
```

## MUST / MUST NOT

- **MUST** 默认发到 135 UNC（`DESKTOP-P2S0F3O\WebSites\...`），**MUST NOT** 把本机盘符当默认目标。
- **MUST** 发布 `repos/FdSoft.BasePlatform.PublicApi`（产出 PublicApi），**MUST NOT** 与 `FdSoft.BasePlatform` 主站混淆。
- **MUST** 默认保留目标已有 `appsettings*.json`；仅在明确需要时加 `-OverwriteAppSettings`。
- 前置 junction：`FdSoft.Common`、`FdSoft.ThirdPlatformAPI`、`FdSoft.BasePlatform`。
- 目录说明入口是本 `AGENTS.md`；**MUST NOT** 用 `README.md`。
