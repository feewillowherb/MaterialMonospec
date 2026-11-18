# FdSoft.BasePlatform.PublicApi 发布到 IIS 站点目录（135）
#
# 默认目标: \\DESKTOP-P2S0F3O\WebSites\base.api.findong.com
# 服务器本机路径: E:\TestServer\WebSites\base.api.findong.com（135）
# 认证: 从凭据管理器读取 TERMSRV/192.168.3.135（用户 yiye），脚本内不保存密码。
#
# 首次写入凭据（只需一次）:
#   cmdkey /generic:TERMSRV/192.168.3.135 /user:yiye /pass:你的密码
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File scripts/FdSoft.BasePlatform.PublicApi/Publish-PublicApi.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/FdSoft.BasePlatform.PublicApi/Publish-PublicApi.ps1 -SkipRobocopy
#   powershell -ExecutionPolicy Bypass -File scripts/FdSoft.BasePlatform.PublicApi/Publish-PublicApi.ps1 -OverwriteAppSettings
#   # 在 135 本机直接发到磁盘路径时可:
#   powershell -ExecutionPolicy Bypass -File scripts/FdSoft.BasePlatform.PublicApi/Publish-PublicApi.ps1 `
#     -TargetPath "E:\TestServer\WebSites\base.api.findong.com" -SkipShareConnect
#
# 流程: 读凭据 -> 映射共享 -> dotnet publish -> robocopy /MIR -> icacls Everyone
# 默认不覆盖目标站点已有的 appsettings*.json；首次部署（目标没有这些文件）仍会复制。
# 加 -OverwriteAppSettings 才会强制同步配置。
#
# 前置: repos/FdSoft.BasePlatform.PublicApi、repos/FdSoft.BasePlatform、
#       repos/FdSoft.Common、repos/FdSoft.ThirdPlatformAPI 均已挂载。

[CmdletBinding()]
param(
    [string] $TargetPath = '\\DESKTOP-P2S0F3O\WebSites\base.api.findong.com',
    [string] $Configuration = 'Release',
    [string] $StagingPath = '',
    [string] $CredentialTarget = 'TERMSRV/192.168.3.135',
    [string] $ShareUser = 'yiye',
    [string] $SharePassword = '',
    [switch] $SelfContained,
    [switch] $SkipRobocopy,
    [switch] $SkipShareConnect,
    [switch] $SkipAcl,
    [switch] $OverwriteAppSettings
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\UrbanManagement\_publish-common.ps1')

function Get-PublicApiCsproj {
    $csproj = Join-Path (Get-MonospecRoot) 'repos\FdSoft.BasePlatform.PublicApi\FdSoft.BasePlatform.PublicApi.csproj'
    if (-not (Test-Path -LiteralPath $csproj)) {
        throw "找不到 PublicApi 项目: $csproj（检查 .hagicode/monospecs.yaml 的 path / Junction）"
    }
    return (Resolve-Path -LiteralPath $csproj).Path
}

if ([string]::IsNullOrWhiteSpace($StagingPath)) {
    $StagingPath = Join-Path (Get-MonospecRoot) '_tmp\publish\FdSoft.BasePlatform.PublicApi'
}

Write-Host 'ServerPath  : E:\TestServer\WebSites\base.api.findong.com'
Write-Host ''

Invoke-IisWebPublish `
    -Csproj (Get-PublicApiCsproj) `
    -TargetPath $TargetPath `
    -Configuration $Configuration `
    -StagingPath $StagingPath `
    -CredentialTarget $CredentialTarget `
    -ShareUser $ShareUser `
    -SharePassword $SharePassword `
    -SelfContained:$SelfContained `
    -SkipRobocopy:$SkipRobocopy `
    -SkipShareConnect:$SkipShareConnect `
    -SkipAcl:$SkipAcl `
    -OverwriteAppSettings:$OverwriteAppSettings

Write-Host '（135 本机: E:\TestServer\WebSites\base.api.findong.com）'
