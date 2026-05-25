#Requires -RunAsAdministrator

$mainScript = Join-Path $PSScriptRoot "scheduled-restart.ps1"
if (-not (Test-Path $mainScript)) {
    Write-Error "Could not find scheduled-restart.ps1 at: $mainScript"
    exit 1
}

$configContent = Get-Content $mainScript -Raw

function Get-ConfigValue {
    param([string]$Content, [string]$VarName)
    $match = [regex]::Match($Content, "(?m)^\`$$VarName\s*=\s*(.+)$")
    if ($match.Success) { return $match.Groups[1].Value.Trim().Trim('"').Trim("'") }
    return $null
}

$vmName             = Get-ConfigValue -Content $configContent -VarName 'vmName'
$sshKeyPath         = Get-ConfigValue -Content $configContent -VarName 'sshKeyPath'
$webhookUrl         = Get-ConfigValue -Content $configContent -VarName 'webhookUrl'
$crashRestartValue  = Get-ConfigValue -Content $configContent -VarName 'enableCrashRestart'
$enableCrashRestart = ($crashRestartValue -eq '$true')

$sshKeyPath = [System.Environment]::ExpandEnvironmentVariables($sshKeyPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$logDir    = Join-Path $PSScriptRoot "..\logs"
$logFile   = Join-Path $logDir "watchdog-$(Get-Date -Format 'yyyy-MM-dd').log"
$stateFile = Join-Path $logDir "watchdog-state.json"
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

function Get-WatchdogState {
    if (Test-Path $stateFile) {
        try { return Get-Content $stateFile -Raw | ConvertFrom-Json }
        catch { }
    }
    return [pscustomobject]@{ lastCrashNotified = $null; consecutiveFailures = 0 }
}

function Save-WatchdogState {
    param($State)
    $State | ConvertTo-Json | Set-Content -Path $stateFile -Force
}

try {
    $state = Get-WatchdogState

    if (-not $enableCrashRestart) {
        Write-Host "$(Get-Date -Format 'HH:mm:ss') Watchdog running - auto-restart is DISABLED."
        Stop-Transcript | Out-Null
        exit 0
    }

    Write-Host "$(Get-Date -Format 'HH:mm:ss') Checking battlegroup health..."

    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if (-not $vm -or $vm.State -ne 'Running') {
        Write-Warning "VM '$vmName' is not running. Skipping check."
        Stop-Transcript | Out-Null
        exit 0
    }

    $ip = (Get-VMNetworkAdapter -VMName $vmName).IPAddresses |
          Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } |
          Select-Object -First 1

    if (-not $ip) {
        Write-Warning "Could not resolve VM IP. Skipping check."
        Stop-Transcript | Out-Null
        exit 0
    }

    $statusOutput = & ssh -o StrictHostKeyChecking=no -o LogLevel=QUIET -o ConnectTimeout=10 `
                          -o IdentitiesOnly=yes -i $sshKeyPath "dune@$ip" `
                          "/home/dune/.dune/bin/battlegroup status" 2>&1
    $statusText  = $statusOutput | Out-String
    $sshExitCode = $LASTEXITCODE
    $isHealthy   = ($sshExitCode -eq 0) -and ($statusText -match 'Running')

    if ($isHealthy) {
        Write-Host "$(Get-Date -Format 'HH:mm:ss') Battlegroup is healthy."
        if ($state.consecutiveFailures -gt 0) {
            Write-Host "Recovered after $($state.consecutiveFailures) failed check(s)."
            Send-DiscordNotification -Message "**Dune Awakening** - Server has recovered and is running normally." -Color 3066993
        }
        $state.consecutiveFailures = 0
        $state.lastCrashNotified   = $null
        Save-WatchdogState -State $state
    } else {
        $state.consecutiveFailures++
        Write-Warning "Battlegroup appears down. Consecutive failures: $($state.consecutiveFailures)"

        if ($state.consecutiveFailures -lt 2) {
            Write-Host "Waiting for confirmation on next check before restarting..."
            Save-WatchdogState -State $state
            Stop-Transcript | Out-Null
            exit 0
        }

        if (-not $state.lastCrashNotified) {
            Send-DiscordNotification -Message "**Dune Awakening** - Server appears to have crashed. Attempting automatic restart..." -Color 15158332
            $state.lastCrashNotified = (Get-Date -Format 'o')
        }

        Write-Host "Attempting automatic restart..."
        $restartOutput = & ssh -o StrictHostKeyChecking=no -o LogLevel=QUIET -o ConnectTimeout=15 `
                               -o IdentitiesOnly=yes -i $sshKeyPath "dune@$ip" `
                               "/home/dune/.dune/bin/battlegroup restart" 2>&1
        $restartCode = $LASTEXITCODE

        if ($restartCode -eq 0) {
            Write-Host "Restart command issued successfully."
            Send-DiscordNotification -Message "**Dune Awakening** - Crash recovery restart issued. Monitoring for recovery..." -Color 16776960
        } else {
            $restartText = $restartOutput | Out-String
            Write-Warning "Restart command failed (exit $restartCode): $restartText"
            Send-DiscordNotification -Message "**Dune Awakening** - Crash recovery restart FAILED. Manual intervention may be required." -Color 15158332
        }

        Save-WatchdogState -State $state
    }

} catch {
    Write-Warning "Watchdog error: $_"
} finally {
    Stop-Transcript | Out-Null
}
