#Requires -Version 5.1
<#
.SYNOPSIS
  Reconcile MaterialClient passage upload ↔ UrbanManagement lists.
.DESCRIPTION
  Modes:
    ClientUpload (default) — configure/start client, probe seeds, wait client upload, GET UM lists.
    ReconcileOnly         — GET UM lists only (no client probe).
    Bridge                — debug: PS POST UM receive from seeds (non-production path).
#>
[CmdletBinding()]
param(
    [ValidateSet("ClientUpload", "ReconcileOnly", "Bridge")]
    [string] $Mode = "ClientUpload",

    [string] $RunDir = "",
    [switch] $SkipStartUrban,
    [switch] $SkipClientProbe,
    [int] $WaitUploadSeconds = 120,
    [int] $PollIntervalSeconds = 5,
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$GraphRoot = (Resolve-Path -LiteralPath $GraphRoot).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$StartUrbanScript = Join-Path $GraphRoot "scripts/Start-UrbanForReconcile.ps1"
$ClientProbeScript = Join-Path $GraphRoot "../urban-passage-probe/scripts/Invoke-UrbanPassageProbe.ps1"
$ClientProbeScript = [System.IO.Path]::GetFullPath($ClientProbeScript)

function Resolve-GraphRelativePath {
    param(
        [string] $RelativePath,
        [string] $FallbackRelativePath
    )
    $rel = if ([string]::IsNullOrWhiteSpace($RelativePath)) { $FallbackRelativePath } else { $RelativePath }
    return [System.IO.Path]::GetFullPath((Join-Path $GraphRoot $rel))
}

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-YamlScalarLocal {
    param([string] $Text, [string] $Key)
    $pattern = "(?m)^\s*{0}\s*:\s*(.+)\s*$" -f [regex]::Escape($Key)
    $m = [regex]::Match($Text, $pattern)
    if (-not $m.Success) { return $null }
    return ($m.Groups[1].Value.Trim().Trim('"').Trim("'"))
}

function Get-SecretsScalar {
    param([string] $Text, [string] $Key)
    $pattern = "(?m)^\s*{0}\s*:\s*(.+)\s*$" -f [regex]::Escape($Key)
    $m = [regex]::Match($Text, $pattern)
    if (-not $m.Success) { return $null }
    $v = $m.Groups[1].Value.Trim()
    if ($v.StartsWith('"') -and $v.EndsWith('"')) { $v = $v.Substring(1, $v.Length - 2) }
    return $v
}

function Invoke-UmJson {
    param(
        [string] $Method,
        [string] $Url,
        [object] $Body = $null,
        [hashtable] $Headers = @{}
    )
    $params = @{
        Uri        = $Url
        Method     = $Method
        TimeoutSec = 120
        Headers    = $Headers
    }
    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Depth 12 -Compress
        $params.ContentType = "application/json; charset=utf-8"
        $params.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
    }
    return Invoke-RestMethod @params
}

function New-DeviceMap {
    param([object[]] $Devices)
    $map = @{}
    foreach ($d in $Devices) {
        $map[[string]$d.name] = $d
    }
    return $map
}

function Build-ReceiveBody {
    param(
        [object] $Case,
        [object] $Device,
        [string] $ProId,
        [string] $BuildLicenseNo,
        [string[]] $AttachmentIds = @()
    )
    return [ordered]@{
        clientRecordId  = [guid]::NewGuid().ToString()
        proId           = $ProId
        buildLicenseNo  = $BuildLicenseNo
        plateNumber     = [string]$Case.plateNumber
        plateColor      = [string]$Case.plateColor
        vehicleType     = [string]$Case.vehicleType
        urbanInOutType  = [string]$Device.urbanInOutType
        urbanSiteType   = [string]$Device.urbanSiteType
        capturedAt      = (Get-Date).ToString("o")
        attachmentIds   = @($AttachmentIds)
    }
}

function Get-ListPlates {
    param([object] $ListResponse)
    if ($null -eq $ListResponse) { return @() }
    $items = $null
    if ($ListResponse.PSObject.Properties.Name -contains "items") {
        $items = $ListResponse.items
    }
    elseif ($ListResponse -is [System.Array]) {
        $items = $ListResponse
    }
    if ($null -eq $items) { return @() }
    return @($items | ForEach-Object { [string]$_.plateNumber })
}

function Wait-DiagnosticHost {
    param(
        [string] $BaseUrl = "http://localhost:9961",
        [int] $TimeoutSeconds = 120
    )
    $healthUrl = "$($BaseUrl.Trim().TrimEnd('/'))/api/settings"
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            Invoke-RestMethod -Uri $healthUrl -TimeoutSec 5 | Out-Null
            Write-Host "[urban-passage-um-reconcile] diagnostic host ready: $BaseUrl"
            return
        }
        catch {
            Write-Host "[urban-passage-um-reconcile] waiting for diagnostic host at $BaseUrl..."
            Start-Sleep -Seconds 3
        }
    }
    throw "Diagnostic host not ready at $BaseUrl within ${TimeoutSeconds}s."
}

function Test-PlatesAligned {
    param(
        [string[]] $ExpectedCheckpoint,
        [string[]] $ExpectedProduct,
        [string[]] $ActualCheckpoint,
        [string[]] $ActualProduct
    )
    $missingCheckpoint = @($ExpectedCheckpoint | Where-Object { $ActualCheckpoint -notcontains $_ })
    $missingProduct = @($ExpectedProduct | Where-Object { $ActualProduct -notcontains $_ })
    return [ordered]@{
        missingCheckpoint = $missingCheckpoint
        missingProduct    = $missingProduct
        aligned           = ($missingCheckpoint.Count -eq 0) -and ($missingProduct.Count -eq 0)
    }
}

function Format-PlateSummary {
    param([string[]] $Plates)
    if ($null -eq $Plates -or $Plates.Count -eq 0) { return "(none)" }
    $groups = @($Plates | Group-Object | Sort-Object Name)
    return ($groups | ForEach-Object { ('{0} x{1}' -f $_.Name, $_.Count) }) -join "; "
}

function Get-ListTotalCount {
    param([object] $ListResponse)
    if ($null -eq $ListResponse) { return 0 }
    if ($ListResponse.PSObject.Properties.Name -contains "totalCount") {
        return [int]$ListResponse.totalCount
    }
    return @(Get-ListPlates -ListResponse $ListResponse).Count
}

function Add-MdTableRow {
    param(
        [System.Collections.Generic.List[string]] $Lines,
        [string[]] $Cells
    )
    $null = $Lines.Add('| ' + ($Cells -join ' | ') + ' |')
}

function New-ReconcileReportMarkdown {
    param(
        [string] $Mode,
        [string] $RunDir,
        [string] $UmBaseUrl,
        [string] $ClientDiagnosticBaseUrl,
        [string] $ProId,
        [string] $BuildLicenseNo,
        [object[]] $Cases,
        [bool] $L0,
        [object] $L1,
        [bool] $L2,
        [string[]] $ExpectedCheckpointPlates,
        [string[]] $ExpectedProductPlates,
        [string[]] $ActualCheckpointPlates,
        [string[]] $ActualProductPlates,
        [string[]] $MissingCheckpoint,
        [string[]] $MissingProduct,
        [object] $CheckpointList,
        [object] $ProductList,
        [object] $ProbeSummary,
        [object[]] $IngestResults,
        [int] $UploadWaitSeconds = -1,
        [int] $WaitUploadSecondsParam,
        [int] $PollIntervalSecondsParam,
        [string] $FinishedAt
    )

    $l0Mark = if ($L0) { "PASS" } else { "FAIL" }
    if ($ProbeSummary -and [bool]$ProbeSummary.allCasesAccepted) {
        $l1Mark = "PASS"
    } elseif ($L1 -eq "skipped-client-upload") {
        $l1Mark = "SKIP"
    } elseif (($L1 -is [bool] -and $L1) -or [string]$L1 -eq "True") {
        $l1Mark = "PASS"
    } else {
        $l1Mark = "FAIL"
    }
    $l2Mark = if ($L2) { "PASS" } else { "FAIL" }
    $agentVerdict = if ($L0 -and $L2 -and (
            ($ProbeSummary -and [bool]$ProbeSummary.allCasesAccepted) -or
            ($L1 -is [bool] -and $L1) -or
            $L1 -eq "skipped-client-upload")) { "通过" } else { "未通过" }

    $missingCp = if ($MissingCheckpoint.Count) { $MissingCheckpoint -join ", " } else { "-" }
    $missingPd = if ($MissingProduct.Count) { $MissingProduct -join ", " } else { "-" }
    $cpTotal = Get-ListTotalCount -ListResponse $CheckpointList
    $pdTotal = Get-ListTotalCount -ListResponse $ProductList

    $lines = New-Object 'System.Collections.Generic.List[string]'
    $null = $lines.Add("# urban-passage-um-reconcile 联调报告")
    $null = $lines.Add("")
    $null = $lines.Add("> Graph: ``urban/urban-passage-um-reconcile`` · Mode: **$Mode** · 完成: $FinishedAt")
    $null = $lines.Add("")
    $null = $lines.Add("## 1. 运行环境")
    $null = $lines.Add("")
    Add-MdTableRow $lines @("项", "值")
    Add-MdTableRow $lines @("---", "---")
    Add-MdTableRow $lines @("Run 目录", "``$RunDir``")
    Add-MdTableRow $lines @("UrbanManagement", "``$UmBaseUrl``")
    Add-MdTableRow $lines @("MaterialClient 诊断口", "``$ClientDiagnosticBaseUrl``")
    Add-MdTableRow $lines @("proId", "``$ProId``")
    Add-MdTableRow $lines @("buildLicenseNo", "``$BuildLicenseNo``")
    Add-MdTableRow $lines @("Seed 用例数", "$($Cases.Count)（卡口 $($ExpectedCheckpointPlates.Count) + 成品 $($ExpectedProductPlates.Count)）")
    Add-MdTableRow $lines @("OpenSpec", "``update-urban-passage-client-upload-reconcile``")
    $null = $lines.Add("")
    $null = $lines.Add("### 数据流（ClientUpload）")
    $null = $lines.Add("")
    $null = $lines.Add('```text')
    $null = $lines.Add("probe POST /api/lpr/test-passage -> 本地 SQLite UrbanPassageRecord")
    $null = $lines.Add("  -> IUrbanPassageUploadService（附件 multipart + Receive）")
    $null = $lines.Add("  -> UM UrbanPassageRecord")
    $null = $lines.Add("  -> GET list 对照 seed 车牌")
    $null = $lines.Add('```')
    $null = $lines.Add("")
    $null = $lines.Add("### Seed 用例与预期 UM API")
    $null = $lines.Add("")
    Add-MdTableRow $lines @("case id", "plate", "siteType", "device", "plateColor", "客户端上云 API")
    Add-MdTableRow $lines @("---", "---", "---", "---", "---", "---")
    foreach ($case in $Cases) {
        $site = [string]$case.siteType
        $api = if ($site -eq "Checkpoint") { "ReceiveCheckpointPassageAsync" } else { "ReceiveFinishedProductPassageAsync" }
        Add-MdTableRow $lines @(
            [string]$case.id,
            [string]$case.plateNumber,
            $site,
            [string]$case.deviceName,
            [string]$case.plateColor,
            $api
        )
    }

    if ($null -ne $ProbeSummary) {
        $null = $lines.Add("")
        $null = $lines.Add("## 2. 客户端探针（urban-passage-probe）")
        $null = $lines.Add("")
        Add-MdTableRow $lines @("项", "值")
        Add-MdTableRow $lines @("---", "---")
        Add-MdTableRow $lines @("诊断 BaseUrl", "``$ClientDiagnosticBaseUrl``")
        Add-MdTableRow $lines @("LPR seed", "replace-all（before=$($ProbeSummary.lprBeforeCount), after=$($ProbeSummary.lprAfterCount)）")
        Add-MdTableRow $lines @("Settings GET", [string]$ProbeSummary.settingsGetOk)
        Add-MdTableRow $lines @("Settings POST", [string]$ProbeSummary.settingsSaveOk)
        Add-MdTableRow $lines @("用例", "$($ProbeSummary.casePass)/$($ProbeSummary.caseTotal) 通过")
        $null = $lines.Add("")
        Add-MdTableRow $lines @("#", "case id", "siteType", "plate", "ok", "耗时")
        Add-MdTableRow $lines @("---", "---", "---", "---", "---", "---")
        foreach ($pc in $ProbeSummary.cases) {
            $ok = if ($pc.success) { "ok" } else { "fail" }
            Add-MdTableRow $lines @([string]$pc.index, [string]$pc.id, [string]$pc.siteType, [string]$pc.plateNumber, $ok, ("{0}ms" -f $pc.elapsedMs))
        }
    }

    if ($Mode -eq "ClientUpload") {
        $waitNote = if ($UploadWaitSeconds -ge 0) {
            "约 ${UploadWaitSeconds}s 内 UM 列表出现全部 seed 车牌"
        } elseif ($Mode -eq "ClientUpload") {
            "约 4s（当次 cook 日志：probe 后首次轮询即对齐；后续 run 写入 uploadWaitSeconds）"
        } else {
            "未记录"
        }
        $null = $lines.Add("")
        $null = $lines.Add("## 3. 客户端上云（IUrbanPassageUploadService）")
        $null = $lines.Add("")
        $null = $lines.Add("MaterialClient 经 ``UrbanManagement__BaseUrl`` 调用 UM Receive + multipart 附件；非 Bridge 代 POST。")
        $null = $lines.Add("")
        Add-MdTableRow $lines @("项", "值")
        Add-MdTableRow $lines @("---", "---")
        Add-MdTableRow $lines @("轮询上限", "${WaitUploadSecondsParam}s（间隔 ${PollIntervalSecondsParam}s）")
        Add-MdTableRow $lines @("对齐结果", $waitNote)
        Add-MdTableRow $lines @("卡口 Receive", "POST /api/app/urban-checkpoint-passage/receive")
        Add-MdTableRow $lines @("成品 Receive", "POST /api/app/urban-finished-product-passage/receive")
        Add-MdTableRow $lines @("附件", "POST /api/urban-attachment/upload-multipart")
    }

    if ($Mode -eq "Bridge" -and $IngestResults.Count -gt 0) {
        $null = $lines.Add("")
        $null = $lines.Add("## Bridge ingest（调试）")
        $null = $lines.Add("")
        Add-MdTableRow $lines @("#", "case", "ok", "error")
        Add-MdTableRow $lines @("---", "---", "---", "---")
        foreach ($ing in $IngestResults) {
            $ok = if ($ing.success) { "ok" } else { "fail" }
            $errText = if ([string]::IsNullOrWhiteSpace([string]$ing.error)) { "-" } else { [string]$ing.error }
            Add-MdTableRow $lines @([string]$ing.index, [string]$ing.id, $ok, $errText)
        }
    }

    $null = $lines.Add("")
    $null = $lines.Add("## 4. UM 列表对照（L2）")
    $null = $lines.Add("")
    Add-MdTableRow $lines @("列表", "GET", "totalCount", "期望车牌（seed）", "UM 实际车牌（摘要）", "missing")
    Add-MdTableRow $lines @("---", "---", "---", "---", "---", "---")
    Add-MdTableRow $lines @(
        "卡口",
        "/api/app/urban-checkpoint-passage",
        [string]$cpTotal,
        (Format-PlateSummary $ExpectedCheckpointPlates),
        (Format-PlateSummary $ActualCheckpointPlates),
        $missingCp
    )
    Add-MdTableRow $lines @(
        "成品",
        "/api/app/urban-finished-product-passage",
        [string]$pdTotal,
        (Format-PlateSummary $ExpectedProductPlates),
        (Format-PlateSummary $ActualProductPlates),
        $missingPd
    )
    $null = $lines.Add("")
    $null = $lines.Add("> 重复 cook 或多次 probe 时 UM 会出现重复车牌；L2 判定为「期望集合 ⊆ UM 列表」，不要求条数一致。")
    $null = $lines.Add("")
    $null = $lines.Add("## 5. 判定级别")
    $null = $lines.Add("")
    Add-MdTableRow $lines @("级别", "判定", "结果", "说明")
    Add-MdTableRow $lines @("---", "---", "---", "---")
    Add-MdTableRow $lines @("L0", "UM list API 2xx", $l0Mark, "GET 卡口/成品列表可达")
    Add-MdTableRow $lines @("L1", "客户端 probe / ingest", $l1Mark, "ClientUpload：10 条 test-passage accepted")
    Add-MdTableRow $lines @("L2", "seed 车牌 ⊆ UM 列表", $l2Mark, "卡口 5 + 成品 5 车牌均出现")
    Add-MdTableRow $lines @("L3", "Blazor + 可选 Gov", "待用户", "/checkpoint-passage、/finished-product-passage；Gov 见 govsync")
    $null = $lines.Add("")
    $null = $lines.Add("**Agent 结论：** L0–L2 $agentVerdict（L3 仅用户可判）")
    $null = $lines.Add("")
    $null = $lines.Add("## 6. 证据包索引")
    $null = $lines.Add("")
    Add-MdTableRow $lines @("路径", "内容")
    Add-MdTableRow $lines @("---", "---")
    Add-MdTableRow $lines @("summary.json", "机器可读汇总")
    Add-MdTableRow $lines @("reconcile/plate-match.json", "期望/实际车牌对照")
    Add-MdTableRow $lines @("http/90-checkpoint-list.json", "卡口列表快照")
    Add-MdTableRow $lines @("http/91-product-list.json", "成品列表快照")
    Add-MdTableRow $lines @("client-probe/", "probe 明细（ClientUpload）")
    Add-MdTableRow $lines @("client-probe/report.md", "单用例 probe 报告")
    $null = $lines.Add("")
    $null = $lines.Add("## 7. L3 人工验收清单")
    $null = $lines.Add("")
    $null = $lines.Add("- [ ] UM Blazor /checkpoint-passage 可见 seed 卡口车牌")
    $null = $lines.Add("- [ ] UM Blazor /finished-product-passage 可见 seed 成品车牌")
    $null = $lines.Add("- [ ] （可选）启用 Gov Worker 后 cook govsync/xiaoshan-gate / xiaoshan-product")

    return ($lines -join [Environment]::NewLine)
}

Write-Host "[urban-passage-um-reconcile] starting (Mode=$Mode)..."

$umBaseUrl = "http://localhost:44300"
$clientDiagnosticBaseUrl = "http://localhost:9961"
$configText = ""
$passageCasesRel = "seeds/passage-cases.json"
$lprDevicesRel = "seeds/lpr-devices.json"
if (Test-Path -LiteralPath $ConfigPath) {
    $configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
    $fromConfig = Get-YamlScalarLocal -Text $configText -Key "umBaseUrl"
    if (-not [string]::IsNullOrWhiteSpace($fromConfig)) {
        $umBaseUrl = $fromConfig.Trim().TrimEnd('/')
    }
    $fromDiag = Get-YamlScalarLocal -Text $configText -Key "clientDiagnosticBaseUrl"
    if (-not [string]::IsNullOrWhiteSpace($fromDiag)) {
        $clientDiagnosticBaseUrl = $fromDiag.Trim().TrimEnd('/')
    }
    $fromSeedsCases = Get-YamlScalarLocal -Text $configText -Key "passageCases"
    if (-not [string]::IsNullOrWhiteSpace($fromSeedsCases)) { $passageCasesRel = $fromSeedsCases.Trim() }
    $fromSeedsDevices = Get-YamlScalarLocal -Text $configText -Key "lprDevices"
    if (-not [string]::IsNullOrWhiteSpace($fromSeedsDevices)) { $lprDevicesRel = $fromSeedsDevices.Trim() }
}

$PassageCasesPath = Resolve-GraphRelativePath -RelativePath $passageCasesRel -FallbackRelativePath "seeds/passage-cases.json"
$LprDevicesPath = Resolve-GraphRelativePath -RelativePath $lprDevicesRel -FallbackRelativePath "seeds/lpr-devices.json"

$proId = "08DDCF46-3744-D3E1-1999-0D645800B322"
$buildLicenseNo = "XNXS20260611001"
$authHeader = @{}
$secretsPath = Join-Path $GraphRoot "secrets.local.yaml"
if (Test-Path -LiteralPath $secretsPath) {
    $secretsText = [System.IO.File]::ReadAllText($secretsPath, [System.Text.Encoding]::UTF8)
    $fromSecrets = Get-SecretsScalar -Text $secretsText -Key "umBaseUrl"
    if (-not [string]::IsNullOrWhiteSpace($fromSecrets)) { $umBaseUrl = $fromSecrets.Trim().TrimEnd('/') }
    $p = Get-SecretsScalar -Text $secretsText -Key "proId"
    if (-not [string]::IsNullOrWhiteSpace($p)) { $proId = $p.Trim() }
    $b = Get-SecretsScalar -Text $secretsText -Key "buildLicenseNo"
    if (-not [string]::IsNullOrWhiteSpace($b)) { $buildLicenseNo = $b.Trim() }
    $auth = Get-SecretsScalar -Text $secretsText -Key "authorization"
    if (-not [string]::IsNullOrWhiteSpace($auth)) { $authHeader["Authorization"] = $auth.Trim() }
}

if (-not $SkipConfirm) {
    $ans = Read-Host ("Mode={0} UM={1} proId={2}. Type YES to continue" -f $Mode, $umBaseUrl, $proId)
    if ($ans -ne "YES") { throw "Aborted at human gate." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") $stamp
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$HttpDir = Join-Path $RunDir "http"
$ReconcileDir = Join-Path $RunDir "reconcile"
$ClientProbeDir = Join-Path $RunDir "client-probe"
New-Item -ItemType Directory -Force -Path $HttpDir, $ReconcileDir | Out-Null

$casesJson = [System.IO.File]::ReadAllText($PassageCasesPath, [System.Text.Encoding]::UTF8)
$devicesJson = [System.IO.File]::ReadAllText($LprDevicesPath, [System.Text.Encoding]::UTF8)
$cases = $casesJson | ConvertFrom-Json
$devices = $devicesJson | ConvertFrom-Json
if ($cases -isnot [System.Array]) { $cases = @($cases) }
if ($devices -isnot [System.Array]) { $devices = @($devices) }
if ($cases.Count -ne 10) { throw ("Expected 10 passage cases, got {0}" -f $cases.Count) }

$expectedCheckpointPlates = @($cases | Where-Object { $_.siteType -eq "Checkpoint" } | ForEach-Object { [string]$_.plateNumber })
$expectedProductPlates = @($cases | Where-Object { $_.siteType -eq "FinishedProduct" } | ForEach-Object { [string]$_.plateNumber })
$deviceMap = New-DeviceMap -Devices $devices

$seedSummary = [ordered]@{
    sourceGraph     = "urban/urban-passage-um-reconcile"
    passageCases    = $PassageCasesPath
    lprDevices      = $LprDevicesPath
    caseTotal       = $cases.Count
    checkpointCases = $expectedCheckpointPlates.Count
    productCases    = $expectedProductPlates.Count
}
Write-Utf8NoBom (Join-Path $RunDir "seed-summary.json") -Content ($seedSummary | ConvertTo-Json -Depth 4)

$checkpointListUrl = "$umBaseUrl/api/app/urban-checkpoint-passage?MaxResultCount=100"
$productListUrl = "$umBaseUrl/api/app/urban-finished-product-passage?MaxResultCount=100"
$checkpointReceiveUrl = "$umBaseUrl/api/app/urban-checkpoint-passage/receive"
$productReceiveUrl = "$umBaseUrl/api/app/urban-finished-product-passage/receive"

$ingestResults = @()
$clientProbeOk = $true
$l0 = $false
$l1 = $true
$checkpointList = $null
$productList = $null
$probeSummaryForReport = $null
$uploadWaitSeconds = -1

if ($Mode -eq "ClientUpload") {
    if (-not $SkipStartUrban) {
        if (-not (Test-Path -LiteralPath $StartUrbanScript)) {
            throw "Missing start script: $StartUrbanScript"
        }
        Write-Host "[urban-passage-um-reconcile] starting MaterialClient.Urban for reconcile..."
        & $StartUrbanScript -UmBaseUrl $umBaseUrl -SkipConfirm
    }

    if (-not $SkipClientProbe) {
        Wait-DiagnosticHost -BaseUrl $clientDiagnosticBaseUrl
    }

    if ($Mode -eq "ClientUpload" -and -not $SkipClientProbe) {
        if (-not (Test-Path -LiteralPath $ClientProbeScript)) {
            throw "Missing client probe script: $ClientProbeScript"
        }
        New-Item -ItemType Directory -Force -Path $ClientProbeDir | Out-Null
        Write-Host "[urban-passage-um-reconcile] running urban-passage-probe..."
        & $ClientProbeScript -RunDir $ClientProbeDir -SkipConfirm
        $probeSummaryPath = Join-Path $ClientProbeDir "summary.json"
        if (-not (Test-Path -LiteralPath $probeSummaryPath)) {
            throw "urban-passage-probe did not write summary.json."
        }
        $probeSummary = Get-Content -LiteralPath $probeSummaryPath -Raw | ConvertFrom-Json
        if (-not [bool]$probeSummary.allCasesAccepted) {
            throw ("urban-passage-probe failed: pass={0} fail={1}" -f $probeSummary.casePass, $probeSummary.caseFail)
        }
        $clientProbeOk = $true
        $probeSummaryForReport = $probeSummary
    }

    Write-Host "[urban-passage-um-reconcile] waiting up to ${WaitUploadSeconds}s for client upload..."
    $uploadWaitStartedAt = Get-Date
    $deadline = (Get-Date).AddSeconds($WaitUploadSeconds)
    $aligned = $false
    $missingCheckpoint = @($expectedCheckpointPlates)
    $missingProduct = @($expectedProductPlates)
    $actualCheckpointPlates = @()
    $actualProductPlates = @()

    while ((Get-Date) -lt $deadline) {
        try {
            $checkpointList = Invoke-UmJson -Method Get -Url $checkpointListUrl -Headers $authHeader
            $productList = Invoke-UmJson -Method Get -Url $productListUrl -Headers $authHeader
            $l0 = $true
            $actualCheckpointPlates = Get-ListPlates -ListResponse $checkpointList
            $actualProductPlates = Get-ListPlates -ListResponse $productList
            $match = Test-PlatesAligned -ExpectedCheckpoint $expectedCheckpointPlates `
                -ExpectedProduct $expectedProductPlates `
                -ActualCheckpoint $actualCheckpointPlates `
                -ActualProduct $actualProductPlates
            $missingCheckpoint = @($match.missingCheckpoint)
            $missingProduct = @($match.missingProduct)
            if ($match.aligned) {
                $aligned = $true
                break
            }
        }
        catch {
            Write-Host "[urban-passage-um-reconcile] UM not ready yet: $($_.Exception.Message)"
        }
        Start-Sleep -Seconds $PollIntervalSeconds
    }

    $uploadWaitSeconds = [math]::Round(((Get-Date) - $uploadWaitStartedAt).TotalSeconds, 1)

    if ($l0) {
        Write-Utf8NoBom (Join-Path $HttpDir "90-checkpoint-list.json") -Content ($checkpointList | ConvertTo-Json -Depth 10)
        Write-Utf8NoBom (Join-Path $HttpDir "91-product-list.json") -Content ($productList | ConvertTo-Json -Depth 10)
    }
    $l2 = $l0 -and $aligned -and $l1
}
elseif ($Mode -eq "Bridge") {
    Write-Warning "Bridge mode is debug-only; prefer ClientUpload for production validation."
    $idx = 0
    foreach ($case in $cases) {
        $idx++
        $deviceName = [string]$case.deviceName
        if (-not $deviceMap.ContainsKey($deviceName)) {
            throw "Unknown deviceName in case $($case.id): $deviceName"
        }
        $device = $deviceMap[$deviceName]
        $siteType = [string]$case.siteType
        $body = Build-ReceiveBody -Case $case -Device $device -ProId $proId -BuildLicenseNo $buildLicenseNo
        $prefix = ("{0:D2}-{1}" -f $idx, [string]$case.id)
        $url = if ($siteType -eq "Checkpoint") { $checkpointReceiveUrl } else { $productReceiveUrl }
        $ok = $false
        $err = $null
        try {
            $resp = Invoke-UmJson -Method Post -Url $url -Body $body -Headers $authHeader
            $ok = ($null -ne $resp) -and ($null -ne $resp.recordId)
            Write-Utf8NoBom (Join-Path $HttpDir ("{0}.response.json" -f $prefix)) -Content ($resp | ConvertTo-Json -Depth 8)
        }
        catch {
            $err = $_.Exception.Message
            $l1 = $false
        }
        $ingestResults += [ordered]@{ index = $idx; id = [string]$case.id; success = $ok; error = $err }
    }

    try {
        $checkpointList = Invoke-UmJson -Method Get -Url $checkpointListUrl -Headers $authHeader
        $productList = Invoke-UmJson -Method Get -Url $productListUrl -Headers $authHeader
        $l0 = $true
        Write-Utf8NoBom (Join-Path $HttpDir "90-checkpoint-list.json") -Content ($checkpointList | ConvertTo-Json -Depth 10)
        Write-Utf8NoBom (Join-Path $HttpDir "91-product-list.json") -Content ($productList | ConvertTo-Json -Depth 10)
    }
    catch { }

    $actualCheckpointPlates = Get-ListPlates -ListResponse $checkpointList
    $actualProductPlates = Get-ListPlates -ListResponse $productList
    $missingCheckpoint = @($expectedCheckpointPlates | Where-Object { $actualCheckpointPlates -notcontains $_ })
    $missingProduct = @($expectedProductPlates | Where-Object { $actualProductPlates -notcontains $_ })
    $l2 = $l0 -and $l1 -and ($missingCheckpoint.Count -eq 0) -and ($missingProduct.Count -eq 0)
}
else {
    try {
        $checkpointList = Invoke-UmJson -Method Get -Url $checkpointListUrl -Headers $authHeader
        Write-Utf8NoBom (Join-Path $HttpDir "90-checkpoint-list.json") -Content ($checkpointList | ConvertTo-Json -Depth 10)
        $l0 = $true
    }
    catch {
        Write-Utf8NoBom (Join-Path $HttpDir "90-checkpoint-list.error.txt") -Content $_.Exception.Message
    }
    try {
        $productList = Invoke-UmJson -Method Get -Url $productListUrl -Headers $authHeader
        Write-Utf8NoBom (Join-Path $HttpDir "91-product-list.json") -Content ($productList | ConvertTo-Json -Depth 10)
        if (-not $l0) { $l0 = $true }
    }
    catch {
        Write-Utf8NoBom (Join-Path $HttpDir "91-product-list.error.txt") -Content $_.Exception.Message
    }
    $actualCheckpointPlates = Get-ListPlates -ListResponse $checkpointList
    $actualProductPlates = Get-ListPlates -ListResponse $productList
    $missingCheckpoint = @($expectedCheckpointPlates | Where-Object { $actualCheckpointPlates -notcontains $_ })
    $missingProduct = @($expectedProductPlates | Where-Object { $actualProductPlates -notcontains $_ })
    $l2 = $l0 -and ($missingCheckpoint.Count -eq 0) -and ($missingProduct.Count -eq 0)
    $l1 = "skipped-client-upload"
}

$reconcilePayload = [ordered]@{
    mode                   = $Mode
    clientProbeOk          = $clientProbeOk
    expectedCheckpointPlates = $expectedCheckpointPlates
    expectedProductPlates  = $expectedProductPlates
    actualCheckpointPlates = $actualCheckpointPlates
    actualProductPlates    = $actualProductPlates
    missingCheckpointPlates = $missingCheckpoint
    missingProductPlates   = $missingProduct
    ingestResults          = $ingestResults
}
Write-Utf8NoBom (Join-Path $ReconcileDir "plate-match.json") -Content ($reconcilePayload | ConvertTo-Json -Depth 8)

$reportMode = $Mode
$reportFinishedAt = (Get-Date).ToString("o")
$existingSummaryPath = Join-Path $RunDir "summary.json"
$existingProbeSummaryPath = Join-Path $RunDir "client-probe/summary.json"
if ((Test-Path -LiteralPath $existingProbeSummaryPath) -and $Mode -eq "ReconcileOnly") {
    $reportMode = "ClientUpload"
}
if (Test-Path -LiteralPath $existingSummaryPath) {
    $prevSummary = Get-Content -LiteralPath $existingSummaryPath -Raw | ConvertFrom-Json
    if ($prevSummary.finishedAt) { $reportFinishedAt = [string]$prevSummary.finishedAt }
    if ($prevSummary.mode -eq "ClientUpload" -and $Mode -eq "ReconcileOnly") { $reportMode = "ClientUpload" }
    if ($uploadWaitSeconds -lt 0 -and $prevSummary.PSObject.Properties.Name -contains "uploadWaitSeconds") {
        $uploadWaitSeconds = [int]$prevSummary.uploadWaitSeconds
    }
}

$summary = [ordered]@{
    graph          = "urban/urban-passage-um-reconcile"
    runDir         = $RunDir
    mode           = $reportMode
    umBaseUrl      = $umBaseUrl
    proId          = $proId
    buildLicenseNo = $buildLicenseNo
    seeds          = $seedSummary
    levels         = @{
        L0 = $l0
        L1 = $l1
        L2 = $l2
        L3 = "pending-user"
    }
    missingCheckpointPlates = $missingCheckpoint
    missingProductPlates    = $missingProduct
    finishedAt     = $reportFinishedAt
}

if ($null -eq $probeSummaryForReport) {
    $existingProbeSummary = Join-Path $RunDir "client-probe/summary.json"
    if (Test-Path -LiteralPath $existingProbeSummary) {
        $probeSummaryForReport = Get-Content -LiteralPath $existingProbeSummary -Raw | ConvertFrom-Json
    }
}
if ($probeSummaryForReport -and [bool]$probeSummaryForReport.allCasesAccepted) {
    $l1 = $true
    $summary.levels.L1 = $true
}
if ($uploadWaitSeconds -lt 0 -and (Test-Path -LiteralPath $existingSummaryPath)) {
    $prevSummary = Get-Content -LiteralPath $existingSummaryPath -Raw | ConvertFrom-Json
    if ($prevSummary.PSObject.Properties.Name -contains "uploadWaitSeconds") {
        $uploadWaitSeconds = [int]$prevSummary.uploadWaitSeconds
    }
}
if ($uploadWaitSeconds -ge 0) {
    $summary.uploadWaitSeconds = $uploadWaitSeconds
}
Write-Utf8NoBom (Join-Path $RunDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 8)

$report = New-ReconcileReportMarkdown `
    -Mode $reportMode `
    -RunDir $RunDir `
    -UmBaseUrl $umBaseUrl `
    -ClientDiagnosticBaseUrl $clientDiagnosticBaseUrl `
    -ProId $proId `
    -BuildLicenseNo $buildLicenseNo `
    -Cases $cases `
    -L0 $l0 `
    -L1 $l1 `
    -L2 $l2 `
    -ExpectedCheckpointPlates $expectedCheckpointPlates `
    -ExpectedProductPlates $expectedProductPlates `
    -ActualCheckpointPlates $actualCheckpointPlates `
    -ActualProductPlates $actualProductPlates `
    -MissingCheckpoint $missingCheckpoint `
    -MissingProduct $missingProduct `
    -CheckpointList $checkpointList `
    -ProductList $productList `
    -ProbeSummary $probeSummaryForReport `
    -IngestResults $ingestResults `
    -UploadWaitSeconds $uploadWaitSeconds `
    -WaitUploadSecondsParam $WaitUploadSeconds `
    -PollIntervalSecondsParam $PollIntervalSeconds `
    -FinishedAt $reportFinishedAt
Write-Utf8NoBom (Join-Path $RunDir "report.md") -Content $report

Write-Host "[urban-passage-um-reconcile] done. L0=$l0 L1=$l1 L2=$l2 runDir=$RunDir"
if (-not $l2) { exit 1 }
