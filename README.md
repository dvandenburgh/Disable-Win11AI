# Disable Windows 11 AI Features

A PowerShell script that disables the built-in AI garbage in Windows 11 Pro. Tested on 24H2 and 25H2.

**What it disables:**
- Copilot (policy, taskbar button, and Appx removal)
- Bing/web integration in Start and taskbar search
- Search box suggestions and Explorer/Run autosuggest
- Recall AI snapshotting and snapshot export (Copilot+ PCs)
- Click to Do — the Win+Q on-screen AI overlay (Copilot+ PCs)
- AI Actions submenu in File Explorer right-click menu
- Paint AI features (Image Creator, Generative Fill, Cocreator)
- Start menu Recommended / promoted content
- Windows Web Experience Pack (Widgets)

Nothing in this script should break normal Windows use. All changes go through official policy keys or Appx removal — no system file hacks.

---

## Before you run it

- Must be run as **Administrator**
- Makes registry edits, sets policies, and removes Appx packages
- Attempts to create a restore point before doing anything
- **Reboot when it's done**

---

## How to run

1. Download the repo and open an **Administrator PowerShell** window (`Start → PowerShell → Run as administrator`).

2. Navigate to the folder:
   ```powershell
   cd "C:\path\to\DisableWinAI"
   ```

3. Allow the script for this session only:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

4. Run it:
   ```powershell
   .\Disable-Win11AI.ps1
   ```

5. Reboot.

A log file is written to `C:\Users\Public\Disable_AIFeatures_YYYYMMDD_HHMMSS.log` so you can see exactly what was changed.

---

## What to expect after rebooting

- Copilot icon gone from taskbar, app removed
- Start/taskbar search no longer shows Bing/Copilot results
- File Explorer right-click menu no longer has an AI Actions entry
- Paint no longer shows Image Creator, Generative Fill, or Cocreator
- Start menu Recommended section suppressed
- Widgets gone
- Recall and Click to Do blocked by policy (Copilot+ PCs)

---

## Undoing changes

**System Restore** — if it was enabled, the script creates a restore point called `Before_AI_Disable` before making any changes.

**Reinstall from Store** — the Copilot app and Windows Web Experience Pack (Widgets) can both be reinstalled from the Microsoft Store.

**Manual revert** — all registry keys set by the script are documented in the script itself with comments.

---

## Notes

- Targets built-in Windows AI features only — third-party apps (Steam, Discord, etc.) are untouched.
- Major Windows updates may re-enable some of this. Re-run the script if something comes back.
- Click to Do and Recall sections are safe to run on non-Copilot+ hardware — they just have no effect.
- Paint's Generative Erase and Remove Background don't have policy keys yet, so those can't be blocked this way.
