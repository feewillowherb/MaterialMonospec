# 发布前可达性检测（需先连 VPN）
#
# 检查: ping(可选) -> SMB 445 -> 凭据 -> UNC 映射 -> IIS 目录 -> 写权限探针
# 默认目标与 Publish-UrbanManagement.ps1 一致。
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File scripts/UrbanManagement/Test-UrbanManagementPublishTarget.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/UrbanManagement/Test-UrbanManagementPublishTarget.ps1 -SkipShareConnect
#
# 退出码: 0=可发布, 1=不可达或未通过必需检查

[CmdletBinding()]
param(
    [string] $TargetPath = '\\191.12.234.212\wwwroot\UrbanManagement',
    [string] $CredentialTarget = 'TERMSRV/191.12.234.212',
    [string] $ShareUser = 'admin',
    [string] $SharePassword = '',
    [switch] $SkipShareConnect
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '_publish-common.ps1')

$result = Test-UrbanManagementPublishReachability `
    -TargetPath $TargetPath `
    -CredentialTarget $CredentialTarget `
    -ShareUser $ShareUser `
    -SharePassword $SharePassword `
    -SkipShareConnect:$SkipShareConnect

if (-not $result.Ok) {
    exit 1
}

exit 0
