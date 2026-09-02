# Shared IIS publish helpers for UrbanManagement scripts under MaterialMonospec.
# Dot-source from sibling Publish-*.ps1 only.

$ErrorActionPreference = 'Stop'

function Get-MonospecRoot {
    $dir = $PSScriptRoot
    while ($dir) {
        if (Test-Path -LiteralPath (Join-Path $dir '.hagicode\monospecs.yaml')) {
            return (Resolve-Path -LiteralPath $dir).Path
        }
        $parent = Split-Path -Parent $dir
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $dir) { break }
        $dir = $parent
    }
    throw '找不到 monospec 根目录（需含 .hagicode/monospecs.yaml）'
}

function Get-UrbanManagementRepoRoot {
    $root = Join-Path (Get-MonospecRoot) 'repos\UrbanManagement'
    if (-not (Test-Path -LiteralPath $root)) {
        throw "UrbanManagement repo not found: $root"
    }
    return (Resolve-Path -LiteralPath $root).Path
}

function Get-UrbanManagementHostCsproj {
    $csproj = Join-Path (Get-UrbanManagementRepoRoot) 'src\UrbanManagement.App\UrbanManagement.App.csproj'
    if (-not (Test-Path -LiteralPath $csproj)) {
        throw "找不到 UrbanManagement 宿主项目: $csproj（检查 .hagicode/monospecs.yaml 的 path / Junction）"
    }
    return (Resolve-Path -LiteralPath $csproj).Path
}

function Convert-ToUncPath {
    param([string] $Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $normalized = $Path.Trim().TrimEnd('\', '/')

    if ($normalized -match '^file://([^/]+)/(.+)$') {
        $hostName = $Matches[1]
        $sharePath = $Matches[2] -replace '/', '\'
        return "\\$hostName\$sharePath"
    }

    if ($normalized -match '^//([^/]+)/(.+)$') {
        $hostName = $Matches[1]
        $sharePath = $Matches[2] -replace '/', '\'
        return "\\$hostName\$sharePath"
    }

    return $normalized
}

function Test-RobocopySuccess {
    param([int] $ExitCode)
    return ($ExitCode -ge 0 -and $ExitCode -le 7)
}

function Get-UncShareRoot {
    param([string] $Path)

    if ($Path -match '^\\\\([^\\]+)\\([^\\]+)') {
        return "\\$($Matches[1])\$($Matches[2])"
    }

    return $null
}

function Get-UncHostName {
    param([string] $Path)

    if ($Path -match '^\\\\([^\\]+)\\') {
        return $Matches[1]
    }

    return $null
}

function Test-UncAccessible {
    param([string] $Path)

    try {
        return [bool](Test-Path -LiteralPath $Path -ErrorAction Stop)
    }
    catch {
        return $false
    }
}

function Initialize-Win32Api {
    if ('Win32.NativeNet' -as [type]) {
        return
    }

    Add-Type -Namespace Win32 -Name NativeNet -MemberDefinition @"
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct CREDENTIAL
{
    public int Flags;
    public int Type;
    public System.IntPtr TargetName;
    public System.IntPtr Comment;
    public long LastWritten;
    public int CredentialBlobSize;
    public System.IntPtr CredentialBlob;
    public int Persist;
    public int AttributeCount;
    public System.IntPtr Attributes;
    public System.IntPtr TargetAlias;
    public System.IntPtr UserName;
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct NETRESOURCE
{
    public int dwScope;
    public int dwType;
    public int dwDisplayType;
    public int dwUsage;
    public string lpLocalName;
    public string lpRemoteName;
    public string lpComment;
    public string lpProvider;
}

[DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool CredRead(string target, int type, int reservedFlag, out System.IntPtr credentialPtr);

[DllImport("advapi32.dll", SetLastError = true)]
public static extern void CredFree(System.IntPtr cred);

[DllImport("mpr.dll", CharSet = CharSet.Unicode)]
public static extern int WNetAddConnection2(ref NETRESOURCE netResource, string password, string username, int flags);

[DllImport("mpr.dll", CharSet = CharSet.Unicode)]
public static extern int WNetCancelConnection2(string name, int flags, bool force);
"@
}

function Read-RdpCredential {
    param([string] $Target)

    Initialize-Win32Api

    foreach ($type in @(1, 2)) {
        $ptr = [IntPtr]::Zero
        if (-not [Win32.NativeNet]::CredRead($Target, $type, 0, [ref]$ptr)) {
            continue
        }

        try {
            $cred = [Runtime.InteropServices.Marshal]::PtrToStructure($ptr, [type][Win32.NativeNet+CREDENTIAL])
            $user = [Runtime.InteropServices.Marshal]::PtrToStringUni($cred.UserName)
            $password = ''
            if ($cred.CredentialBlob -ne [IntPtr]::Zero -and $cred.CredentialBlobSize -gt 0) {
                $password = [Runtime.InteropServices.Marshal]::PtrToStringUni(
                    $cred.CredentialBlob,
                    [int]($cred.CredentialBlobSize / 2)
                )
                if ([string]::IsNullOrEmpty($password)) {
                    $password = [Runtime.InteropServices.Marshal]::PtrToStringAnsi(
                        $cred.CredentialBlob,
                        $cred.CredentialBlobSize
                    )
                }
                $password = $password.TrimEnd([char]0)
            }

            if (-not [string]::IsNullOrWhiteSpace($user) -and -not [string]::IsNullOrWhiteSpace($password)) {
                return @{ UserName = $user; Password = $password }
            }
        }
        finally {
            [Win32.NativeNet]::CredFree($ptr)
        }
    }

    throw @"
凭据管理器中没有可读取密码的条目: $Target
RDP 域密码无法被程序取出。请写入一条 generic 凭据（只需一次）:
  cmdkey /generic:$Target /user:admin /pass:你的密码
"@
}

function Connect-UncWithPassword {
    param(
        [string] $ShareRoot,
        [string] $User,
        [string] $Password
    )

    Initialize-Win32Api
    [void][Win32.NativeNet]::WNetCancelConnection2($ShareRoot, 0, $true)

    $nr = New-Object Win32.NativeNet+NETRESOURCE
    $nr.dwType = 1
    $nr.lpRemoteName = $ShareRoot

    Write-Host "WNetAddConnection2 $ShareRoot /user:$User"
    return [Win32.NativeNet]::WNetAddConnection2([ref]$nr, $Password, $User, 0)
}

function Get-ShareUserCandidates {
    param(
        [string] $User,
        [string] $HostName
    )

    $leaf = ($User -split '\\')[-1]
    $list = @()
    foreach ($name in @($User, $leaf, "$HostName\$leaf")) {
        if (-not [string]::IsNullOrWhiteSpace($name) -and $list -notcontains $name) {
            $list += $name
        }
    }
    return $list
}

function Connect-UncShare {
    param(
        [string] $UncPath,
        [string] $CredentialTargetName,
        [string] $User,
        [string] $Password
    )

    $shareRoot = Get-UncShareRoot -Path $UncPath
    if ([string]::IsNullOrWhiteSpace($shareRoot)) {
        return
    }

    if (Test-UncAccessible -Path $UncPath) {
        Write-Host "Share already accessible: $UncPath"
        return
    }

    if ([string]::IsNullOrWhiteSpace($Password)) {
        Write-Host "Reading credential: $CredentialTargetName"
        $stored = Read-RdpCredential -Target $CredentialTargetName
        if ([string]::IsNullOrWhiteSpace($User)) {
            $User = $stored.UserName
        }
        $Password = $stored.Password
        Write-Host "Using stored user: $($stored.UserName)"
    }

    if ([string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($Password)) {
        throw '未提供共享账号或密码。'
    }

    $hostName = Get-UncHostName -Path $UncPath
    $connected = $false
    $lastCode = -1
    foreach ($candidate in (Get-ShareUserCandidates -User $User -HostName $hostName)) {
        $lastCode = Connect-UncWithPassword -ShareRoot $shareRoot -User $candidate -Password $Password
        if ($lastCode -eq 0 -or $lastCode -eq 85) {
            Write-Host "Connected as $candidate"
            $connected = $true
            break
        }
        Write-Host "Connect as $candidate failed, Win32=$lastCode"
    }

    if (-not $connected -or -not (Test-UncAccessible -Path $UncPath)) {
        throw "无法以 $User 连接 $shareRoot（Win32=$lastCode）。"
    }
}

function Grant-EveryoneAcl {
    param([string] $Path)

    Write-Host "icacls `"$Path`" /grant *S-1-1-0:(OI)(CI)M /T"
    & icacls $Path /grant '*S-1-1-0:(OI)(CI)M' /T
    if ($LASTEXITCODE -ne 0) {
        throw "为 Everyone 授权失败，退出码 $LASTEXITCODE"
    }
}

function Invoke-IisWebPublish {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Csproj,

        [Parameter(Mandatory)]
        [string] $TargetPath,

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

    $target = Convert-ToUncPath -Path $TargetPath

    if ([string]::IsNullOrWhiteSpace($StagingPath)) {
        $StagingPath = Join-Path (Get-MonospecRoot) '_tmp\publish\UrbanManagement'
    }

    $staging = [System.IO.Path]::GetFullPath($StagingPath)
    New-Item -ItemType Directory -Force -Path $staging | Out-Null

    Write-Host "Project      : $Csproj"
    Write-Host "Configuration: $Configuration"
    Write-Host "Staging      : $staging"
    Write-Host "Target       : $target"
    Write-Host "Credential   : $CredentialTarget"
    Write-Host "ShareUser    : $ShareUser"
    Write-Host "AppSettings  : $(if ($OverwriteAppSettings) { 'overwrite' } else { 'preserve if exists' })"
    Write-Host ''

    $publishArgs = @(
        'publish',
        $Csproj,
        '-c', $Configuration,
        '-o', $staging,
        '--no-self-contained'
    )

    if ($SelfContained) {
        $publishArgs = @(
            'publish',
            $Csproj,
            '-c', $Configuration,
            '-o', $staging,
            '--self-contained', 'true',
            '-r', 'win-x64'
        )
    }

    if ($SkipRobocopy) {
        Write-Host 'Skip robocopy (local publish only).'
    }
    elseif (-not $SkipShareConnect) {
        Connect-UncShare -UncPath $target -CredentialTargetName $CredentialTarget -User $ShareUser -Password $SharePassword
        Write-Host ''
    }

    Write-Host "dotnet $($publishArgs -join ' ')"
    & dotnet @publishArgs
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet publish 失败，退出码 $LASTEXITCODE"
    }

    if ($SkipRobocopy) {
        Write-Host ''
        Write-Host "已跳过 robocopy。产物目录: $staging"
        return
    }

    if (-not (Test-UncAccessible -Path $target)) {
        Write-Host "目标目录不存在，尝试创建: $target"
        New-Item -ItemType Directory -Force -Path $target | Out-Null
    }

    Write-Host ''
    $roboArgs = @($staging, $target, '/MIR', '/MT:8', '/R:2', '/W:3')
    $preserveAppSettings = $false
    if (-not $OverwriteAppSettings -and (Test-UncAccessible -Path $target)) {
        $existingAppSettings = @(Get-ChildItem -LiteralPath $target -Filter 'appsettings*.json' -File -ErrorAction SilentlyContinue)
        if ($existingAppSettings.Count -gt 0) {
            $preserveAppSettings = $true
            $roboArgs += @('/XF', 'appsettings*.json')
        }
    }

    if ($preserveAppSettings) {
        Write-Host 'robocopy (preserve dest appsettings*.json)'
    }
    else {
        Write-Host 'robocopy (include appsettings*.json)'
    }
    Write-Host "robocopy $($roboArgs -join ' ')"
    & robocopy @roboArgs
    $robocopyExit = $LASTEXITCODE

    if (-not (Test-RobocopySuccess -ExitCode $robocopyExit)) {
        throw "robocopy 失败，退出码 $robocopyExit"
    }

    if (-not $SkipAcl) {
        Write-Host ''
        Grant-EveryoneAcl -Path $target
    }

    Write-Host ''
    Write-Host '发布完成。'
    Write-Host "站点目录: $target"
}

function Resolve-UrbanManagementPublishTargetHost {
    param([string] $TargetPath)

    $target = Convert-ToUncPath -Path $TargetPath
    $hostName = Get-UncHostName -Path $target
    if (-not [string]::IsNullOrWhiteSpace($hostName)) {
        return @{
            TargetPath = $target
            HostName = $hostName
            ShareRoot = Get-UncShareRoot -Path $target
            IsUnc = $true
        }
    }

    return @{
        TargetPath = $target
        HostName = $null
        ShareRoot = $null
        IsUnc = $false
    }
}

function Test-UrbanManagementPublishReachability {
    [CmdletBinding()]
    param(
        [string] $TargetPath = '\\191.12.234.212\wwwroot\UrbanManagement',

        [string] $CredentialTarget = 'TERMSRV/191.12.234.212',

        [string] $ShareUser = 'admin',

        [string] $SharePassword = '',

        [switch] $SkipShareConnect,

        [int] $PingTimeoutSec = 2,

        [int] $TcpTimeoutMs = 3000
    )

    $resolved = Resolve-UrbanManagementPublishTargetHost -TargetPath $TargetPath
    $target = $resolved.TargetPath
    $checks = New-Object System.Collections.Generic.List[object]

    function Add-Check {
        param(
            [string] $Id,
            [string] $Label,
            [bool] $Ok,
            [string] $Detail,
            [switch] $Required
        )
        $checks.Add([ordered]@{
            Id = $Id
            Label = $Label
            Ok = $Ok
            Required = [bool]$Required
            Detail = $Detail
        }) | Out-Null
    }

    Write-Host 'UrbanManagement publish target reachability'
    Write-Host "TargetPath : $target"
    if ($resolved.IsUnc) {
        Write-Host "Host       : $($resolved.HostName)"
        Write-Host "ShareRoot  : $($resolved.ShareRoot)"
    }
    Write-Host "Credential : $CredentialTarget"
    Write-Host "ShareUser  : $ShareUser"
    Write-Host ''

    if (-not $resolved.IsUnc) {
        $localOk = Test-Path -LiteralPath $target
        Add-Check -Id 'local-path' -Label 'Local IIS path' -Ok $localOk -Required `
            -Detail $(if ($localOk) { 'Path exists' } else { "Missing: $target" })
    }
    else {
        $pingOk = $false
        $pingDetail = 'No reply (ICMP may be blocked; not fatal if SMB works)'
        try {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $pingOk = [bool](Test-Connection -ComputerName $resolved.HostName -Count 1 -Quiet -TimeoutSeconds $PingTimeoutSec -ErrorAction Stop)
            }
            else {
                $pingOk = [bool](Test-Connection -ComputerName $resolved.HostName -Count 1 -Quiet -ErrorAction Stop)
            }
            if ($pingOk) {
                $pingDetail = 'Host replied to ping'
            }
        }
        catch {
            $pingDetail = "Ping failed: $($_.Exception.Message)"
        }
        Add-Check -Id 'ping' -Label 'Host ping' -Ok $pingOk -Detail $pingDetail

        $smbOk = $false
        $smbDetail = 'Port 445 closed or filtered — check VPN'
        try {
            $tcp = Test-NetConnection -ComputerName $resolved.HostName -Port 445 -WarningAction SilentlyContinue -ErrorAction Stop
            $smbOk = [bool]$tcp.TcpTestSucceeded
            if ($smbOk) {
                $smbDetail = 'SMB port 445 reachable'
            }
        }
        catch {
            $smbDetail = "TCP 445 probe failed: $($_.Exception.Message)"
        }
        Add-Check -Id 'smb445' -Label 'SMB (TCP 445)' -Ok $smbOk -Required -Detail $smbDetail

        $credOk = $false
        $credDetail = 'Credential readable from Windows Credential Manager'
        if (-not [string]::IsNullOrWhiteSpace($SharePassword)) {
            $credOk = $true
            $credDetail = 'Password supplied via -SharePassword parameter'
        }
        else {
            try {
                $stored = Read-RdpCredential -Target $CredentialTarget
                $credOk = $true
                $credDetail = "Stored credential user: $($stored.UserName)"
            }
            catch {
                $credDetail = $_.Exception.Message
            }
        }
        Add-Check -Id 'credential' -Label 'Credential' -Ok $credOk -Required -Detail $credDetail

        $shareOk = $false
        $shareDetail = 'Share not checked'
        if ($SkipShareConnect) {
            $shareDetail = 'Skipped (-SkipShareConnect)'
            Add-Check -Id 'share-connect' -Label 'UNC connect' -Ok $true -Detail $shareDetail
        }
        elseif (-not $smbOk) {
            $shareDetail = 'Skipped because SMB 445 is not reachable'
            Add-Check -Id 'share-connect' -Label 'UNC connect' -Ok $false -Required -Detail $shareDetail
        }
        else {
            try {
                Connect-UncShare -UncPath $target -CredentialTargetName $CredentialTarget -User $ShareUser -Password $SharePassword
                $shareOk = $true
                $shareDetail = "Connected to $($resolved.ShareRoot)"
            }
            catch {
                $shareDetail = $_.Exception.Message
            }
            Add-Check -Id 'share-connect' -Label 'UNC connect' -Ok $shareOk -Required -Detail $shareDetail
        }

        $pathOk = $false
        $pathDetail = 'Target folder not checked'
        if ($shareOk -or (Test-UncAccessible -Path $target)) {
            $pathOk = Test-UncAccessible -Path $target
            if ($pathOk) {
                $pathDetail = 'IIS folder exists'
            }
            else {
                $pathDetail = "IIS folder missing: $target"
            }
        }
        else {
            $pathDetail = 'Cannot access target until UNC connect succeeds'
        }
        Add-Check -Id 'iis-path' -Label 'IIS folder' -Ok $pathOk -Required -Detail $pathDetail

        $writeOk = $false
        $writeDetail = 'Write probe not run'
        if ($pathOk) {
            $probeName = ".publish-reachability-$([guid]::NewGuid().ToString('N')).tmp"
            $probePath = Join-Path $target $probeName
            try {
                Set-Content -LiteralPath $probePath -Value 'ok' -Encoding Ascii -ErrorAction Stop
                Remove-Item -LiteralPath $probePath -Force -ErrorAction Stop
                $writeOk = $true
                $writeDetail = 'Write/delete probe succeeded'
            }
            catch {
                $writeDetail = "Write probe failed: $($_.Exception.Message)"
            }
        }
        else {
            $writeDetail = 'Skipped because IIS folder is not accessible'
        }
        Add-Check -Id 'write-probe' -Label 'Write permission' -Ok $writeOk -Required -Detail $writeDetail
    }

    foreach ($check in $checks) {
        $mark = if ($check.Ok) { '[OK]' } else { if ($check.Required) { '[FAIL]' } else { '[WARN]' } }
        Write-Host "$mark $($check.Label): $($check.Detail)"
    }

    $requiredFailed = @($checks | Where-Object { $_.Required -and -not $_.Ok })
    $ok = ($requiredFailed.Count -eq 0)

    Write-Host ''
    if ($ok) {
        Write-Host 'Reachable: publish preflight passed.'
    }
    else {
        Write-Host 'Not reachable: connect VPN and verify credential/share before publish.'
        foreach ($fail in $requiredFailed) {
            Write-Host "  - $($fail.Label): $($fail.Detail)"
        }
    }

    return @{
        Ok = $ok
        TargetPath = $target
        HostName = $resolved.HostName
        Checks = $checks
    }
}
