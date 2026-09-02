# UrbanManagement 发布到 IIS 站点目录
#
# 服务器 IIS 物理路径: C:\wwwroot\UrbanManagement
# 远程发布 UNC（SMB 共享 wwwroot）: \\191.12.234.212\wwwroot\UrbanManagement
# 认证: 从凭据管理器读取 TERMSRV/191.12.234.212（用户 admin），脚本内不保存密码。
#
# 首次写入凭据（只需一次，密码勿写入仓库）:
#   cmdkey /generic:TERMSRV/191.12.234.212 /user:admin /pass:你的密码
#
# 用法:
#   # 发布前先测 VPN / 目标可达（推荐）
#   powershell -ExecutionPolicy Bypass -File scripts/UrbanManagement/Test-UrbanManagementPublishTarget.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/UrbanManagement/Publish-UrbanManagement.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/UrbanManagement/Publish-UrbanManagement.ps1 -SkipRobocopy
#   powershell -ExecutionPolicy Bypass -File scripts/UrbanManagement/Publish-UrbanManagement.ps1 -OverwriteAppSettings
#   # 在 191.12.234.212 本机直接发布:
#   powershell -ExecutionPolicy Bypass -File scripts/UrbanManagement/Publish-UrbanManagement.ps1 -TargetPath "C:\wwwroot\UrbanManagement" -SkipShareConnect
#
# 流程: 读凭据 -> 映射共享 -> dotnet publish -> robocopy /MIR -> icacls Everyone
# 默认不覆盖目标站点已有的 appsettings*.json；首次部署（目标没有这些文件）仍会复制。
# 加 -OverwriteAppSettings 才会强制同步配置。

[CmdletBinding()]
param(
    [string] $TargetPath = '\\191.12.234.212\wwwroot\UrbanManagement',
    [string] $Configuration = 'Release',
    [string] $StagingPath = '',
    [string] $CredentialTarget = 'TERMSRV/191.12.234.212',
    [string] $ShareUser = 'admin',
    [string] $SharePassword = '',
    [switch] $SelfContained,
    [switch] $SkipRobocopy,
    [switch] $SkipShareConnect,
    [switch] $SkipAcl,
    [switch] $OverwriteAppSettings
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '_publish-common.ps1')

Invoke-IisWebPublish `
    -Csproj (Get-UrbanManagementHostCsproj) `
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
