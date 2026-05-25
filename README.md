# Dune Awakening Server — Scheduler, Watchdog & Discord Notifications

Automated server management for Dune Awakening self-hosted dedicated servers running on Windows Hyper-V.

---

## Features

- **Scheduled restarts** every 4 hours (or any interval you choose)
- **Pre-restart warnings** — notifies players on Discord before every restart
- **Crash watchdog** — checks server health every 5 minutes, auto-restarts on crash
- **Discord notifications** for restarts, crashes, and recoveries
- **Toggleable auto-restart** — enable/disable crash recovery without touching Task Scheduler
- **Daily logs** for every scheduled run and watchdog check

---

## Known Limitations

| Feature | Status | Notes |
|---|---|---|
| Auto update check | Disabled | `battlegroup update` causes a Steam symlink error on the Linux VM in the current server release. Set `$enableUpdateCheck = $true` at your own risk once Funcom resolves this. |
| In-game restart warnings | Disabled | No broadcast or RCON interface is exposed by the battlegroup in the current release. Discord warnings work reliably. Both features are stubbed and ready to enable when official support lands. |

---

## Requirements

- Windows host with **Hyper-V** enabled (Windows 10/11 Pro)
- Dune Awakening dedicated server installed via the official setup tools (`battlegroup.bat`)
- The VM (`dune-awakening`) already set up and reachable via SSH
- PowerShell 5.1 or later (included with Windows 10/11)
- A Discord webhook URL (optional but recommended)

---

## File Overview

```
your-server-folder\
    battlegroup.bat
    register-task.ps1              — registers the 4-hour restart schedule
    register-watchdog.ps1          — registers the 5-minute crash watchdog
    battlegroup-management\
        battlegroup.ps1            — official management script (unchanged)
        scheduled-restart.ps1      — main script: restarts, warnings, updates
        scheduled-watchdog.ps1     — watchdog: crash detection and recovery
```

---

## Setup Guide

### Step 1 — Download the files

Place the new files alongside your existing `battlegroup-management` folder as shown above.

---

### Step 2 — Create a Discord Webhook (optional)

Skip this step if you don't want Discord notifications.

1. In Discord, right-click your notification channel → **Edit Channel**
2. Go to **Integrations** → **Webhooks** → **New Webhook**
3. Name it (e.g. `Server Status`) and click **Copy Webhook URL**

---

### Step 3 — Configure the script

Open `battlegroup-management\scheduled-restart.ps1` in Notepad or VS Code and fill in the `CONFIGURATION` section:

```powershell
$vmName     = 'dune-awakening'          # Your VM name — leave as-is unless changed
$sshKeyPath = "C:\Users\YourName\..."   # Auto-fills your Windows username
$webhookUrl = "https://discord.com/..."  # Paste your webhook URL here

$enableRestartWarnings = $true          # Toggle pre-restart Discord warnings
$warningMinutes        = @(15, 5, 1)   # Warn at 15, 5, and 1 minute before restart

$enableUpdateCheck  = $false           # Disabled — see Known Limitations above
$enableCrashRestart = $true            # Auto-restart on crash (used by watchdog)
```

---

### Step 4 — Register the scheduled restart task

Open PowerShell **as Administrator** and run:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\path\to\register-task.ps1"
```

This creates a task that restarts the server every 4 hours starting at 4:00 AM.

---

### Step 5 — Register the crash watchdog task

In the same elevated PowerShell window:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\path\to\register-watchdog.ps1"
```

This creates a task that checks battlegroup health every 5 minutes.

---

### Step 6 — Test

1. Open **Task Scheduler** and find `DuneAwakening-Restart`
2. Right-click → **Run**
3. Watch your Discord channel — you should see warning messages counting down, then a restart notification and a success confirmation

---

## Toggling Auto-Restart on Crash

Open `battlegroup-management\scheduled-restart.ps1` and change:

```powershell
$enableCrashRestart = $true    # enabled
$enableCrashRestart = $false   # disabled
```

No need to re-register anything — the watchdog reads this value on every run.

---

## Changing the Restart Schedule

The default schedule restarts every **4 hours starting at 4:00 AM**:

```
4:00 AM  |  8:00 AM  |  12:00 PM  |  4:00 PM  |  8:00 PM  |  12:00 AM
```

To change it, edit the `-At` and `-Hours` values in `register-task.ps1`, then re-run it. It will ask before replacing the existing task.

---

## Discord Notification Reference

| Notification | Color | Trigger |
|---|---|---|
| Restarting in X minutes | 🟠 Orange | Pre-restart warning |
| Server restarting now | 🟡 Yellow | Restart begins |
| Restart successful | 🟢 Green | Restart completed |
| Crash detected | 🔴 Red | Watchdog found server down |
| Recovery restart issued | 🟡 Yellow | Watchdog issued restart |
| Server recovered | 🟢 Green | Server healthy after crash |
| Any failure | 🔴 Red | Any script error |

---

## Logs

All logs are written to the `logs\` folder next to your scripts:

- `scheduled-restart-YYYY-MM-DD.log` — one file per day for restart runs
- `watchdog-YYYY-MM-DD.log` — one file per day for watchdog checks
- `watchdog-state.json` — tracks crash state between watchdog runs (do not edit manually)

---

## Troubleshooting

**Restart fails with a Steam symlink error**
The update check is likely still enabled. Set `$enableUpdateCheck = $false` in `scheduled-restart.ps1`.

**Watchdog keeps restarting during a scheduled restart**
The watchdog requires 2 consecutive failed checks before acting. A normal restart should complete within one 5-minute window. If overlap is still an issue, increase the watchdog interval in `register-watchdog.ps1`.

**Discord messages not appearing**
Check the webhook URL in `scheduled-restart.ps1`. Verify the webhook still exists under **Edit Channel → Integrations → Webhooks**.

**Task Scheduler shows Last Run Result: 0x1**
The script hit an error — open the log file for that day for details.

**SSH key not found error**
The default key path uses your Windows username. If you ran initial setup under a different account, update `$sshKeyPath` in `scheduled-restart.ps1` to the correct path.

---

## Security Notes

- Your Discord webhook URL is stored in plaintext in `scheduled-restart.ps1`. Do not commit the configured file to a public repository — it is listed in `.gitignore` by default. Only the `.example.ps1` template (with no URL) should be committed.
- The SSH key is restricted to your user account by the Dune Awakening initial setup.
- Scheduled tasks run with elevated privileges. Ensure the script folder is only writable by administrators.

---

## Contributing

Pull requests welcome. Please test against a running Dune Awakening server before submitting.

Issues and feature requests can be filed via GitHub Issues.

---

## License

MIT License. Not affiliated with Funcom or the official Dune Awakening server tools.
