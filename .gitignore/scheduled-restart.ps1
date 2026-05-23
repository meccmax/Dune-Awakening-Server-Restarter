#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Scheduled battlegroup restart script for Dune Awakening dedicated server.

.DESCRIPTION
    Connects to the Dune Awakening Linux VM via SSH and issues a battlegroup restart command.
    Sends Discord webhook notifications on start, success, and failure.

.NOTES
    Intended to be run by Windows Task Scheduler.
    Configure CONFIGURATION section below before use.
#>

# ==============================================================================
# CONFIGURATION — edit these values before use
# ==============================================================================

$vmName     = 'dune-awakening'
$sshKeyPath = "C:\Users\$env:USERNAME\AppData\Local\DuneAwakeningServer\sshKey"
$webhookUrl = ""   # Paste your Discord webhook URL here

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

try {
    # Validate SSH key exists
    if (-not (Test-Path $sshKeyPath)) {
        throw "SSH key not found at '$sshKeyPath'. Run the initial setup first."
    }

    # Resolve VM IP
    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if (-not $vm) {
        throw "VM '$vmName' does not exist."
    }
    if ($vm.State -ne 'Running') {
        throw "VM '$vmName' is not running (state: $($vm.State))."
    }

    $ip = (Get-VMNetworkAdapter -VMName $vmName).IPAddresses |
          Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } |
          Select-Object -First 1

    if (-not $ip) {
        throw "Could not resolve IP for VM '$vmName'."
    }

    Write-Host "Restarting battlegroup on $vmName ($ip)..."
    Send-DiscordNotification -Message "**Dune Awakening** - Server is restarting..." -Color 16776960

    & ssh -o StrictHostKeyChecking=no -o LogLevel=QUIET -o IdentitiesOnly=yes `
          -i "$sshKeyPath" "dune@$ip" "/home/dune/.dune/bin/battlegroup restart"

    if ($LASTEXITCODE -ne 0) {
        throw "SSH command exited with code $LASTEXITCODE."
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
