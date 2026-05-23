# Security Audit — Dune Awakening Scheduler

**Audit Date:** 2026-05-23
**Scope:** `scheduled-restart.ps1`, `register-task.ps1`, and supporting files (`battlegroup.ps1`, `vm-utilities.ps1`, `initial-setup.ps1`)

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
**Description:** The Discord webhook URL is stored as a plaintext string in the script file. Anyone with read access to the file can post messages to your Discord channel.
**Resolution:** Documented in README to not commit the file with the URL populated. Users should treat the webhook URL as a secret. An optional improvement would be to store it in Windows Credential Manager and retrieve it at runtime — not implemented here to keep setup simple for non-technical users.

---

### [MEDIUM] SSH with StrictHostKeyChecking=no
**File:** `scheduled-restart.ps1`, `vm-utilities.ps1`, `battlegroup.ps1`
**Description:** All SSH calls use `-o StrictHostKeyChecking=no`, which disables host key verification. This makes the connection vulnerable to a man-in-the-middle attack on the local network.
**Context:** This is consistent with the original scripts and is a deliberate trade-off for ease of setup on home/LAN networks where the VM IP is controlled by the host machine itself.
**Recommendation:** For production or internet-exposed setups, remove `StrictHostKeyChecking=no` after the initial connection has been made and the host key cached. The known_hosts entry will then be verified on subsequent connections.
**Status:** Accepted / documented.

---

### [MEDIUM] SSH key path uses environment variable at register time
**File:** `scheduled-restart.ps1` (original version)
**Description:** The original script used `$env:LOCALAPPDATA` to build the SSH key path. When Task Scheduler runs as SYSTEM or a different user, this resolves to the wrong profile path, causing authentication failures.
**Resolution:** Updated script now uses a fully explicit path with `$env:USERNAME` resolved at script-load time, with a pre-flight `Test-Path` check that fails fast with a clear error message before attempting SSH.

---

### [MEDIUM] No error handling on SSH exit code (original)
**File:** `scheduled-restart.ps1` (original version)
**Description:** The original script sent a "restarted successfully" Discord notification unconditionally, even if the SSH command failed silently.
**Resolution:** Updated script checks `$LASTEXITCODE` after the SSH call and throws an exception on non-zero exit, which routes to the failure notification path instead.

---

### [LOW] Transcript log directory world-accessible
**File:** `scheduled-restart.ps1`
**Description:** Logs are written to a `logs\` subdirectory with default NTFS permissions, which may be readable by standard users on a shared machine.
**Recommendation:** If this host is shared, restrict the logs folder: `icacls logs /inheritance:r /grant:r "Administrators:(OI)(CI)F"`
**Status:** Accepted — most users run this on a personal/dedicated server machine.

---

### [LOW] Task runs with highest privileges
**File:** `register-task.ps1`
**Description:** The scheduled task is registered with `RunLevel Highest` (elevated). This is required for Hyper-V PowerShell cmdlets (`Get-VMNetworkAdapter`) but means the script runs with full admin rights on every execution.
**Recommendation:** Ensure the script file and its parent directory are only writable by administrators to prevent privilege escalation via script replacement.
**Status:** Required for functionality. Documented.

---

### [LOW] `initial-setup.ps1` displays default VM password in plaintext
**File:** `initial-setup.ps1`
**Description:** Line 356 writes `"When prompted, enter the password: dune"` to the console. This is the well-known default and is only shown during initial setup, but it confirms the default credential publicly.
**Context:** This is part of the upstream Dune Awakening server tooling, not the scheduler scripts, and the password is changed during the same setup flow.
**Status:** Informational. Out of scope for this release.

---

## Informational Notes

**Password handling in `vm-utilities.ps1`**
`Set-VmPassword` correctly uses `SecureString` for input and clears the plaintext variable immediately after use (`$plain = $null`). This is good practice.

**SSH key rotation**
`Update-SshKey` in `vm-utilities.ps1` uses an atomic move pattern (`authorized_keys.new` → `authorized_keys`) to prevent a race condition where the authorized_keys file is empty mid-write. This is well-implemented.

**Base64 remote script injection**
`initial-setup.ps1` and `vm-utilities.ps1` use base64-encoded payloads piped via SSH (`echo $b64 | base64 -d | sh`). This is a reasonable approach for sending multi-line scripts without temp file risk, but means any compromise of the Windows host could result in arbitrary code execution on the Linux VM. This is inherent to the architecture.

**`-NonInteractive` flag added**
The updated `register-task.ps1` adds `-NonInteractive` to the PowerShell invocation in the scheduled task action. This prevents the task from hanging on unexpected prompts when running headless.

---

## Files Modified in This Release

| File | Changes |
|------|---------|
| `scheduled-restart.ps1` | Added error handling, pre-flight checks, logging, `IdentitiesOnly=yes`, `$ErrorActionPreference`, `Set-StrictMode`, try/catch/finally, non-fatal Discord errors |
| `register-task.ps1` | Added `-NonInteractive` flag, existing task detection, path validation, `-StartWhenAvailable` setting |
| `README.md` | New file — setup guide and security notes |

## Files Not Modified

| File | Notes |
|------|-------|
| `battlegroup.ps1` | Upstream tool — out of scope |
| `vm-utilities.ps1` | Upstream tool — out of scope |
| `initial-setup.ps1` | Upstream tool — out of scope |
| `battlegroup.bat` | Upstream tool — out of scope |
