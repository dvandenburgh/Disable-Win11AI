# Disable Windows 11 AI Features (Gaming-Friendly)

This repository contains a PowerShell script that turns off most of the built-in AI features in Windows 11 Pro, with a focus on **gaming PCs**.

The script:

- Disables **Copilot** and hides its taskbar button  
- Removes the **Microsoft Copilot** app (if installed)  
- Disables **Bing / web integration** in Start / taskbar search  
- Turns off **search suggestions** and **Explorer / Run autosuggest**  
- Blocks **Windows Recall / AI snapshotting** (on Copilot+ PCs)  
- Removes the **Windows Web Experience Pack** (Widgets and some cloud content)  
- Logs what it does so you can review changes  

It is designed to remove as much AI as possible **without breaking normal Windows use**.

---

## ⚠️ Before You Start

- You **must** run the script as an **Administrator**.  
- The script makes **system changes** (registry edits, app removals, policies).  
- A **system restore point** is attempted for safety (if Windows allows it).  
- You should **reboot** after running the script.

If at any point you’re unsure, stop and ask someone more technical for help.

---

## 1. Get the Script

1. Download or clone this repository.  
2. Make sure the file `Disable-Win11AI.ps1` is in a folder you can find, e.g.:

   ```text
   C:\Users\YourName\Downloads\DisableWinAI\
   ```

---

## 2. Open PowerShell as Administrator

1. Click **Start**.  
2. Type **PowerShell**.  
3. Right-click **Windows PowerShell** (or **PowerShell 7** if you have it).  
4. Click **Run as administrator**.  
5. If Windows asks for permission (UAC prompt), click **Yes**.

You’ll know it worked if the window title includes `Administrator`.

---

## 3. Go to the Folder with the Script

In the Administrator PowerShell window, go to the folder where you saved the script. For example:

```powershell
cd "C:\Users\YourName\Downloads\DisableWinAI"
```

To confirm the script is there, run:

```powershell
dir
```

You should see `Disable-Win11AI.ps1` listed.

---

## 4. (Optional but Recommended) Read the Script

It’s always good practice to look at scripts before running them.

```powershell
notepad .\Disable-Win11AI.ps1
```

Skim it to reassure yourself it’s doing what you expect (disabling Copilot, Recall, Widgets, etc.).

Close Notepad when you’re done.

---

## 5. Allow the Script to Run (Safest Method)

Windows PowerShell has an **execution policy** that can block scripts.  
We’ll change it in the **safest way**: only for this one PowerShell window.

In the same Administrator PowerShell window, run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

- `-Scope Process` means the change is temporary and only affects this one PowerShell session.  
- `-ExecutionPolicy Bypass` lets the script run without being blocked in this session, but **does not** permanently weaken the policy for your user or the whole machine.  

If you’re curious about your policies, you can check them with:

```powershell
Get-ExecutionPolicy -List
```

---

## 6. Run the Script

Now, actually run the script:

```powershell
.\Disable-Win11AI.ps1
```

You should see messages like:

- `Attempting to create system restore point…`  
- `Disabling Bing/web results…`  
- `Removing Copilot package Microsoft.Copilot…`  
- `Removing Web Experience package MicrosoftWindows.Client.WebExperience…`  
- `All sections completed. A system reboot is recommended…`  

The script also creates a log file in:

```text
C:\Users\Public\Disable_AIFeatures_YYYYMMDD_HHMMSS.log
```

You can open this later with Notepad if you want to see exactly what happened.

---

## 7. Restart Your PC

When the script finishes:

1. Close the Administrator PowerShell window.  
   - This automatically discards the temporary `Process` execution policy change.  
2. **Restart Windows**.

A reboot is important so that:

- Policy changes fully apply.  
- Removed components (Copilot, Web Experience Pack) are fully unloaded.

---

## 8. What Should Be Different After Reboot

After restarting:

- The **Copilot icon/button** should be gone from the taskbar.  
- **Copilot** itself should be disabled / removed.  
- **Start / taskbar search** should no longer push `Ask Copilot` or Bing/web-style results.  
- **Widgets** (Win+W or the Widgets icon) should not open.  
- If you have a **Copilot+ PC**, **Recall** should be disabled / blocked according to policy.  
- Explorer and the Run dialog should stop showing “smart” autosuggest text.

If you still see some AI-related stuff in a specific spot (e.g. a certain app or menu), you may need an extra tweak for that exact area.

---

## 9. How to Undo Changes (If Needed)

There are a few ways to undo changes if you don’t like the result:

### 9.1 System Restore

If System Restore was enabled, the script attempted to create (or reuse) a restore point.

You can roll back to a restore point via:

1. **Start → type `Recovery` → open `Recovery`**  
2. Click **Open System Restore**.  
3. Choose a restore point from *before* you ran the script.

### 9.2 Reinstall Components

- **Windows Web Experience Pack** (Widgets) can be reinstalled from the Microsoft Store (search for **"Windows Web Experience Pack"**).  
- **Copilot** or other removed apps can usually be reinstalled from the Microsoft Store as well.

### 9.3 Manual Registry/Policy Revert

Advanced users can manually revert registry keys set by the script if needed.

---

## 10. Notes and Limitations

- This script focuses on **built-in Windows AI features** (Copilot, Recall, Widgets, Bing search integration).  
- It does **not** touch third-party apps (e.g. Discord, Steam, GeForce Experience) that might have their own AI features.  
- Some future Windows updates may re-enable or reintroduce certain features. You might need to re-run the script or adjust settings again after major updates.

---

