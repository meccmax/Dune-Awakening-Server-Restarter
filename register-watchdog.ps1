#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Registers the crash watchdog as a scheduled task running every 5 minutes.

.NOTES
    Run this once from an elevated PowerShell window.
    The watchdog checks battlegroup health every 5 minutes and auto-restarts
    on crash if $enableCrashRestart is set to $true in scheduled-restart.ps1.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskName   = "DuneAwakening-Watchdog"
$scriptPath = Join-Path $PSScriptRoot "battlegroup-management\scheduled-watchdog.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Could not find scheduled-watchdog.ps1 at: $scriptPath"
    exit 1
}

$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    $confirm = Read-Host "Task '$taskName' already exists. Replace it? [Y/N]"
    if ($confirm -ne 'Y') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Existing task removed." -ForegroundColor Cyan
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`""

# Runs every 5 minutes continuously
$trigger = New-ScheduledTaskTrigger `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration (New-TimeSpan -Days 365) `
    -Once -At (Get-Date).Date

$settings = New-ScheduledTaskSettingsSet `
    -RunOnlyIfNetworkAvailable `
    -ExecutionTimeLimit "00:02:00" `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName    $taskName `
    -Action      $action `
    -Trigger     $trigger `
    -Settings    $settings `
    -RunLevel    Highest `
    -User        $env:USERNAME `
    -Description "Monitors Dune Awakening battlegroup health and auto-restarts on crash" | Out-Null

Write-Host ""
Write-Host "Watchdog task '$taskName' registered successfully." -ForegroundColor Green
Write-Host "Checks every 5 minutes. Auto-restart is controlled by `$enableCrashRestart in scheduled-restart.ps1." -ForegroundColor Cyan
Write-Host ""
Write-Host "You will be prompted for your Windows password to store with the task." -ForegroundColor Yellow
