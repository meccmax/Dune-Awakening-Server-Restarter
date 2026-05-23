#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Registers a Windows Task Scheduler task to restart the Dune Awakening
    battlegroup every 4 hours.

.NOTES
    Run this script once from an elevated PowerShell window.
    Re-running will prompt to replace the existing task if one exists.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskName   = "DuneAwakening-Restart"
$scriptPath = Join-Path $PSScriptRoot "battlegroup-management\scheduled-restart.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Could not find scheduled-restart.ps1 at: $scriptPath"
    exit 1
}

# Remove existing task if present
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

# Repeats every 4 hours for 1 year, starting at 4:00 AM
$trigger = New-ScheduledTaskTrigger `
    -RepetitionInterval (New-TimeSpan -Hours 4) `
    -RepetitionDuration (New-TimeSpan -Days 365) `
    -Once -At "04:00AM"

$settings = New-ScheduledTaskSettingsSet `
    -RunOnlyIfNetworkAvailable `
    -ExecutionTimeLimit "00:10:00" `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName    $taskName `
    -Action      $action `
    -Trigger     $trigger `
    -Settings    $settings `
    -RunLevel    Highest `
    -User        $env:USERNAME `
    -Description "Restarts the Dune Awakening battlegroup every 4 hours" | Out-Null

Write-Host ""
Write-Host "Task '$taskName' registered successfully." -ForegroundColor Green
Write-Host "Schedule: every 4 hours starting at 4:00 AM (4AM, 8AM, 12PM, 4PM, 8PM, 12AM)" -ForegroundColor Cyan
Write-Host ""
Write-Host "You will be prompted for your Windows password to store with the task." -ForegroundColor Yellow
Write-Host "To test it now, open Task Scheduler, find '$taskName', and click Run." -ForegroundColor Yellow
