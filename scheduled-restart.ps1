#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Scheduled battlegroup manager for Dune Awakening dedicated server.

.DESCRIPTION
    Handles scheduled restarts with pre-restart warnings, optional update checks,
    and crash auto-restart toggle. Sends Discord notifications throughout.

.NOTES
    Intended to be run by Windows Task Scheduler.
    Configure the CONFIGURATION section below before first use.
    See README.md for full setup instructions.
#>

# ==============================================================================
# CONFIGURATION — edit these values before use
# ==============================================================================

$vmName     = 'dune-awakening'
$sshKeyPath = "C:\Users\$env:USERNAME\AppData\Local\DuneAwakeningServer\sshKey"
$webhookUrl = ""   # Paste your Discord webhook URL here (leave empty to disable)

# Restart warnings — warn players before restarting
# Set to $true to enable, $false to disable
$enableRestartWarnings = $true

# Warning times in minutes before restart (customize as needed)
$warningMinutes = @(15, 5, 1)

# Update check — check for and apply updates before restarting
# Set to $true to enable, $false to disable
$enableUpdateCheck = $false  # Currently unsupported — see README for details

# Auto-restart on crash — read by scheduled-watchdog.ps1
# Toggle here to enable/disable without re-registering the watchdog task
# Set to $true to enable, $false to disable
$enableCrashRestart = $true

# ==============================================================================
# END CONFIGURATION
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Logging
$logDir  = Join-Path $PSScriptRoot "..\logs"
$logFile = Join-Path $logDir "scheduled-restart-$(Get-Date -Format 'yyyy-MM-dd').log"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Start-Transcript -Path $logFile -Append | Out-Null

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

function Send-DiscordNotification {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][int]$Color
    )
    if ([string]::IsNullOrWhiteSpace($webhookUrl)) { return }
    try {
        $payload = @{
            embeds = @(@{
                description = $Message
                color       = $Color
            })
        } | ConvertTo-Json -Depth 4 -Compress
        Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType "application/json" -Body $payload | Out-Null
    } catch {
        Write-Warning "Discord notification failed: $_"
    }
}

function Invoke-SshCommand {
    param(
        [Parameter(Mandatory)][string]$Ip,
        [Parameter(Mandatory)][string]$Command
    )
    $output = & ssh -o StrictHostKeyChecking=no -o LogLevel=QUIET -o IdentitiesOnly=yes `
                    -i $sshKeyPath "dune@$Ip" $Command 2>&1
    return @{ ExitCode = $LASTEXITCODE; Output = ($output | Out-String) }
}

function Get-VmIp {
    $ip = (Get-VMNetworkAdapter -VMName $vmName).IPAddresses |
          Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } |
          Select-Object -First 1
    return $ip
}

function Get-ServerVersion {
    param([string]$Ip)
    $result = Invoke-SshCommand -Ip $Ip -Command "/home/dune/.dune/bin/battlegroup status"
    $match = [regex]::Match($result.Output, '(\d{7,}-\d+-\w+)')
    if ($match.Success) { return $match.Value }
    return $null
}

# In-game broadcast is not yet supported by the Dune Awakening battlegroup.
# This function is a placeholder for when Funcom adds an official broadcast/RCON interface.
function Send-InGameWarning {
    param([string]$Ip, [int]$MinutesRemaining)
    Write-Host "In-game warning skipped ($MinutesRemaining min) — no broadcast interface available yet."
}

# ------------------------------------------------------------------------------
# Pre-flight checks
# ------------------------------------------------------------------------------

try {
    if (-not (Test-Path $sshKeyPath)) {
        throw "SSH key not found at '$sshKeyPath'. Run initial setup first."
    }

    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if (-not $vm) { throw "VM '$vmName' does not exist." }
    if ($vm.State -ne 'Running') { throw "VM '$vmName' is not running (state: $($vm.State))." }

    $ip = Get-VmIp
    if (-not $ip) { throw "Could not resolve IP for VM '$vmName'." }

    Write-Host "VM '$vmName' running at $ip."

    # --------------------------------------------------------------------------
    # Update check
    # --------------------------------------------------------------------------

    if ($enableUpdateCheck) {
        Write-Host "Checking for server update..."
        $versionBefore = Get-ServerVersion -Ip $ip
        $displayVersionBefore = 'unknown'
        if ($versionBefore) { $displayVersionBefore = $versionBefore }
        Write-Host "Current version: $displayVersionBefore"

        $updateResult = Invoke-SshCommand -Ip $ip -Command "/home/dune/.dune/bin/battlegroup update"
        Write-Host "Update output: $($updateResult.Output)"

        $versionAfter = Get-ServerVersion -Ip $ip

        if ($versionBefore -and $versionAfter -and ($versionBefore -ne $versionAfter)) {
            Write-Host "Update applied: $versionBefore -> $versionAfter"
            Send-DiscordNotification `
                -Message "**Dune Awakening** - Server updated from ``$versionBefore`` to ``$versionAfter``." `
                -Color 3447003
        } else {
            $displayVersion = 'unknown'
            if ($versionAfter) { $displayVersion = $versionAfter }
            Write-Host "Server is up to date. Version: $displayVersion"
        }
    }

    # --------------------------------------------------------------------------
    # Pre-restart warnings
    # --------------------------------------------------------------------------

    if ($enableRestartWarnings -and $warningMinutes.Count -gt 0) {
        $sortedWarnings = $warningMinutes | Sort-Object -Descending
        $totalLeadMinutes = $sortedWarnings[0]
        $elapsed = 0

        foreach ($minutes in $sortedWarnings) {
            $waitSeconds = ($totalLeadMinutes - $minutes - $elapsed) * 60
            if ($waitSeconds -gt 0) {
                Write-Host "Waiting $waitSeconds seconds..."
                Start-Sleep -Seconds $waitSeconds
            }
            $elapsed = $totalLeadMinutes - $minutes

            Write-Host "Sending $minutes-minute warning..."
            $warnSuffix = 'minutes'
            if ($minutes -eq 1) { $warnSuffix = 'minute' }
            Send-DiscordNotification `
                -Message "**Dune Awakening** - Server restarting in **$minutes $warnSuffix**. Find a safe location!" `
                -Color 16744272
            Send-InGameWarning -Ip $ip -MinutesRemaining $minutes
        }

        # Wait out the final warning period
        $finalWait = ($sortedWarnings | Select-Object -Last 1) * 60
        if ($finalWait -gt 0) {
            Write-Host "Waiting $finalWait seconds before restart..."
            Start-Sleep -Seconds $finalWait
        }
    }

    # --------------------------------------------------------------------------
    # Restart
    # --------------------------------------------------------------------------

    Write-Host "Restarting battlegroup..."
    Send-DiscordNotification -Message "**Dune Awakening** - Server is restarting now..." -Color 16776960

    $restartResult = Invoke-SshCommand -Ip $ip -Command "/home/dune/.dune/bin/battlegroup restart"
    if ($restartResult.ExitCode -ne 0) {
        throw "Restart command failed (exit code $($restartResult.ExitCode)): $($restartResult.Output)"
    }

    Write-Host "Battlegroup restarted successfully."
    Send-DiscordNotification -Message "**Dune Awakening** - Server has restarted successfully." -Color 3066993

} catch {
    Write-Warning "Scheduled restart failed: $_"
    Send-DiscordNotification -Message "**Dune Awakening** - Scheduled restart failed: $_" -Color 15158332
    exit 1
} finally {
    Stop-Transcript | Out-Null
}
