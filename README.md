# Windows Secure Boot Certificate Updater

> [!IMPORTANT]
> Microsoft's 2011 Secure Boot certificates expired between June and October 2026. A PC without the 2023 certificates **still starts and still gets normal Windows updates**, but it no longer gets security fixes for the boot process (boot manager, Secure Boot DB/DBX updates, revocations). This tool checks your PC and, if needed, asks Windows to install the 2023 certificates and the 2023-signed boot manager.
>
> 📦 **[Download Update-SecureBootCert.zip](https://github.com/j0p3s/Update-SecureBootCert/releases/latest/download/Update-SecureBootCert.zip)**

[中文說明 (Traditional Chinese)](./README_TW.md)

![version](https://img.shields.io/badge/version-2.1-orange) ![platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011%20%7C%20Server-blue)

## Table of Contents

- [Quick Start](#quick-start)
- [Screenshots](#screenshots)
- [What the 2026 expiry means](#what-the-2026-expiry-means)
- [What the tool does](#what-the-tool-does)
- [Supported systems](#supported-systems)
- [Command line](#command-line)
- [Reading the status](#reading-the-status)
- [Windows 10 without ESU](#windows-10-without-esu)
- [Troubleshooting](#troubleshooting)
- [If the PC does not start](#if-the-pc-does-not-start)
- [Legacy BIOS (CSM) users](#legacy-bios-csm-users)
- [Enterprise deployment](#enterprise-deployment)
- [Checking by hand](#checking-by-hand)
- [References](#references)
- [Credits](#credits)
- [Changelog](#changelog)

---

## Quick Start

1. Download the zip and unzip it. If Windows blocks the files, right-click the zip → **Properties** → tick **Unblock** before unzipping.
2. Open one of these (both ask for administrator rights once):
   - **`Update-SecureBootCert-GUI.cmd`**: a window with the status and the options.
   - **`RunMe.bat`**: the same steps in a console window.
3. Read the status at the top. If it says the PC is not updated, start the update. Nothing changes before you confirm.
4. **Restart** when asked, then **open the tool again**: it starts the next step and confirms the result. It can ask for one more restart.

> [!TIP]
> If the PC uses **BitLocker**, have the 48-digit recovery key ready ([aka.ms/myrecoverykey](https://aka.ms/myrecoverykey)), or choose **Suspend BitLocker for 2 restarts** in the tool. BitLocker turns back on by itself.

Logs are saved in `%ProgramData%\Update-SecureBootCert`.

---

## Screenshots

The GUI (`Update-SecureBootCert-GUI.cmd`) on a Windows 10 PC that is partly updated. It shows the result at the top, the state of the PC, and the certificates found in the firmware.

![Main window with the status and the certificates in the firmware](docs/screenshots/gui-certificates.png)

The **Recent Secure Boot events** tab lists the Secure Boot messages from the System log with an explanation for each.

![Recent Secure Boot events tab](docs/screenshots/gui-events.png)

Nothing is changed until you click **Start update** and confirm.

![Confirmation before the update starts](docs/screenshots/gui-confirm.png)

> **Window language:** the button at the top right switches the window between English and Traditional Chinese, and the log file follows it. The window starts in Traditional Chinese when Windows is set to `zh-TW`, `zh-HK` or `zh-MO`, English otherwise; `SBGUI_LANG=en` or `SBGUI_LANG=zh-TW` sets the starting language. The screenshots show the English window.

---

## What the 2026 expiry means

| Old certificate | Expired | Replaced by | Stored in | Used for |
|---|---|---|---|---|
| Microsoft Corporation KEK CA 2011 | 2026-06-24 | Microsoft Corporation KEK 2K CA 2023 (valid to 2038) | KEK | Signing updates to DB and DBX |
| Microsoft Corporation UEFI CA 2011 | 2026-06-27 | Microsoft UEFI CA 2023 (to 2038) | DB | Third-party boot loaders (Linux shim, tools) |
| Microsoft Corporation UEFI CA 2011 | 2026-06-27 | Microsoft Option ROM UEFI CA 2023 (to 2038) | DB | Third-party option ROMs (graphics, network cards) |
| Microsoft Windows Production PCA 2011 | 2026-10-19 | Windows UEFI CA 2023 (to 2035) | DB | The Windows boot manager |

**What happens without the 2023 certificates:**
- ✅ The PC keeps starting. UEFI firmware does not check certificate expiry dates at boot.
- ✅ Normal Windows updates keep installing.
- ❌ No more security updates for the boot process: new boot managers, DB/DBX updates and fixes for newly found boot-level vulnerabilities.
- ❌ Over time, newer boot media and third-party boot loaders signed only with the 2023 certificates will not start with Secure Boot on.

The expired 2011 certificates stay in the firmware next to the 2023 ones, so older boot media keeps working. That is normal.

---

## What the tool does

### 1. Reads the state (changes nothing)

| What | Where it comes from |
|---|---|
| Secure Boot on/off | `Confirm-SecureBootUEFI` |
| Certificates in KEK and DB, with their real expiry dates | The firmware variables, parsed as EFI signature lists |
| Windows' own update status | `HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing` (`UEFICA2023Status`, `UEFICA2023Error`, `WindowsUEFICA2023Capable`) |
| Queued update | `AvailableUpdates` |
| The Secure-Boot-Update scheduled task | Last run and result |
| BitLocker on the system drive | On/off, recovery key protector |
| Pending restart | Windows servicing flags |
| Recent Secure Boot events | System log, source TPM-WMI, with an explanation for each |

### 2. Updates (only after you confirm)

| Step | When | Default |
|---|---|---|
| Install **KB5073724** from the Microsoft Update Catalog | Windows 10 21H2/22H2 only, and only if older than build 1904x.6809 | On |
| Install all pending Windows software updates | Optional (not drivers, not hidden updates) | Off |
| Suspend BitLocker for 2 restarts | Only if BitLocker is on | Off (asked) |
| Set `AvailableUpdates = 0x5944` and start the Secure-Boot-Update task | Microsoft's full update: 2023 KEK, 2023 DB certificates and the 2023-signed boot manager | On |

If Windows has **already queued** an update (for example `0x4100`), the tool does not overwrite it; it only starts the task.
The old v1.x method (`0x40`, only Windows UEFI CA 2023 in the DB) is still available as an option.

### 3. Shows the result

It reads everything again, explains what is left and asks to restart. The usual sequence is:

1. The task runs → `AvailableUpdates` becomes `0x4100` (certificates applied, boot manager pending).
2. **Restart**, then run the tool again → the task finishes → `0x4000`, status `Updated`.
3. One more restart may be needed until Windows starts from the 2023-signed boot manager (`WindowsUEFICA2023Capable = 2`).

If you do not run it again, Windows runs the task by itself within about 12 hours.

---

## Supported systems

- ✅ Windows 11 (all versions)
- ✅ Windows 10 22H2 / 21H2, including Enterprise LTSC 2021 and IoT Enterprise LTSC 2021
- ✅ Windows Server 2016 / 2019 / 2022 / 2025
- ⚠️ UEFI with Secure Boot. With legacy BIOS (CSM) there is nothing to update in the firmware.
- ⚠️ The **Secure-Boot-Update** scheduled task must exist (it is part of Windows' Secure Boot servicing in current updates). If it is missing, install the latest cumulative update first.
- ⚠️ Administrator rights. Internet only for the optional KB5073724 and Windows Update steps.

---

## Command line

```powershell
.\Update-SecureBootCert.ps1 [-CheckOnly] [-Unattended] [-InstallWindowsUpdates] [-SkipKB]
                            [-DbOnly] [-SuspendBitLocker] [-Restart] [-NoPause] [-Lang <auto|en|zh-TW>] [-LogPath <file>]
```

| Parameter | What it does |
|---|---|
| `-CheckOnly` | Only show the state; change nothing |
| `-Unattended` | No questions; uses the defaults plus the switches you pass |
| `-InstallWindowsUpdates` | Also install all pending Windows software updates |
| `-SkipKB` | Do not install KB5073724 on older Windows 10 |
| `-DbOnly` | Old method: only add Windows UEFI CA 2023 to the DB (`0x40`) |
| `-SuspendBitLocker` | Suspend BitLocker for the next 2 restarts |
| `-Restart` | Restart automatically (after 30 seconds) when needed |
| `-NoPause` | Do not wait for Enter at the end |
| `-Lang` | Interface language: `auto` (Chinese when Windows is set to zh-TW/HK/MO), `en`, or `zh-TW` |
| `-LogPath` | Where to write the log |

`RunMe.bat` passes its arguments on, for example `RunMe.bat -CheckOnly` or `RunMe.bat -Lang zh-TW`.

The output follows the Windows language unless you pass `-Lang`; `SB_LANG=en` or `SB_LANG=zh-TW` does the same as a parameter. The script and its log file are then in English or Traditional Chinese.

**Exit codes**

| Code | Meaning |
|---|---|
| 0 | Up to date, or nothing to do (also legacy BIOS) |
| 1 | Error |
| 2 | Update needed (`-CheckOnly`) or not finished |
| 3 | Cancelled |
| 3010 | Restart needed; run the tool again afterwards |

**Examples**

```powershell
# Report only
.\Update-SecureBootCert.ps1 -CheckOnly

# Silent, for a deployment tool; restarts by itself
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Update-SecureBootCert.ps1 -Unattended -SuspendBitLocker -Restart
```

---

## Reading the status

**`AvailableUpdates`** (`HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot`)

| Value | Meaning |
|---|---|
| not set / `0` | Nothing queued |
| `0x5944` | Full update queued (what this tool sets) |
| `0x4100` | Certificates applied; restart, then the task installs the boot manager |
| `0x4000` | Finished |
| `0x40` | Old method: Windows UEFI CA 2023 queued for the DB |

**`UEFICA2023Status`**: `NotStarted`, `InProgress` or `Updated`. **`UEFICA2023Error`**: 0 when there is no error.
**`WindowsUEFICA2023Capable`**: 0 = 2023 CA not in the DB, 1 = in the DB, 2 = in the DB and the PC starts from the 2023-signed boot manager.

**Events** (System log, source TPM-WMI)

| Event | Meaning |
|---|---|
| 1808 | Finished: the PC has the 2023 certificates and boot manager |
| 1799 | Boot manager signed with Windows UEFI CA 2023 installed |
| 1036 / 1043 / 1044 / 1045 | DB updated / KEK updated / Option ROM CA added / Microsoft UEFI CA 2023 added |
| 1800 | A restart is needed before the update can continue |
| 1801 | The 2023 certificates/boot manager are not fully applied yet |
| 1032 | Not applied: BitLocker would have asked for the recovery key |
| 1795 / 1796 | Firmware or unexpected error; Windows tries again at the next restart |
| 1802 | Blocked by Microsoft because of a known firmware issue on this device |
| 1803 | The KEK cannot be updated: the PC maker has no KEK signed with this PC's platform key |

---

## Windows 10 without ESU

- KB5073724 (January 2026) and later cumulative updates for Windows 10 are ESU updates. Without an ESU license they may not install, or Windows can remove them after the restart. The tool skips this step when the PC is already at build .6809 or later.
- The certificate step does **not** depend on KB5073724. It uses Windows' own Secure-Boot-Update task, which updated Windows 10 builds already have (the DB-only method has been documented by Microsoft since 2024, KB5036210).
- How much of the full update an older Windows 10 build can do depends on its last installed update. The tool shows exactly what was applied (KEK, DB, boot manager). If the KEK or the boot manager step is not possible, you can still use the old method (`-DbOnly`) to get Windows UEFI CA 2023 into the DB.

---

## Troubleshooting

| What you see | What to do |
|---|---|
| Event **1803** (KEK update not possible) | The firmware has no Microsoft-signed KEK update for this PC model. Install the latest BIOS/UEFI update from the PC maker. The DB certificates can still be added. |
| Event **1802** (blocked, known firmware issue) | Install the latest BIOS/UEFI update, then run the tool again. |
| Event **1795 / 1796** | The firmware refused the change. Update the BIOS/UEFI; Windows tries again at every restart. |
| Event **1032** | BitLocker would have gone into recovery. Suspend BitLocker for 2 restarts and run the update again. |
| "Secure-Boot-Update task NOT FOUND" | Install the latest cumulative update for this Windows. |
| Status stays `InProgress` | Restart, then run the tool again (it starts the task). Check `UEFICA2023Error` and the events in the tool. |
| Virtual machines | Secure Boot must be on, and the hypervisor must allow KEK/DB updates. Check your hypervisor's guidance. |

---

## If the PC does not start

Certificate expiry alone does not stop a PC from starting. If a PC does not start with Secure Boot on after a firmware or boot change:

**A. BitLocker asks for the recovery key**: enter the 48-digit key from [aka.ms/myrecoverykey](https://aka.ms/myrecoverykey). Windows starts normally afterwards.

**B. Turn Secure Boot off for a moment**
1. Open the BIOS/UEFI setup (usually `Del`, `F2` or `F10` at power-on).
2. Set **Secure Boot** to **Disabled**, save and restart.
3. In Windows, run this tool and let it finish.
4. Turn **Secure Boot** back on in the BIOS/UEFI setup.

**C. Add the certificate in the firmware (advanced)**
1. On another PC, download the certificate files from Microsoft's repository [microsoft/secureboot_objects](https://github.com/microsoft/secureboot_objects), folder `PreSignedObjects/DB/Certificates`: `windows uefi ca 2023.der` (and, for third-party boot loaders, `microsoft uefi ca 2023.der` and `microsoft option rom uefi ca 2023.der`).
2. Copy them to a FAT32 USB stick.
3. In the BIOS/UEFI setup, open Secure Boot key management (often under **Custom Mode**) and choose **Append** to **DB (Authorized Signatures)**.
4. Pick the `.der` file, confirm, save and restart.

Never change the **PK** or the **KEK** by hand unless you know exactly what you are doing.

---

## Legacy BIOS (CSM) users

- In legacy BIOS mode the firmware does not use Secure Boot, so the expiry does not affect starting the PC, and there is nothing for this tool to update. Windows' own driver signing does not depend on these firmware certificates.
- If you switch to UEFI later (for example to install Windows 11), the firmware may only have the 2011 certificates. Install with Secure Boot off if the media does not start, run this tool in Windows, then turn Secure Boot on.

---

## Enterprise deployment

Microsoft's documented methods (Group Policy, Intune, or the `AvailableUpdates = 0x5944` registry value) are the reference; see the [registry key article](https://support.microsoft.com/en-us/topic/registry-key-updates-for-secure-boot-windows-devices-with-it-managed-updates-a7be69c9-4634-42e1-9ca1-df06f43f360d). Do not write `AvailableUpdatesPolicy` yourself: Group Policy and Intune set it, and Windows uses it for reference only.

This script can also be run silently (`-Unattended`, exit codes above). To check many PCs:

```powershell
Invoke-Command -ComputerName PC1, PC2 -ScriptBlock {
    $s = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing' -ErrorAction SilentlyContinue
    [pscustomobject]@{ Status = $s.UEFICA2023Status; Error = $s.UEFICA2023Error; Capable = $s.WindowsUEFICA2023Capable }
}
```

Install the PC makers' BIOS/UEFI updates first: many KEK and DB problems are fixed there.

---

## Checking by hand

```powershell
# Windows' own status (expect Updated)
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing' |
    Select-Object UEFICA2023Status, UEFICA2023Error, WindowsUEFICA2023Capable

# Certificates in the firmware (expect True)
[Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI KEK).Bytes) -match 'Microsoft Corporation KEK 2K CA 2023'
[Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).Bytes) -match 'Windows UEFI CA 2023'

# Queued update
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot' -Name AvailableUpdates

# Recent Secure Boot events
Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 1036, 1043, 1799, 1800, 1801, 1803, 1808 } -MaxEvents 10
```

---

## References

- [Windows Secure Boot certificate expiration and CA updates](https://support.microsoft.com/en-us/topic/windows-secure-boot-certificate-expiration-and-ca-updates-7ff40d33-95dc-4c3c-8725-a9b95457578e) (Microsoft)
- [Registry key updates for Secure Boot: Windows devices with IT-managed updates](https://support.microsoft.com/en-us/topic/registry-key-updates-for-secure-boot-windows-devices-with-it-managed-updates-a7be69c9-4634-42e1-9ca1-df06f43f360d) (Microsoft)
- [Secure Boot DB and DBX variable update events](https://support.microsoft.com/en-us/servicing/os/windows/2022/06/secure-boot-db-and-dbx-variable-update-events) (Microsoft)
- [KB5073724](https://support.microsoft.com/en-us/topic/bd960b49-050e-432f-a9d5-2454cb377fed) and its [Microsoft Update Catalog page](https://www.catalog.update.microsoft.com/Search.aspx?q=KB5073724)
- [microsoft/secureboot_objects](https://github.com/microsoft/secureboot_objects): the certificate files

---

## Credits

Original tool by **anomixer**. GUI (1.2) and version 2.0 by **j0p3s**; version 2.1 and the dual-language interface by **anomixer**.

Use at your own risk. Changing Secure Boot settings affects how the PC starts.

---

## Changelog

Current version: **2.1**. The full history is in [CHANGELOG.md](CHANGELOG.md).

### 2.1 - 2026-11-11
- **Dual Language interface (English and Traditional Chinese), in the window and in the script.** The GUI has a button at the top right that switches English and Traditional Chinese while it is open; the script has `-Lang auto|en|zh-TW` (and `SB_LANG`). Both start in Traditional Chinese when Windows is set to zh-TW/HK/MO. Everything they show is translated, including the log file.
- **HTTPS only.** The Microsoft Update Catalog download no longer falls back to plain HTTP.
- `0x5944` is the value Microsoft documents for the full update (KB 5068202); the code comment now says so.
- **Fixed:** the language button was drawn behind the title label, so the window showed no toggle at all. It is now on top of the label and anchored to the right edge, so it stays visible when the window is resized.

### 2.0 - 2026-10-23
- **Full update:** installs all the 2023 certificates and the 2023-signed boot manager (`0x5944`), not only Windows UEFI CA 2023. Never overwrites an update Windows has already queued.
- **Real status:** reads the certificates from the firmware with their real expiry dates, Windows' own update status, the task, BitLocker and the Secure Boot events, with advice for known problems.
- **Fixes:** the 2011 third-party CA was never detected, Windows Production PCA 2011 showed "expires soon" after it expired, Windows Update results were misread, Windows Server was treated as Windows 10, and more.
- **New:** command-line parameters and exit codes, log files, optional BitLocker suspension, a GUI that no longer freezes.

### 1.2.1 - 2026-10-23
- **Fixed:** a label in the GUI was cut off.

### 1.2 - 2026-10-23
- **Added** `Update-SecureBootCert-GUI.cmd`.

### 1.1 - 2026-07-13
- Adjusted the expired-certificate logic for the post-June 2026 deadline.

### 1.0 - 2026-01-26
- First version.
