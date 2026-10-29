# PC Driver Check

**English** | [Türkçe](README.tr.md)

A small Windows tool that checks whether your PC's drivers are up to date, shows you what can be updated, and installs **only what you approve** — on any PC, with any hardware.

- No installation, no background service, no third-party downloads: it uses only components built into Windows.
- Nothing is installed without your confirmation.
- A System Restore point is created before anything is changed.
- Messages are shown in **Turkish** on Turkish Windows and in **English** everywhere else.

---

## Contents

- [What it does](#what-it-does)
- [Requirements](#requirements)
- [Usage](#usage)
- [Options](#options)
- [Example output](#example-output)
- [Where updates come from](#where-updates-come-from)
- [Hardware health](#hardware-health)
- [Safety](#safety)
- [Undoing an update](#undoing-an-update)
- [What it does not do](#what-it-does-not-do)
- [FAQ](#faq)
- [Tests](#tests)
- [License](#license)

---

## What it does

1. **Detects this PC**: model, Windows version, CPU, and GPU(s) with their current driver versions. Nothing is hard-coded, so the same tool works on every machine.
2. **Checks hardware health** (read-only): RAM, disks / SSDs and devices with a problem in Device Manager. See [Hardware health](#hardware-health).
3. **Checks NVIDIA GPUs** against NVIDIA's official driver service. This is usually newer than what Windows Update offers.
4. **Scans Windows Update** for every driver Microsoft offers for this exact hardware.
5. **Filters out noise**: drivers for phones and USB accessories you plugged in once (Android, iPhone, MTP, …) are hidden.
6. **Lists the updates** with a number, source, device class, date and size.
7. **Asks you** which ones to install.
8. **Creates a restore point**, then downloads and installs your selection.
9. **Shows a summary**, tells you if a restart is needed, and saves a log file.

## Requirements

| | |
|---|---|
| OS | Windows 10 or Windows 11 (64-bit) |
| Rights | Administrator (the `.bat` asks for it automatically) |
| Network | Internet connection |
| PowerShell | Windows PowerShell 5.1 (included with Windows) |

## Usage

1. Download the repository: **Code → Download ZIP**, then extract it.
   > If Windows blocks the files, right-click the ZIP → **Properties** → tick **Unblock** → OK, then extract again.
2. Double-click **`Check-Drivers.bat`**.
3. Click **Yes** in the administrator prompt.
4. Wait for the scan (Windows Update may take 1–2 minutes).
5. Type the numbers you want to install and press Enter:

| Input | Meaning |
|---|---|
| `1,3` | install items 1 and 3 |
| `1-4` | install items 1 to 4 |
| `A` (English) / `T` (Turkish) | install all |
| *(empty)* + Enter | install nothing and exit |

6. Restart your PC if the tool tells you to.

## Options

Run from a terminal in the tool's folder:

```bat
Check-Drivers.bat -ScanOnly          :: only list updates, install nothing
Check-Drivers.bat -IncludeDevices    :: also show phone / USB accessory drivers
Check-Drivers.bat -NoBackup          :: skip the driver backup before installing
```

Or call the script directly:

```powershell
powershell -ExecutionPolicy Bypass -File .\PC-Driver-Check.ps1 -ScanOnly
```

### Exit codes

Useful when the tool is called from another script or Task Scheduler:

| Code | Meaning |
|---|---|
| `0` | Done, or nothing to update / nothing selected |
| `1` | Error: not run as administrator, or a scan (Windows Update / NVIDIA) failed |
| `2` | At least one selected driver failed to install |
| `3010` | Installed, restart required (standard Windows code) |

## Example output

```
PC-Driver-Check - driver update check

==== This PC ====
Model        Example Laptop 15
Windows      Microsoft Windows 11 Pro (build 26100)
CPU          Intel(R) Core(TM) Ultra 7 155H
GPU          NVIDIA GeForce RTX 4070 Laptop GPU  [32.0.15.5222]

==== Hardware health ====
RAM          32 GB DDR5, 2/2 slots used, 5600 MT/s
Disk         Example NVMe SSD 1TB | NVMe SSD | 1000 GB | firmware 1.0
             health: good | wear: %3 | temperature: 41°C
[OK] No problem devices.
[--] Checking NVIDIA driver: NVIDIA GeForce RTX 4070 Laptop GPU
[--] Scanning Windows Update (this can take 1-2 minutes)...
[--] 3 phone/USB accessory driver(s) hidden (use -IncludeDevices to show).

==== Available updates ====
[1] NVIDIA GeForce RTX 4070 Laptop GPU  552.22 -> 621.01
     NVIDIA | Display | Wed Oct 21, 2026 | 1.04 GB
[2] Intel Corporation ComputeAccelerator Driver Update (32.0.100.5541)
     WU | ComputeAccelerator | 2026-08-20 | 30.3 MB

Numbers to install (e.g. 1,3 or 1-3)  A = all  Enter = none: 1,2
[--] Creating a System Restore point...
[OK] Restore point created: "PC-Driver-Check 2026-10-29 19:20"
...
==== Summary ====
[OK] Installed: 2

RESTART your PC.
```

## Where updates come from

| Source | Covers | Notes |
|---|---|---|
| **Windows Update** | All devices: chipset, audio, network, Bluetooth, storage, GPUs, … | Uses the built-in Windows Update Agent. Only drivers Microsoft has published for *your* hardware IDs are offered. |
| **NVIDIA official service** | NVIDIA GeForce GPUs (desktop and laptop) | Looks up your exact GPU model on nvidia.com and compares it with the installed version. Only a **newer** version is offered. When this check succeeds, the NVIDIA display driver from Windows Update is hidden so it can never downgrade you. |

**AMD and Intel GPUs** are checked through Windows Update. Their own tools usually have newer releases:
[AMD Software: Adrenalin Edition](https://www.amd.com/en/support/download/drivers.html) · [Intel Driver & Support Assistant](https://www.intel.com/content/www/us/en/support/detect.html).

## Hardware health

Shown on every run, including `-ScanOnly`. It only reads information; nothing is changed.

| Part | What is shown | Warning when |
|---|---|---|
| **RAM** | Total size, type (DDR4/DDR5/…), used / total slots, current speed | It runs below its rated speed (XMP/EXPO may be off, or the CPU does not support that speed), or a single module sits in a two-slot system (single channel) |
| **Disks / SSDs** | Model, bus (NVMe/SATA/USB), size, firmware version, health, wear, temperature | Windows reports the disk as not healthy · any uncorrectable read error · wear ≥ 70% (keep an eye on it) or ≥ 90% (plan a replacement) · temperature ≥ 70°C |
| **Devices** | Devices with an error in Device Manager, e.g. *no driver installed* (code 28), plus the hardware ID to search for a driver | Always listed when present. Disabled (code 22) and unplugged (code 45) devices are not shown |

*Wear* is the SSD's own "percentage used" counter: 100% means the manufacturer's rated write endurance is reached (the drive usually keeps working, but it is time to keep backups). Many SATA and USB disks do not report wear or temperature; they are shown as *unknown*, not as a problem.

## Safety

- **Nothing is installed without your selection.** `-ScanOnly` installs nothing at all.
- **Restore point first.** If one cannot be created (for example, System Protection is off), you are asked whether to continue anyway.
- **NVIDIA downloads are verified.** The download URL must be on `nvidia.com`, and the installer's digital signature must be valid and issued to *NVIDIA Corporation*. Otherwise the installer is not run.
- **No downgrades.** NVIDIA updates are offered only if they are newer than the installed driver.
- **Settings are kept.** The NVIDIA driver is installed as an upgrade, not a clean install, so your NVIDIA Control Panel settings stay.
- **Success is checked, not assumed.** After an NVIDIA install the tool reads the installed version again instead of trusting the installer's exit code.
- **Current drivers are backed up.** Before installing, the driver packages the selected devices use now are exported with `pnputil` to `%ProgramData%\PC-Driver-Check\backups\<date>`. Only third-party packages (`oem*.inf`) are exported; Windows' own drivers are always on the system anyway. The two newest backups are kept (an NVIDIA package alone is about 3 GB), and the backup is skipped if less than 10 GB is free. Turn it off with `-NoBackup`.
- **Everything is logged** to `logs\PC-Driver-Check_<date>.log` next to the script.

## Undoing an update

1. Press **Win + R**, type `rstrui`, press Enter.
2. Choose the restore point named **"PC-Driver-Check <date>"**.
3. Follow the wizard; the PC restarts.

For a single device you can also use **Device Manager → device → Properties → Driver → Roll Back Driver**.

From the driver backup (the tool prints the exact folder), in an administrator terminal:

```bat
pnputil /add-driver "C:\ProgramData\PC-Driver-Check\backups\<date>\*.inf" /subdirs /install
```

Then restart. If Windows keeps picking the newer driver, use **Device Manager → device → Update driver → Browse my computer → Let me pick** and choose the older version.

## What it does not do

- BIOS / UEFI or firmware updates (the SSD firmware version is shown, so you can compare it on the manufacturer's site)
- Fixing hardware: RAM, disk and device warnings are information only
- Manufacturer utilities (laptop control centers, RGB software, etc.)
- Windows feature or security updates (use Windows Update for those)
- Running in the background or on a schedule — it only runs when you start it

## FAQ

**Why does the scan take 1–2 minutes?**
Windows Update compares every device in your PC with Microsoft's catalog. The first scan after a restart is the slowest.

**Why are phone drivers hidden?**
Windows offers drivers for every device that was *ever* connected, such as a phone you charged once. They are rarely useful on a PC, so they are hidden by default. Use `-IncludeDevices` to see them.

**Windows says "Windows protected your PC".**
That is SmartScreen reacting to a script downloaded from the internet. Click **More info → Run anyway**, or unblock the ZIP before extracting (see [Usage](#usage)). You can read the full source in `PC-Driver-Check.ps1` before running it.

**My NVIDIA GPU says "model not found".**
Some OEM or very new models have a different name in NVIDIA's list. Check [nvidia.com/drivers](https://www.nvidia.com/drivers) manually. Windows Update is still scanned.

**Is any data sent anywhere?**
Only the standard requests Windows Update makes, and one lookup to nvidia.com with your GPU model. Nothing else is collected or sent.

## Tests

Offline unit tests (version conversion, GPU name matching, accessory filter, selection
input, the NVIDIA lookup against sample service responses, TR/EN message keys and
placeholders) need no administrator rights, network or Windows Update:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\PC-Driver-Check.Tests.ps1
```

They run on every push and pull request with GitHub Actions on Windows PowerShell 5.1 and
PowerShell 7, followed by [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
(rules in `PSScriptAnalyzerSettings.psd1`).

## License

[MIT](LICENSE)
