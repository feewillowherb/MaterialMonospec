#Requires -Version 5.1
<#
.SYNOPSIS
  Temporary SSH_ASKPASS for a password that must not be written to argv, evidence, or the askpass file.
.DESCRIPTION
  experimental shared helper. Dot-source this file. The password stays in the process environment
  only while the SSH/SCP child runs, then the temp directory and UM_SSH_ASKPASS are removed.
#>

function New-UmSshAskPass {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("um-ssh-askpass-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $cmd = Join-Path $dir "askpass.cmd"
    $body = "@echo off`r`npowershell.exe -NoProfile -Command `"[Console]::Out.WriteLine(`$env:UM_SSH_ASKPASS)`"`r`n"
    [System.IO.File]::WriteAllText($cmd, $body, [System.Text.UTF8Encoding]::new($false))
    return $cmd
}

function Set-UmSshAskPassEnv {
    param(
        [Parameter(Mandatory = $true)]
        [string] $AskPass,
        [Parameter(Mandatory = $true)]
        [string] $Password
    )
    $script:UmSshAskPassSaved = @{
        SSH_ASKPASS         = $env:SSH_ASKPASS
        SSH_ASKPASS_REQUIRE = $env:SSH_ASKPASS_REQUIRE
        DISPLAY             = $env:DISPLAY
        UM_SSH_ASKPASS      = $env:UM_SSH_ASKPASS
    }
    $env:SSH_ASKPASS = $AskPass
    $env:SSH_ASKPASS_REQUIRE = "force"
    $env:DISPLAY = "1"
    $env:UM_SSH_ASKPASS = $Password
}

function Clear-UmSshAskPassEnv {
    foreach ($name in @("SSH_ASKPASS", "SSH_ASKPASS_REQUIRE", "DISPLAY", "UM_SSH_ASKPASS")) {
        $saved = $script:UmSshAskPassSaved[$name]
        if ([string]::IsNullOrEmpty($saved)) {
            Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
        }
        else {
            Set-Item -Path "Env:$name" -Value $saved
        }
    }
    $script:UmSshAskPassSaved = $null
}

function Remove-UmSshAskPass {
    param([string] $AskPass)
    if ([string]::IsNullOrWhiteSpace($AskPass)) { return }
    $dir = Split-Path -Parent $AskPass
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}

function Redact-UmSecret {
    param([string] $Text, [string] $Secret)
    if ([string]::IsNullOrEmpty($Text) -or [string]::IsNullOrEmpty($Secret)) { return $Text }
    return $Text.Replace($Secret, "***")
}
