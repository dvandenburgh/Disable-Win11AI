# Win11-Cleanup

A single PowerShell script that removes bloat, kills AI features, and strips ads from Windows 11 Pro. Tested on 24H2 and 25H2.

All changes go through official policy keys or Appx removal — no system file edits, no risk of breaking Windows Update.

---

## What it does

**AI and Copilot**
- Disables Copilot system-wide (policy + taskbar button + Appx removal)
- Blocks Bing/web results and AI suggestions in Search and Explorer
- Disables Recall AI snapshotting and snapshot export (Copilot+ PCs)
- Disables Click to Do on-screen AI overlay (Copilot+ PCs)
- Removes AI Actions from the File Explorer right-click menu (25H2)
- Disables Paint AI features: Image Creator, Generative Fill, Cocreator

**Bloat and ads**
- Removes Widgets and the Windows Web Experience Pack
- Suppresses Start menu Recommended section and all promoted content
- Kills ads across Start, Settings, Lock Screen, and Explorer
- Blocks Microsoft from silently installing apps via Consumer Experience policy
- Disables OneDrive/cloud sync ads in Explorer sidebar
- Opens Explorer to This PC, shows file extensions
- Removes Task View button from taskbar, sets Search to icon-only

**Privacy and telemetry**
- Sets telemetry to minimum, caps the ceiling, limits diagnostic log collection
- Disables activity feed, user activity publishing and upload
- Disables personalized ads and tailored experiences
- Suppresses Windows feedback notification popups

**Extras**
- 25H2 native Store app removal policy scaffold (Pro+) — see notes below
- Unlocks Ultimate Performance power plan as a selectable option in Power Options

---

## Before you run it

- Must be run as **Administrator**
- Makes HKLM and HKCU registry edits, sets policies, and removes Appx packages
- Attempts to create a restore point (`Before_Win11_Cleanup`) before doing anything
- **Reboot when it's done**

A timestamped log is written to `C:\Users\Public\Win11_Cleanup_YYYYMMDD_HHMMSS.log`.

---

## How to run

```powershell
# 1. Open PowerShell as Administrator
# 2. Navigate to the script folder
cd "C:\path\to\Win11-Cleanup"

# 3. Allow execution for this session only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 4. Run
.\Win11-Cleanup.ps1
```

Reboot when it finishes.

---

## What to expect after rebooting

- Copilot icon gone from taskbar, app removed
- Search no longer shows Bing or Copilot results
- File Explorer right-click menu has no AI Actions entry
- Paint has no Image Creator, Generative Fill, or Cocreator
- Start menu Recommended section gone
- Widgets gone
- No more ad popups, tips, or "Get more out of Windows" prompts
- Explorer opens to This PC, file extensions visible
- Recall and Click to Do blocked by policy (Copilot+ PCs only)
- Ultimate Performance available in Control Panel → Power Options

---

## 25H2 native Store app removal

Windows 11 25H2 (Pro and above) can deprovision specific inbox Store apps for all new user profiles at the policy level. Changes made this way survive feature updates — Windows won't try to restore them.

The script creates the policy key scaffold at:
`HKLM\SOFTWARE\Policies\Microsoft\Windows\Appx\RemoveDefaultMicrosoftStorePackages`

To remove an app, add its package family name as a subkey. Examples in the script include BingNews, BingWeather, Phone Link, Solitaire, Clipchamp, DevHome, and new Outlook.

**Do not add Microsoft Store or any Xbox/gaming packages.** The Store is required for app updates, and Xbox services underpin Game Pass, overlays, and controller input.

---

## Undoing changes

**System Restore** — the script attempts to create a restore point called `Before_Win11_Cleanup` before making any changes.

**Reinstall from Store** — the Copilot app and Windows Web Experience Pack (Widgets) can both be reinstalled from the Microsoft Store.

**Manual revert** — every registry key is documented inline in the script. Find the key and delete it or restore its default value.

---

## Notes

- Copilot+ hardware sections (Recall, Click to Do) are safe to run on any machine — they no-op if the hardware isn't present.
- Paint's Generative Erase and Remove Background don't have policy keys yet and can't be blocked this way.
- Major Windows feature updates may re-enable some settings. Re-run after upgrading.
- The `DisableWindowsConsumerFeatures` CloudContent key is the most important one for blocking silent app installs. If you revert anything, keep that one.
- This script doesn't touch third-party software, Edge internals, or OneDrive.
