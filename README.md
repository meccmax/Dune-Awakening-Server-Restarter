# Dune Awakening Server — Scheduler, Watchdog & Discord Notifications

Automated server management for Dune Awakening self-hosted dedicated servers running on Windows Hyper-V.

---

## Features

- **Scheduled restarts** every 4 hours (or any interval you choose)
- **Pre-restart warnings** — notifies players in Discord and attempts in-game broadcast before every restart
- **Update check** — checks for and applies server updates before each restart
- **Crash watchdog** — checks server health every 5 minutes, auto-restarts on crash
- **Discord notifications** for restarts, updates, crashes, and recoveries
- **Toggleable auto-restart** — enable/disable crash recovery without touching Task Scheduler
- **Daily logs** for every scheduled run and watchdog check

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

1. In Discord, right-click your notification channel → **Edit Channel**
2. Go to **Integrations** → **Webhooks** → **New Webhook**
3. Name it (e.g. `Server Status`) and click **Copy Webhook URL**

---

### Step 3 — Configure the script

Open `battlegroup-management\scheduled-restart.ps1` in Notepad or VS Code and edit the `CONFIGURATION` section:

```powershell
$vmName     = 'dune-awakening'          # Your VM name — leave as-is unless you changed it
$sshKeyPath = "C:\Users\YourName\..."   # Path to your SSH key — auto-fills your username
$webhookUrl = "https://discord.com/..."  # Paste your webhook URL here

$enableRestartWarnings = $true          # Toggle pre-restart warnings
$warningMinutes        = @(15, 5, 1)   # Warn at 15, 5, and 1 minute before restart

$enableUpdateCheck  = $true            # Check for and apply updates before each restart
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
3. Watch your Discord channel — you should see warning messages counting down, then restart and success notifications

---

## Toggling Auto-Restart on Crash

Open `battlegroup-management\scheduled-restart.ps1` and change:

```powershell
$enableCrashRestart = $true    # enabled
$enableCrashRestart = $false   # disabled
```

No need to re-register anything — the watchdog reads this value every time it runs.

---

## Changing the Restart Schedule

The default schedule restarts every **4 hours starting at 4:00 AM**:

```
4:00 AM  |  8:00 AM  |  12:00 PM  |  4:00 PM  |  8:00 PM  |  12:00 AM
```

To change it, edit the `-At` and `-Hours` values in `register-task.ps1`, then re-run it (it will ask before replacing the existing task).

---

## Discord Notification Reference

| Notification | Color | Trigger |
|---|---|---|
| Restarting in X minutes | 🟠 Orange | Pre-restart warning |
| Server updated | 🔵 Blue | Update applied before restart |
| Server restarting now | 🟡 Yellow | Restart begins |
| Restart successful | 🟢 Green | Restart completed |
| Crash detected | 🔴 Red | Watchdog found server down |
| Recovery restart issued | 🟡 Yellow | Watchdog issued restart |
| Server recovered | 🟢 Green | Server healthy after crash |
| Any failure | 🔴 Red | Any script error |

---

## Logs

All logs are written to the `logs\` folder:

- `scheduled-restart-YYYY-MM-DD.log` — one file per day for restart runs
- `watchdog-YYYY-MM-DD.log` — one file per day for watchdog checks
- `watchdog-state.json` — tracks crash state between watchdog runs (do not edit manually)

---

## Troubleshooting

**Warnings fire but restart doesn't happen**
Check the log — if the update step times out it may be holding up the process. Set `$enableUpdateCheck = $false` temporarily to isolate.

**Watchdog keeps restarting the server during a scheduled restart**
The watchdog requires 2 consecutive failed checks before acting, and a scheduled restart should complete within one 5-minute window. If overlap is a problem, consider extending the watchdog interval in `register-watchdog.ps1`.

**In-game warning not appearing**
In-game broadcast uses a best-effort pod console method. Whether players see the message depends on your battlegroup version and whether the pods expose a console interface. Discord warnings are always reliable.

**Task Scheduler shows Last Run Result: 0x1**
The script hit an error — open the log file for that day for details.

---

## Security Notes

- Your Discord webhook URL is stored in plaintext in `scheduled-restart.ps1`. Do not commit this file to a public repository. Add it to `.gitignore` (already included).
- The SSH key is restricted to your user account by the Dune Awakening initial setup.
- The scheduled tasks run with elevated privileges — ensure the script folder is only writable by administrators.

---

## License

MIT License. Not affiliated with Funcom or the official Dune Awakening server tools.
