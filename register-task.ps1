#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskName   = "DuneAwakening-Restart"
$scriptPath = Join-Path $PSScriptRoot "battlegroup-management\scheduled-restart.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Could not find scheduled-restart.ps1 at: $scriptPath"
    exit 1
}

$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    $confirm = Read-Host "Task '$taskName' already exists. Replace it? [Y/N]"
    if ($confirm -ne 'Y') {
        Write-Host "Aborted."
        exit 0
    }
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Existing task removed."
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`""

$trigger = New-ScheduledTaskTrigger `
    -RepetitionInterval (New-TimeSpan -Hours 4) `
    -RepetitionDuration (New-TimeSpan -Days 365) `
    -Once -At "04:00AM"

$settings = New-ScheduledTaskSettingsSet `
    -RunOnlyIfNetworkAvailable `
    -ExecutionTimeLimit "01:00:00" `
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
Write-Host "Task '$taskName' registered successfully."
Write-Host "Schedule: every 4 hours starting at 4:00 AM"
Write-Host ""
Write-Host "You will be prompted for your Windows password to store with the task."
