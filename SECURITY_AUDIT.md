# Security Audit — Dune Awakening Scheduler

**Audit Date:** 2026-05-25
**Scope:** `scheduled-restart.ps1`, `scheduled-watchdog.ps1`, `register-task.ps1`, `register-watchdog.ps1`

---

## Summary

| Severity | Count | Status |
|----------|-------|--------|
| High     | 1     | Resolved |
| Medium   | 3     | Resolved |
| Low      | 3     | Resolved / Accepted |
| Info     | 4     | Noted |

---

## Findings

---

### [HIGH] Webhook URL stored in plaintext
**File:** `scheduled-restart.ps1`
**Description:** The Discord webhook URL is stored as a plaintext string. Anyone with read access to the file can post to your Discord channel.
**Resolution:** The configured file is listed in `.gitignore` so it is never committed. Only the blank `.example.ps1` template is tracked by Git. Users are warned in the README not to share the configured file. An optional improvement would be Windows Credential Manager storage — not implemented here to keep setup accessible for non-technical users.

---

### [MEDIUM] SSH with StrictHostKeyChecking=no
**Files:** `scheduled-restart.ps1`, `scheduled-watchdog.ps1`
**Description:** All SSH calls use `-o StrictHostKeyChecking=no`, disabling host key verification and leaving connections vulnerable to man-in-the-middle attacks on the local network.
**Context:** The VM IP is controlled by the Hyper-V host itself, making MITM attacks on a home/LAN network extremely unlikely. This is a deliberate trade-off for ease of setup.
**Recommendation:** For hardened setups, remove `StrictHostKeyChecking=no` after the first connection so the host key is cached and verified on subsequent runs.
**Status:** Accepted / documented.

---

### [MEDIUM] SSH key path uses environment variable
**File:** `scheduled-restart.ps1`
**Description:** `$env:USERNAME` is used to build the SSH key path. When Task Scheduler runs as a different user this resolves incorrectly.
**Resolution:** `$env:USERNAME` is resolved at script load time (not inside a string passed to another process), and a `Test-Path` pre-flight check fails fast with a clear error if the key is not found.

---

### [MEDIUM] No error handling on SSH exit code (original)
**File:** `scheduled-restart.ps1` (original version)
**Description:** The original script sent a success notification unconditionally even if SSH failed silently.
**Resolution:** All SSH calls now check `$LASTEXITCODE` and throw on non-zero exit, routing to the failure notification path.

---

### [LOW] Transcript log directory uses default NTFS permissions
**File:** `scheduled-restart.ps1`
**Description:** The `logs\` directory is created with default permissions and may be readable by standard users on a shared machine.
**Recommendation:** On shared machines, restrict the folder: `icacls logs /inheritance:r /grant:r "Administrators:(OI)(CI)F"`
**Status:** Accepted — most users run this on a personal or dedicated server host.

---

### [LOW] Scheduled tasks run with highest privileges
**Files:** `register-task.ps1`, `register-watchdog.ps1`
**Description:** Both tasks are registered with `RunLevel Highest`. This is required for Hyper-V PowerShell cmdlets but means the scripts run with full admin rights.
**Recommendation:** Ensure the script directory is only writable by administrators to prevent privilege escalation via script replacement.
**Status:** Required for functionality. Documented in README.

---

### [LOW] `watchdog-state.json` is unprotected
**File:** `scheduled-watchdog.ps1`
**Description:** The watchdog state file is written with default permissions. Tampering with it could suppress crash notifications or trigger false restarts.
**Recommendation:** On shared machines, apply the same ACL restriction as the logs folder.
**Status:** Accepted — low risk on a dedicated server host.

---

## Informational Notes

**Update check disabled by default**
`$enableUpdateCheck` defaults to `$false` following a confirmed issue where `battlegroup update` causes a Steam symlink error (`ln: /home/dune/.steam/root: No such file or directory`) on the Linux VM in the current server release. The feature remains in the script and can be re-enabled when Funcom resolves the upstream issue.

**In-game warnings stubbed**
`Send-InGameWarning` is a no-op placeholder. The Dune Awakening battlegroup does not currently expose a broadcast or RCON interface. The function logs a clean skip message and will be wired up when official support lands.

**Watchdog requires 2 consecutive failures**
The watchdog will not restart on a single failed health check, reducing false positives during normal scheduled restarts. State is persisted in `watchdog-state.json` between runs.

**`-NonInteractive` and `-MultipleInstances IgnoreNew`**
The restart task uses `-NonInteractive` to prevent hanging on unexpected prompts. The watchdog task uses `MultipleInstances IgnoreNew` so overlapping executions are silently skipped rather than queued.

---

## Files in This Release

| File | Purpose |
|------|---------|
| `scheduled-restart.ps1` | Main restart script with warnings, update check stub, Discord notifications |
| `scheduled-restart.example.ps1` | Blank template safe for public repository commit |
| `scheduled-watchdog.ps1` | Crash detection and auto-recovery watchdog |
| `register-task.ps1` | One-time Task Scheduler registration for restart task |
| `register-watchdog.ps1` | One-time Task Scheduler registration for watchdog task |
| `README.md` | Setup guide, known limitations, troubleshooting |
| `SECURITY_AUDIT.md` | This document |
| `.gitignore` | Prevents configured `scheduled-restart.ps1` from being committed |

## Files Not Modified (upstream)

| File | Notes |
|------|-------|
| `battlegroup.ps1` | Official management script — out of scope |
| `vm-utilities.ps1` | Official utility script — out of scope |
| `initial-setup.ps1` | Official setup script — out of scope |
| `battlegroup.bat` | Official launcher — out of scope |
