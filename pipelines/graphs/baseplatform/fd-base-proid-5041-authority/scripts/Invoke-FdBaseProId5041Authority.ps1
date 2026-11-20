# experimental
# Dry-run by default. -Apply commits one JC_ProductAuthority change on 135 FD_Base.
[CmdletBinding()]
param(
    [switch] $Apply
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')).Path
$ConfigPath = Join-Path $GraphRoot 'config.yaml'
$RunId = Get-Date -Format 'yyyy-MM-ddTHHmmss'
$RunDir = Join-Path $GraphRoot (Join-Path 'runs' $RunId)

function Redact([string] $Text) {
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $value = $Text
    if ($value.Length -gt 240 -or $value -match '(?i)ConnectionStrings|SecretKey|amqp://') {
        return 'Connection source could not be read.'
    }
    $value = $value -replace '(?i)(password|pwd)\s*=\s*[^;''"\s]*', '$1=***'
    return ($value -replace '(?i)(user id|uid)\s*=\s*[^;''"\s]*', '$1=***')
}

function Read-YamlScalar([string] $Text, [string] $Key) {
    $pattern = '(?m)^\s*' + [regex]::Escape($Key) + ':\s*"?([^"#\r\n]+?)"?\s*$'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value.Trim()
}

function Parse-Stamp([string] $Text) {
    return [datetime]::ParseExact($Text, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Read-Grants([string] $Text) {
    $matches = [regex]::Matches(
        $Text,
        '(?m)^\s+-\s+proId:\s*"([0-9a-fA-F-]{36})"\s*[\r\n]+\s+productCode:\s*(\d+)\s*$')
    $grants = @()
    foreach ($match in $matches) {
        $grants += [pscustomobject]@{
            ProId       = [guid]$match.Groups[1].Value
            ProductCode = [int]$match.Groups[2].Value
        }
    }
    return $grants
}

function Read-ConnectionString([string] $SecretsPath, [string] $AppsettingsPath, [string] $ConnectionKey) {
    if (Test-Path -LiteralPath $SecretsPath) {
        $secretText = Get-Content -LiteralPath $SecretsPath -Raw -Encoding UTF8
        $inline = Read-YamlScalar $secretText 'connectionString'
        if (-not [string]::IsNullOrWhiteSpace($inline)) { return $inline }
    }

    if (-not (Test-Path -LiteralPath $AppsettingsPath)) {
        throw "Missing connection source: $AppsettingsPath"
    }
    $json = Get-Content -LiteralPath $AppsettingsPath -Raw -Encoding UTF8
    $section = [regex]::Match($json, '"ConnectionStrings"\s*:\s*\{(?<body>[^{}]*)\}')
    if (-not $section.Success) { throw 'ConnectionStrings section is missing.' }
    $keyPattern = '"' + [regex]::Escape($ConnectionKey) + '"\s*:\s*"(?<cs>[^"]+)"'
    $found = [regex]::Match($section.Groups['body'].Value, $keyPattern)
    if (-not $found.Success) { throw "Connection key $ConnectionKey is missing." }
    $value = $found.Groups['cs'].Value
    if ($value -notmatch '(?i)(data source|server)\s*=') {
        throw "Connection key $ConnectionKey is not a SQL connection."
    }
    return $value
}

function Open-Target([string] $ConnectionString) {
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $ConnectionString
    if ([string]$builder.DataSource -notmatch '(^|\.)135([,\\]|$)') {
        throw 'Target server fingerprint mismatch.'
    }
    if ([string]$builder.InitialCatalog -ne 'FD_Base') {
        throw 'Target database mismatch.'
    }
    $builder['Connect Timeout'] = 15
    $builder['Application Name'] = 'graph-fd-base-proid-5041-authority'
    if ($builder.ContainsKey('ApplicationIntent')) { [void]$builder.Remove('ApplicationIntent') }
    $connection = New-Object System.Data.SqlClient.SqlConnection ($builder.ConnectionString)
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandText = 'SELECT DB_NAME()'
    $name = [string]$command.ExecuteScalar()
    if ($name -ne 'FD_Base') { throw 'Open database is not FD_Base.' }
    return $connection
}

function Invoke-Rows([System.Data.SqlClient.SqlConnection] $Connection, [string] $Sql, [hashtable] $Parameters, [System.Data.SqlClient.SqlTransaction] $Transaction) {
    $command = $Connection.CreateCommand()
    $command.CommandText = $Sql
    $command.CommandTimeout = 30
    if ($null -ne $Transaction) { $command.Transaction = $Transaction }
    foreach ($name in $Parameters.Keys) {
        $value = $Parameters[$name]
        if ($null -eq $value) { $value = [DBNull]::Value }
        [void]$command.Parameters.AddWithValue($name, $value)
    }
    $table = New-Object System.Data.DataTable
    $reader = $command.ExecuteReader()
    $table.Load($reader)
    $reader.Close()
    $rows = @()
    foreach ($row in $table.Rows) {
        $item = [ordered]@{}
        foreach ($column in $table.Columns) {
            $cell = $row[$column]
            if ($cell -is [DBNull]) { $item[$column.ColumnName] = $null }
            elseif ($cell -is [datetime]) { $item[$column.ColumnName] = $cell.ToString('yyyy-MM-dd HH:mm:ss') }
            else { $item[$column.ColumnName] = $cell }
        }
        $rows += [pscustomobject]$item
    }
    return ,$rows
}

function Invoke-NonQuery([System.Data.SqlClient.SqlConnection] $Connection, [string] $Sql, [hashtable] $Parameters, [System.Data.SqlClient.SqlTransaction] $Transaction) {
    $command = $Connection.CreateCommand()
    $command.CommandText = $Sql
    $command.CommandTimeout = 30
    $command.Transaction = $Transaction
    foreach ($name in $Parameters.Keys) {
        $value = $Parameters[$name]
        if ($null -eq $value) { $value = [DBNull]::Value }
        [void]$command.Parameters.AddWithValue($name, $value)
    }
    return $command.ExecuteNonQuery()
}

function Get-Clock([System.Data.SqlClient.SqlConnection] $Connection, [int] $Years, [System.Data.SqlClient.SqlTransaction] $Transaction) {
    $rows = Invoke-Rows $Connection @"
SELECT CONVERT(varchar(19), GETDATE(), 120) AS NowLocal,
       CONVERT(varchar(19), DATEADD(year, @Years, GETDATE()), 120) AS EndLocal
"@ @{ Years = $Years } $Transaction
    return $rows[0]
}

function Get-Product([System.Data.SqlClient.SqlConnection] $Connection, [string] $ProductText, [System.Data.SqlClient.SqlTransaction] $Transaction) {
    $rows = Invoke-Rows $Connection @"
SELECT ProductCode, Status, DeleteStatus
FROM dbo.JC_Product
WHERE ProductCode = @ProductText
"@ @{ ProductText = $ProductText } $Transaction
    return ,$rows
}

function Get-Authority([System.Data.SqlClient.SqlConnection] $Connection, [guid] $ProId, [int] $ProductCode, [System.Data.SqlClient.SqlTransaction] $Transaction, [switch] $Lock) {
    $hint = ''
    if ($Lock) { $hint = 'WITH (UPDLOCK, HOLDLOCK)' }
    $sql = @"
SELECT AuthId, ProductCode, ProId, AuthStatus, CheckStatus, DeleteStatus,
       CONVERT(varchar(19), AuthBeginTime, 120) AS AuthBeginTime,
       CONVERT(varchar(19), AuthEndTime, 120) AS AuthEndTime,
       CoId, CreateUserId, CreateUser, UpdateUserId, UpdateUser,
       AuthUserId, AuthUser, CheckUserId, CheckUser
FROM dbo.JC_ProductAuthority $hint
WHERE ProId = @ProId AND ProductCode = @ProductCode
"@
    $rows = Invoke-Rows $Connection $sql @{ ProId = $ProId; ProductCode = $ProductCode } $Transaction
    return ,$rows
}

function Get-Templates([System.Data.SqlClient.SqlConnection] $Connection, [guid] $ProId, [System.Data.SqlClient.SqlTransaction] $Transaction, [switch] $Lock) {
    $hint = ''
    if ($Lock) { $hint = 'WITH (UPDLOCK, HOLDLOCK)' }
    $sql = @"
SELECT AuthId, ProductCode, CoId, AuthStatus, CheckStatus, DeleteStatus,
       CONVERT(varchar(19), AuthEndTime, 120) AS AuthEndTime,
       CreateUserId, CreateUser, UpdateUserId, UpdateUser,
       AuthUserId, AuthUser, CheckUserId, CheckUser
FROM dbo.JC_ProductAuthority $hint
WHERE ProId = @ProId AND DeleteStatus = 0
"@
    $rows = Invoke-Rows $Connection $sql @{ ProId = $ProId } $Transaction
    return ,$rows
}

function Get-UniqueIndexes([System.Data.SqlClient.SqlConnection] $Connection, [System.Data.SqlClient.SqlTransaction] $Transaction) {
    $rows = Invoke-Rows $Connection @"
SELECT i.index_id AS IndexId, i.name AS IndexName, c.name AS ColumnName
FROM sys.indexes i
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE i.object_id = OBJECT_ID(N'dbo.JC_ProductAuthority')
  AND i.is_unique = 1
  AND ic.is_included_column = 0
ORDER BY i.index_id, ic.key_ordinal
"@ @{} $Transaction
    return ,$rows
}

function Assert-InsertAllowed($Indexes, $Existing) {
    $groups = $Indexes | Group-Object IndexId
    foreach ($group in $groups) {
        $columns = @($group.Group | ForEach-Object { [string]$_.ColumnName })
        $known = @('AuthId', 'ProductCode', 'ProId', 'DeleteStatus')
        $extra = @($columns | Where-Object { $known -notcontains $_ })
        if ($extra.Count -gt 0) { continue }
        if ($columns -contains 'AuthId' -and $columns.Count -eq 1) { continue }
        $conflict = @($Existing | Where-Object {
            $deleteOk = ($columns -notcontains 'DeleteStatus') -or ([int]$_.DeleteStatus -eq 0)
            return $deleteOk
        })
        if ($conflict.Count -gt 0) {
            throw 'A unique index already covers this ProId and ProductCode.'
        }
    }
}

function Select-Template($Templates) {
    $active = @($Templates | Where-Object { [int]$_.DeleteStatus -eq 0 })
    if ($active.Count -eq 0) { throw 'ProId has no undeleted authority row to copy CoId from.' }
    $coIds = @($active | Select-Object -ExpandProperty CoId -Unique)
    if ($coIds.Count -ne 1) { throw 'ProId has more than one CoId.' }
    $preferred = @($active | Where-Object { [int]$_.AuthStatus -eq 1 -and [int]$_.CheckStatus -eq 2 })
    $pool = $active
    if ($preferred.Count -gt 0) { $pool = $preferred }
    $chosen = $pool | Sort-Object AuthEndTime -Descending | Select-Object -First 1
    foreach ($field in @('CreateUserId', 'UpdateUserId', 'AuthUserId', 'CheckUserId')) {
        if ($null -eq $chosen.$field) { throw "Template $field is missing." }
    }
    if ([string]::IsNullOrWhiteSpace([string]$chosen.CreateUser)) { throw 'Template CreateUser is empty.' }
    return $chosen
}

function Get-PublicRow($Row) {
    if ($null -eq $Row) { return $null }
    return [ordered]@{
        authId        = [int64]$Row.AuthId
        authStatus    = [int]$Row.AuthStatus
        checkStatus   = [int]$Row.CheckStatus
        deleteStatus  = [int]$Row.DeleteStatus
        authBeginTime = [string]$Row.AuthBeginTime
        authEndTime   = [string]$Row.AuthEndTime
    }
}

function Plan-Grant($Undeleted, $Clock) {
    if ($Undeleted.Count -gt 1) { throw 'More than one undeleted authority row exists for this ProId and ProductCode.' }
    if ($Undeleted.Count -eq 0) {
        return [pscustomobject]@{ Action = 'insert'; Before = $null }
    }
    $row = $Undeleted[0]
    $covers = (Parse-Stamp ([string]$row.AuthEndTime)) -ge (Parse-Stamp ([string]$Clock.EndLocal))
    $granted = ([int]$row.AuthStatus -eq 1) -and ([int]$row.CheckStatus -eq 2)
    $action = 'update'
    if ($covers -and $granted) { $action = 'noop' }
    return [pscustomobject]@{ Action = $action; Before = $row }
}

function Write-Utf8([string] $Path, [string] $Content) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

$summary = [ordered]@{
    graphId       = 'fd-base-proid-5041-authority'
    graphPath     = 'pipelines/graphs/baseplatform/fd-base-proid-5041-authority'
    runId         = $RunId
    result        = 'unknown'
    applied       = $false
    action        = $null
    proId         = $null
    productCode   = $null
    termYears     = $null
    database      = 'FD_Base'
    serverMatched = $false
    message       = $null
}
$connection = $null
$transaction = $null

try {
    if (Test-Path -LiteralPath $RunDir) { throw "Run directory already exists: $RunId" }
    New-Item -ItemType Directory -Path (Join-Path $RunDir 'prepare') | Out-Null

    $configText = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
    $years = [int](Read-YamlScalar $configText 'termYears')
    $authStatus = [int](Read-YamlScalar $configText 'authStatus')
    $checkStatus = [int](Read-YamlScalar $configText 'checkStatus')
    if ($years -ne 1) { throw 'termYears must be 1.' }
    if ($authStatus -ne 1 -or $checkStatus -ne 2) { throw 'Grant shape must stay AuthStatus 1 and CheckStatus 2.' }
    $grants = @(Read-Grants $configText)
    if ($grants.Count -ne 1) { throw 'This graph expects exactly one grant.' }
    $grant = $grants[0]
    if ($grant.ProductCode -ne 5041) { throw 'This graph only grants ProductCode 5041.' }

    $summary.proId = $grant.ProId.ToString()
    $summary.productCode = $grant.ProductCode
    $summary.termYears = $years

    $secretsPath = Join-Path $GraphRoot 'secrets.local.yaml'
    $appsettingsRel = Read-YamlScalar $configText 'appsettingsRel'
    $connectionKey = Read-YamlScalar $configText 'connectionKey'
    $appsettingsPath = Join-Path $RepoRoot ($appsettingsRel -replace '/', '\')
    $connectionString = Read-ConnectionString $secretsPath $appsettingsPath $connectionKey
    $connection = Open-Target $connectionString
    $summary.serverMatched = $true

    $clock = Get-Clock $connection $years $null
    $products = Get-Product $connection ([string]$grant.ProductCode) $null
    if ($products.Count -ne 1) { throw 'JC_Product does not contain exactly one 5041 row.' }
    if ([int]$products[0].DeleteStatus -ne 0 -or [int]$products[0].Status -ne 1) {
        throw 'Product 5041 is deleted or not enabled.'
    }

    $existing = Get-Authority $connection $grant.ProId $grant.ProductCode $null
    $undeleted = @($existing | Where-Object { [int]$_.DeleteStatus -eq 0 })
    $templates = Get-Templates $connection $grant.ProId $null
    $template = Select-Template $templates
    $plan = Plan-Grant $undeleted $clock
    if ($plan.Action -eq 'insert') {
        $indexes = Get-UniqueIndexes $connection $null
        Assert-InsertAllowed $indexes $existing
    }
    $summary.action = $plan.Action

    $planDoc = [ordered]@{
        dryRun            = (-not $Apply)
        action            = $plan.action
        proId             = $grant.ProId.ToString()
        productCode       = $grant.ProductCode
        termYears         = $years
        authStatus        = $authStatus
        checkStatus       = $checkStatus
        serverNow         = [string]$clock.NowLocal
        plannedEnd        = [string]$clock.EndLocal
        productLocated    = $true
        organizationReady = $true
        before            = Get-PublicRow $plan.Before
    }
    Write-Utf8 (Join-Path $RunDir 'prepare\plan.json') ($planDoc | ConvertTo-Json -Depth 6)

    if ($Apply) {
        $transaction = $connection.BeginTransaction()
        $lockedExisting = Get-Authority $connection $grant.ProId $grant.ProductCode $transaction -Lock
        $lockedUndeleted = @($lockedExisting | Where-Object { [int]$_.DeleteStatus -eq 0 })
        $lockedTemplates = Get-Templates $connection $grant.ProId $transaction -Lock
        $lockedTemplate = Select-Template $lockedTemplates
        $lockedClock = Get-Clock $connection $years $transaction
        $lockedPlan = Plan-Grant $lockedUndeleted $lockedClock
        $summary.action = $lockedPlan.Action

        if ($lockedPlan.Action -eq 'insert') {
            $indexes = Get-UniqueIndexes $connection $transaction
            Assert-InsertAllowed $indexes $lockedExisting
            $inserted = Invoke-NonQuery $connection @"
INSERT INTO dbo.JC_ProductAuthority (
    ProductCode, ProId, AuthStatus, AuthBeginTime, AuthEndTime,
    CreateTime, CreateUserId, CreateUser, UpdateTime, UpdateUserId, UpdateUser,
    DeleteStatus, CoId, AuthTime, AuthUserId, AuthUser,
    CheckStatus, CheckTime, CheckUserId, CheckUser)
VALUES (
    @ProductCode, @ProId, @AuthStatus, GETDATE(), DATEADD(year, @Years, GETDATE()),
    GETDATE(), @CreateUserId, @CreateUser, GETDATE(), @UpdateUserId, @UpdateUser,
    0, @CoId, GETDATE(), @AuthUserId, @AuthUser,
    @CheckStatus, GETDATE(), @CheckUserId, @CheckUser)
"@ @{
                ProductCode = $grant.ProductCode
                ProId       = $grant.ProId
                AuthStatus  = $authStatus
                Years       = $years
                CreateUserId = [int]$lockedTemplate.CreateUserId
                CreateUser  = [string]$lockedTemplate.CreateUser
                UpdateUserId = [int]$lockedTemplate.UpdateUserId
                UpdateUser  = $lockedTemplate.UpdateUser
                CoId        = [int]$lockedTemplate.CoId
                AuthUserId  = [int]$lockedTemplate.AuthUserId
                AuthUser    = $lockedTemplate.AuthUser
                CheckStatus = $checkStatus
                CheckUserId = [int]$lockedTemplate.CheckUserId
                CheckUser   = $lockedTemplate.CheckUser
            } $transaction
            if ($inserted -ne 1) { throw 'Insert did not affect one row.' }
        }
        elseif ($lockedPlan.Action -eq 'update') {
            $updated = Invoke-NonQuery $connection @"
UPDATE dbo.JC_ProductAuthority
SET AuthStatus = @AuthStatus,
    CheckStatus = @CheckStatus,
    AuthEndTime = CASE
        WHEN AuthEndTime >= DATEADD(year, @Years, GETDATE()) THEN AuthEndTime
        ELSE DATEADD(year, @Years, GETDATE())
    END,
    UpdateTime = GETDATE(),
    UpdateUserId = @UpdateUserId,
    UpdateUser = @UpdateUser
WHERE AuthId = @AuthId
  AND ProId = @ProId
  AND ProductCode = @ProductCode
  AND DeleteStatus = 0
"@ @{
                AuthStatus   = $authStatus
                CheckStatus  = $checkStatus
                Years        = $years
                UpdateUserId = [int]$lockedTemplate.UpdateUserId
                UpdateUser   = $lockedTemplate.UpdateUser
                AuthId       = [int64]$lockedPlan.Before.AuthId
                ProId        = $grant.ProId
                ProductCode  = $grant.ProductCode
            } $transaction
            if ($updated -ne 1) { throw 'Update did not affect one row.' }
        }

        $afterRows = @(Get-Authority $connection $grant.ProId $grant.ProductCode $transaction | Where-Object { [int]$_.DeleteStatus -eq 0 })
        if ($afterRows.Count -ne 1) { throw 'Validation did not find one undeleted authority row.' }
        $after = $afterRows[0]
        $endOk = (Parse-Stamp ([string]$after.AuthEndTime)) -ge (Parse-Stamp ([string]$lockedClock.EndLocal))
        $shapeOk = ([int]$after.AuthStatus -eq 1) -and ([int]$after.CheckStatus -eq 2)
        if (-not $endOk -or -not $shapeOk) { throw 'Re-read authority does not cover one granted year.' }
        $transaction.Commit()
        $transaction = $null
        $summary.applied = $true
        $summary.after = Get-PublicRow $after
    }

    $summary.result = 'pass'
    $summary.message = if ($Apply) { 'Apply committed.' } else { 'Dry-run only. No row was written.' }
}
catch {
    if ($null -ne $transaction) {
        try { $transaction.Rollback() } catch { }
        $transaction = $null
    }
    $summary.result = 'fail'
    $summary.message = Redact ([string]$_.Exception.Message)
}
finally {
    if ($null -ne $connection) { $connection.Dispose() }
    $json = $summary | ConvertTo-Json -Depth 6
    Write-Utf8 (Join-Path $RunDir 'summary.json') $json
    $report = @(
        '# fd-base-proid-5041-authority'
        ''
        "- runId: ``$RunId``"
        "- result: ``$($summary.result)``"
        "- applied: ``$($summary.applied)``"
        "- action: ``$($summary.action)``"
        "- proId: ``$($summary.proId)``"
        "- productCode: ``$($summary.productCode)``"
        "- termYears: ``$($summary.termYears)``"
        "- message: $($summary.message)"
        ''
        'P3 stays with the user. This run does not approve a product change.'
    ) -join "`r`n"
    Write-Utf8 (Join-Path $RunDir 'report.md') ($report + "`r`n")
    $rev = ''
    try { $rev = (& git -C $RepoRoot rev-parse --short HEAD) } catch { $rev = '' }
    $manifest = @"
graphId: $($summary.graphId)
graphPath: $($summary.graphPath)
runId: $RunId
result: $($summary.result)
gitRevision: "$rev"
contractPath: pipelines/graphs/baseplatform/fd-base-proid-5041-authority/contract.yaml
artifacts:
  - prepare/plan.json
  - summary.json
  - report.md
  - manifest.yaml
"@
    Write-Utf8 (Join-Path $RunDir 'manifest.yaml') $manifest
}

if ($summary.result -ne 'pass') {
    Write-Error $summary.message
    exit 1
}

Write-Output "result=$($summary.result) action=$($summary.action) applied=$($summary.applied) runId=$RunId"
exit 0
