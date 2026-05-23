# Dune Awakening Server — Scheduled Restart & Discord Notifications

Automatically restart your Dune Awakening dedicated server battlegroup on a schedule, with Discord notifications on every restart attempt.

Built for servers running on **Windows Hyper-V** with a **Linux VM** managed by the official Dune Awakening server tools.

---

## What This Does

- Restarts your battlegroup every 4 hours (or any schedule you choose)
- Sends a Discord notification when the restart begins
- Sends a Discord notification when the restart completes successfully
- Sends a Discord notification if the restart fails, with the reason
- Logs every run to a local file for troubleshooting

---

## Requirements

- Windows host with **Hyper-V** enabled
- Dune Awakening dedicated server installed and working via the official `.bat` management tool
- The VM (`dune-awakening`) must already be set up and reachable via SSH
- PowerShell 5.1 or later (comes with Windows 10/11)
- A Discord server and channel for notifications (optional but recommended)

---

## Setup Guide

### Step 1 — Download the files

Download or clone this repository and place the files alongside your existing `battlegroup-management` folder. Your folder structure should look like this:

```
your-server-folder\
    battlegroup.bat
    register-task.ps1              <-- new
    battlegroup-management\
        battlegroup.ps1
        battlegroup-internal.ps1   (if present)
        initial-setup.ps1
        vm-utilities.ps1
        scheduled-restart.ps1      <-- new
```

---

### Step 2 — Create a Discord Webhook (optional)

Skip this step if you don't want Discord notifications.

1. In Discord, right-click your notification channel and select **Edit Channel**
2. Go to **Integrations** → **Webhooks** → **New Webhook**
3. Give it a name (e.g. `Server Status`) and click **Copy Webhook URL**
4. Keep this URL handy for the next step

---

### Step 3 — Configure the restart script

Open `battlegroup-management\scheduled-restart.ps1` in Notepad or any text editor.

Find the `CONFIGURATION` section near the top and fill in your webhook URL:

```powershell
$webhookUrl = "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL_HERE"
```

If you don't want Discord notifications, leave `$webhookUrl` as an empty string `""`.

The `$vmName` is already set to `dune-awakening`. Only change it if your VM has a different name.

---

### Step 4 — Register the scheduled task

Open PowerShell **as Administrator** (right-click → Run as administrator) and run:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\path\to\your\server\register-task.ps1"
```

Replace the path with wherever you placed the files.

You will be prompted for your Windows password — this is required for Task Scheduler to run the script automatically in the background.

---

### Step 5 — Test it

1. Open **Task Scheduler** (search for it in the Start menu)
2. Find the task named `DuneAwakening-Restart`
3. Right-click it and select **Run**
4. Check your Discord channel — you should see a "restarting" message, followed shortly by "restarted successfully"

---

## Changing the Schedule

The default schedule restarts every **4 hours starting at 4:00 AM**, giving you restarts at:

```
4:00 AM  |  8:00 AM  |  12:00 PM  |  4:00 PM  |  8:00 PM  |  12:00 AM
```

To change the schedule:

1. Edit the `-At "04:00AM"` and `-Hours 4` values in `register-task.ps1`
2. Open an elevated PowerShell and re-run `register-task.ps1` — it will ask if you want to replace the existing task

---

## Logs

Every scheduled run is logged to:

```
battlegroup-management\logs\scheduled-restart-YYYY-MM-DD.log
```

Check here first if a restart appears to have failed.

---

## Troubleshooting

**Task runs but battlegroup doesn't restart**
- Open the log file for that day and check for errors
- Make sure the VM is running before the task fires
- Verify your SSH key is still valid by running `battlegroup.bat` and testing the connection manually

**Discord messages not appearing**
- Double-check the webhook URL in `scheduled-restart.ps1`
- Make sure the channel still has the webhook (it may have been deleted)

**Task Scheduler shows Last Run Result: 0x1**
- This means the script ran but hit an error — check the log file

**SSH key not found error**
- The default key path assumes your Windows username is the account that ran initial setup
- If the key is somewhere else, update `$sshKeyPath` in `scheduled-restart.ps1`

---

## Security Notes

- The Discord webhook URL in `scheduled-restart.ps1` is stored in plaintext. Do not commit this file to a public repository with your webhook URL in it. Add your webhook URL after downloading.
- The SSH private key at `AppData\Local\DuneAwakeningServer\sshKey` is restricted to your user account by the initial setup script. Do not share or copy it to less-restricted locations.
- The scheduled task runs with elevated privileges. Ensure the script file itself is only writable by administrators.

---

## Contributing

Pull requests welcome. Please test against a running Dune Awakening server before submitting.

---

## License

MIT License. Not affiliated with Funcom or the official Dune Awakening server tools.
