# Dune Awakening - Server Scheduler & Discord Notifications

Automated server management for Dune Awakening self-hosted dedicated servers running on Windows Hyper-V with a Linux VM.

Built and maintained by the Misfit Mercenaries community.

---

## Features

- Scheduled restarts every 4 hours
- Pre-restart warnings posted to Discord
- Discord notifications for restarts, crashes, and recoveries
- Crash watchdog checks server health every 5 minutes and auto-restarts on crash
- Auto-restart can be toggled on or off without touching Task Scheduler
- Daily log files for every run

---

## Known Limitations

| Feature | Status | Notes |
|---|---|---|
| Auto update check | Disabled by default | battlegroup update causes a Steam symlink error in the current server release. Set $enableUpdateCheck = $true to try it once Funcom fixes this. |
| In-game restart warnings | Not available | The battlegroup does not expose a broadcast or RCON interface in the current release. Discord warnings work reliably. This will be wired up when official support is added. |

---

## Requirements

- Windows 10 or 11 Pro with Hyper-V enabled
- Dune Awakening dedicated server installed via the official battlegroup.bat setup
- The dune-awakening VM already running and reachable via SSH
- PowerShell 5.1 or later (included with Windows 10 and 11)
- A Discord webhook URL (optional but recommended)

---

## File Structure

Place the new files alongside your existing battlegroup-management folder:

```
your-server-folder\
    battlegroup.bat
    register-task.ps1
    register-watchdog.ps1
    battlegroup-management\
        battlegroup.ps1
        scheduled-restart.ps1
        scheduled-watchdog.ps1
```

---

## Setup Guide

### Step 1 - Download

Download this repository and place the files as shown above.

---

### Step 2 - Create a Discord Webhook

Skip this step if you do not want Discord notifications.

1. In Discord, right-click your notification channel and select Edit Channel
2. Go to Integrations, then Webhooks, then New Webhook
3. Give it a name such as Server Status and click Copy Webhook URL
4. Keep the URL handy for the next step

---

### Step 3 - Configure the Script

Open battlegroup-management\scheduled-restart.ps1 in Notepad and fill in the configuration section at the top:

```powershell
$vmName     = 'dune-awakening'
$sshKeyPath = "C:\Users\YourWindowsUsername\AppData\Local\DuneAwakeningServer\sshKey"
$webhookUrl = "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL_HERE"

$enableRestartWarnings = $true
$warningMinutes        = @(15, 5, 1)

$enableUpdateCheck  = $false
$enableCrashRestart = $true
```

Replace YourWindowsUsername with your actual Windows username.
Replace the webhook URL with the one you copied from Discord.

---

### Step 4 - Register the Restart Task

Open PowerShell as Administrator (right-click, Run as administrator) and run:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\path\to\register-task.ps1"
```

Replace the path with wherever you placed the files.
You will be prompted for your Windows password to store with the task.

---

### Step 5 - Register the Watchdog Task

In the same elevated PowerShell window run:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\path\to\register-watchdog.ps1"
```

---

### Step 6 - Test

1. Open Task Scheduler from the Start menu
2. Find the task named DuneAwakening-Restart
3. Right-click it and select Run
4. Watch your Discord channel for the warning and restart notifications

---

## Configuration Options

All options are set at the top of scheduled-restart.ps1.

| Option | Default | Description |
|---|---|---|
| $vmName | dune-awakening | Name of your Hyper-V VM |
| $sshKeyPath | Auto | Path to your SSH private key |
| $webhookUrl | Empty | Discord webhook URL |
| $enableRestartWarnings | true | Send Discord warnings before restart |
| $warningMinutes | 15, 5, 1 | How many minutes before restart to warn |
| $enableUpdateCheck | false | Check for and apply updates before restart |
| $enableCrashRestart | true | Auto-restart on crash via watchdog |

---

## Toggling Auto-Restart on Crash

Open scheduled-restart.ps1 and change:

```powershell
$enableCrashRestart = $true    # enabled
$enableCrashRestart = $false   # disabled
```

No need to re-register the watchdog task. It reads this value on every run.

---

## Restart Schedule

The default schedule restarts every 4 hours starting at 4:00 AM:

```
4:00 AM  |  8:00 AM  |  12:00 PM  |  4:00 PM  |  8:00 PM  |  12:00 AM
```

To change the schedule, edit the -At and -Hours values in register-task.ps1 and re-run it. It will ask before replacing the existing task.

---

## Discord Notifications

| Message | Color | When |
|---|---|---|
| Server restarting in X minutes | Orange | Pre-restart warning |
| Server is restarting now | Yellow | Restart begins |
| Server restarted successfully | Green | Restart complete |
| Server appears to have crashed | Red | Watchdog detected crash |
| Crash recovery restart issued | Yellow | Watchdog issued restart |
| Server has recovered | Green | Server healthy again |
| Scheduled restart failed | Red | Any script error |

---

## Logs

Logs are written to a logs folder next to your scripts:

- scheduled-restart-YYYY-MM-DD.log - one file per day for restart runs
- watchdog-YYYY-MM-DD.log - one file per day for watchdog checks
- watchdog-state.json - tracks crash state between runs, do not edit manually

To view the current log run this in PowerShell:

```powershell
Get-Content "C:\path\to\logs\scheduled-restart-$(Get-Date -Format 'yyyy-MM-dd').log" -Raw
```

---

## Troubleshooting

**Task Scheduler shows Last Run Result 0x1**
Open the log file for that day and check the bottom for the error message.

**Restart fails with a Steam symlink error**
The update check is enabled. Set $enableUpdateCheck = $false in scheduled-restart.ps1.

**No Discord messages appearing**
Check the webhook URL in scheduled-restart.ps1. Verify the webhook still exists under Edit Channel, Integrations, Webhooks in Discord.

**SSH key not found error**
Update $sshKeyPath in scheduled-restart.ps1 to the full path where your SSH key is stored.

**Watchdog keeps restarting the server during a scheduled restart**
The watchdog requires 2 consecutive failed health checks before acting. A normal restart should complete within one 5-minute window. If this keeps happening, increase the watchdog interval in register-watchdog.ps1.

---

## Security

- Your Discord webhook URL is stored in plaintext in scheduled-restart.ps1. Do not upload that file to a public repository. Only the example template should be committed.
- The SSH key is restricted to your Windows user account by the Dune Awakening initial setup.
- Both scheduled tasks run with elevated privileges. Make sure the script folder is only writable by administrators.

---

## Contributing

Pull requests are welcome. Please test against a running Dune Awakening server before submitting.

---

## License

MIT License. Not affiliated with Funcom or the official Dune Awakening server tools.
