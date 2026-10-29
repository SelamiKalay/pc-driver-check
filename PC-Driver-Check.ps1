<#
.SYNOPSIS
    PC-Driver-Check - scans this PC for driver updates, asks before installing.

.DESCRIPTION
    Sources:
      - Windows Update (all device drivers Microsoft offers for this PC)
      - NVIDIA's official driver service (GeForce GPUs; usually newer than Windows Update)
    Nothing is installed without confirmation. A System Restore point is created first.
    Messages are shown in Turkish on Turkish Windows, English otherwise.

.PARAMETER ScanOnly
    List available updates and exit without installing anything.

.PARAMETER IncludeDevices
    Also show phone / USB accessory drivers (hidden by default).

.EXAMPLE
    .\Check-Drivers.bat
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\PC-Driver-Check.ps1 -ScanOnly
#>
param(
    [switch]$ScanOnly,
    [switch]$IncludeDevices
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8   # Turkish characters in console and log
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

# ------------------------------------------------------------------
# Language
# ------------------------------------------------------------------
$Lang = if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'tr') { 'tr' } else { 'en' }

$Msg = @{
    tr = @{
        NeedAdmin      = 'Yönetici olarak çalıştırın (Check-Drivers.bat bunu otomatik yapar).'
        Title          = 'PC-Driver-Check - sürücü güncelleme kontrolü'
        PcInfo         = 'Bilgisayar'
        Model          = 'Model'
        Os             = 'Windows'
        Cpu            = 'İşlemci'
        Gpu            = 'Ekran kartı'
        WuScan         = 'Windows Update taranıyor (1-2 dakika sürebilir)...'
        WuFailed       = 'Windows Update taranamadı: {0}'
        WuHidden       = '{0} telefon/USB aygıtı sürücüsü gizlendi (göstermek için -IncludeDevices).'
        NvCheck        = 'NVIDIA sürücüsü kontrol ediliyor: {0}'
        NvUpToDate     = '{0}: güncel ({1})'
        NvNoMatch      = '{0}: model NVIDIA listesinde bulunamadı. nvidia.com/drivers adresinden elle kontrol edin.'
        NvFailed       = 'NVIDIA servisine ulaşılamadı: {0}'
        NoUpdates      = 'Tüm sürücüler güncel.'
        Found          = 'Bulunan güncellemeler'
        ScanOnlyDone   = '-ScanOnly: hiçbir şey kurulmadı.'
        Ask            = 'Kurulacakların numaraları (örnek: 1,3 veya 1-3)  T = tümü  Enter = hiçbiri'
        AskInvalid     = 'Geçersiz seçim, tekrar deneyin.'
        NothingChosen  = 'Hiçbir şey seçilmedi, çıkılıyor.'
        RpCreating     = 'Sistem geri yükleme noktası oluşturuluyor...'
        RpOk           = 'Geri yükleme noktası oluşturuldu: "{0}"'
        RpFailed       = 'Geri yükleme noktası oluşturulamadı ({0}).'
        RpContinue     = 'Yine de kurulsun mu? (E/H)'
        Cancelled      = 'İptal edildi.'
        Installing     = 'Kuruluyor: {0}'
        Downloading    = 'İndiriliyor: {0}'
        WuOk           = 'Kuruldu: {0}'
        WuFail         = 'Kurulamadı: {0} (sonuç kodu {1})'
        NvSigBad       = 'İMZA GEÇERSİZ, kurulmadı: {0}'
        NvBadHost      = 'İndirme adresi nvidia.com değil, kurulmadı: {0}'
        NvOk           = 'NVIDIA sürücüsü kuruldu: {0}'
        NvFail         = 'NVIDIA kurulumu doğrulanamadı (kurulu sürüm: {0}, beklenen: {1}). Yeniden başlatıp tekrar kontrol edin.'
        Summary        = 'Özet'
        SumOk          = 'Kurulan: {0}'
        SumFail        = 'Başarısız: {0}'
        Reboot         = 'Bilgisayarı YENİDEN BAŞLATIN.'
        Log            = 'Kayıt dosyası: {0}'
        AllWord        = 'T'
        YesWord        = 'E'
        Device         = 'aygıt'
    }
    en = @{
        NeedAdmin      = 'Run as administrator (Check-Drivers.bat does this automatically).'
        Title          = 'PC-Driver-Check - driver update check'
        PcInfo         = 'This PC'
        Model          = 'Model'
        Os             = 'Windows'
        Cpu            = 'CPU'
        Gpu            = 'GPU'
        WuScan         = 'Scanning Windows Update (this can take 1-2 minutes)...'
        WuFailed       = 'Windows Update scan failed: {0}'
        WuHidden       = '{0} phone/USB accessory driver(s) hidden (use -IncludeDevices to show).'
        NvCheck        = 'Checking NVIDIA driver: {0}'
        NvUpToDate     = '{0}: up to date ({1})'
        NvNoMatch      = '{0}: model not found in NVIDIA''s list. Check nvidia.com/drivers manually.'
        NvFailed       = 'Could not reach NVIDIA''s service: {0}'
        NoUpdates      = 'All drivers are up to date.'
        Found          = 'Available updates'
        ScanOnlyDone   = '-ScanOnly: nothing was installed.'
        Ask            = 'Numbers to install (e.g. 1,3 or 1-3)  A = all  Enter = none'
        AskInvalid     = 'Invalid selection, try again.'
        NothingChosen  = 'Nothing selected, exiting.'
        RpCreating     = 'Creating a System Restore point...'
        RpOk           = 'Restore point created: "{0}"'
        RpFailed       = 'Could not create a restore point ({0}).'
        RpContinue     = 'Install anyway? (Y/N)'
        Cancelled      = 'Cancelled.'
        Installing     = 'Installing: {0}'
        Downloading    = 'Downloading: {0}'
        WuOk           = 'Installed: {0}'
        WuFail         = 'Failed: {0} (result code {1})'
        NvSigBad       = 'INVALID SIGNATURE, not installed: {0}'
        NvBadHost      = 'Download URL is not nvidia.com, not installed: {0}'
        NvOk           = 'NVIDIA driver installed: {0}'
        NvFail         = 'Could not verify the NVIDIA install (installed: {0}, expected: {1}). Restart and check again.'
        Summary        = 'Summary'
        SumOk          = 'Installed: {0}'
        SumFail        = 'Failed: {0}'
        Reboot         = 'RESTART your PC.'
        Log            = 'Log file: {0}'
        AllWord        = 'A'
        YesWord        = 'Y'
        Device         = 'device'
    }
}

function M([string]$key) {
    $t = $Msg[$Lang][$key]
    if ($args.Count) { $t = $t -f $args }
    $t
}
function Say-Ok($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Say-Info($m) { Write-Host "[--] $m" -ForegroundColor Gray }
function Say-Warn($m) { Write-Host "[!!] $m" -ForegroundColor Yellow }
function Say-Head($m) { Write-Host "`n==== $m ====" -ForegroundColor Cyan }

# ------------------------------------------------------------------
# Helpers (pure functions - no side effects, easy to test)
# ------------------------------------------------------------------

# Windows driver version -> NVIDIA version: 32.0.16.2101 -> 621.01
function ConvertTo-NvidiaVersion([string]$driverVersion) {
    $p = $driverVersion.Split('.')
    if ($p.Count -lt 4) { return $null }
    $d = $p[2] + $p[3].PadLeft(4, '0')
    $d = $d.Substring($d.Length - 5)
    '{0}.{1}' -f [int]$d.Substring(0, 3), $d.Substring(3, 2)
}

function Get-NormalizedGpuName([string]$name) {
    ($name -replace '^\s*NVIDIA\s+', '').Trim().ToLowerInvariant()
}

# Phone / USB accessory drivers: offered only because a phone was plugged in once
function Test-AccessoryDriver($driverClass, [string]$title) {
    ($driverClass -eq 'OtherHardware') -or ($title -match '(?i)\b(Android|Apple|iPhone|iPad|MTP|ADB|Mobile|Phone|Modem)\b')
}

# "1,3", "1-3", "A"/"T" (all), "" (none) -> index list (1-based), or $null if invalid
function Read-Selection([string]$text, [int]$count) {
    $text = $text.Trim()
    if ($text -eq '') { return ,@() }
    if ($text -match '^(?i)(a|all|t|tumu|tümü)$') { return ,@(1..$count) }
    $picked = @()
    foreach ($part in $text -split '[,\s]+' | Where-Object { $_ }) {
        if ($part -match '^(\d+)-(\d+)$') { $picked += [int]$Matches[1]..[int]$Matches[2] }
        elseif ($part -match '^\d+$') { $picked += [int]$part }
        else { return $null }
    }
    if (@($picked | Where-Object { $_ -lt 1 -or $_ -gt $count }).Count) { return $null }
    ,@($picked | Sort-Object -Unique)
}

# ------------------------------------------------------------------
# Sources
# ------------------------------------------------------------------
function Find-WUDrivers {
    $session = New-Object -ComObject Microsoft.Update.Session
    $result = $session.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Driver'")
    foreach ($u in $result.Updates) {
        [pscustomobject]@{
            Source       = 'WU'
            Title        = $u.Title
            Class        = $u.DriverClass
            Manufacturer = $u.DriverManufacturer
            Date         = $u.DriverVerDate
            SizeMB       = [double]$u.MaxDownloadSize / 1MB
            Update       = $u
        }
    }
}

function Find-NvidiaDriver($gpu) {
    $installed = ConvertTo-NvidiaVersion $gpu.DriverVersion
    $products = [xml](Invoke-WebRequest 'https://www.nvidia.com/Download/API/lookupValueSearch.aspx?TypeID=3' -UseBasicParsing).Content
    $want = Get-NormalizedGpuName $gpu.Name
    $match = $products.LookupValueSearch.LookupValues.LookupValue |
        Where-Object { (Get-NormalizedGpuName $_.Name) -eq $want } | Select-Object -First 1
    if (-not $match) { return [pscustomobject]@{ Status = 'NoMatch'; Gpu = $gpu.Name } }

    $url = 'https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php' +
           "?func=DriverManualLookup&psid=$($match.ParentID)&pfid=$($match.Value)&osID=57&languageCode=1033&isWHQL=1&dch=1&sort1=0&numberOfResults=1"
    $resp = Invoke-RestMethod $url -UseBasicParsing
    if ($resp -is [string]) { $resp = $resp | ConvertFrom-Json }   # served as text/html
    $info = $resp.IDS[0].downloadInfo
    $latest = [string]$info.Version

    [pscustomobject]@{
        Status    = if ([version]$latest -gt [version]$installed) { 'Update' } else { 'Current' }
        Source    = 'NVIDIA'
        Gpu       = $gpu.Name
        Installed = $installed
        Latest    = $latest
        Title     = "$($gpu.Name)  $installed -> $latest"
        Class     = 'Display'
        Date      = $info.ReleaseDateTime
        SizeMB    = $info.DownloadURLFileSize
        Url       = $info.DownloadURL
    }
}

# ------------------------------------------------------------------
# Install
# ------------------------------------------------------------------
function New-RestorePoint {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $old = (Get-ItemProperty $key -EA SilentlyContinue).SystemRestorePointCreationFrequency
    $name = "PC-Driver-Check $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    try {
        # Windows allows one restore point per 24h by default; lift it for this one
        Set-ItemProperty $key SystemRestorePointCreationFrequency 0 -Type DWord
        $before = @(Get-ComputerRestorePoint -EA SilentlyContinue).Count
        Checkpoint-Computer -Description $name -RestorePointType DEVICE_DRIVER_INSTALL -EA Stop
        if (@(Get-ComputerRestorePoint -EA SilentlyContinue).Count -le $before) { throw 'System Protection is off' }
        Say-Ok (M RpOk $name)
        $true
    } catch {
        Say-Warn (M RpFailed $_.Exception.Message)
        $false
    } finally {
        if ($null -eq $old) { Remove-ItemProperty $key SystemRestorePointCreationFrequency -EA SilentlyContinue }
        else { Set-ItemProperty $key SystemRestorePointCreationFrequency $old -Type DWord }
    }
}

function Install-WUDriver($item) {
    $session = New-Object -ComObject Microsoft.Update.Session
    $coll = New-Object -ComObject Microsoft.Update.UpdateColl
    if (-not $item.Update.EulaAccepted) { $item.Update.AcceptEula() }
    [void]$coll.Add($item.Update)

    Say-Info (M Downloading $item.Title)
    $dl = $session.CreateUpdateDownloader(); $dl.Updates = $coll; [void]$dl.Download()
    Say-Info (M Installing $item.Title)
    $inst = $session.CreateUpdateInstaller(); $inst.Updates = $coll
    $res = $inst.Install()
    $code = $res.GetUpdateResult(0).ResultCode   # 2 = succeeded, 3 = succeeded with errors
    [pscustomobject]@{ Ok = $code -in 2, 3; Code = $code; Reboot = [bool]$res.RebootRequired }
}

function Install-NvidiaDriver($item) {
    if (([uri]$item.Url).Host -notmatch '(^|\.)nvidia\.com$') { Say-Warn (M NvBadHost $item.Url); return [pscustomobject]@{ Ok = $false; Reboot = $false } }

    $dir = Join-Path $env:TEMP 'PC-Driver-Check'
    New-Item -ItemType Directory $dir -Force | Out-Null
    $file = Join-Path $dir ([IO.Path]::GetFileName(([uri]$item.Url).AbsolutePath))
    Say-Info (M Downloading "$($item.Latest) ($($item.SizeMB))")
    try { Start-BitsTransfer -Source $item.Url -Destination $file -DisplayName 'PC-Driver-Check' }
    catch { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest $item.Url -OutFile $file -UseBasicParsing }

    try {
        $sig = Get-AuthenticodeSignature $file
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O="?NVIDIA Corporation') {
            Say-Warn (M NvSigBad $file)
            return [pscustomobject]@{ Ok = $false; Reboot = $false }
        }
        Say-Info (M Installing "NVIDIA $($item.Latest)")
        Start-Process $file -ArgumentList '-s', '-noreboot', '-noeula' -Wait | Out-Null

        # Trust the installed version, not the installer's exit code
        $now = Get-CimInstance Win32_VideoController | Where-Object Name -eq $item.Gpu | Select-Object -First 1
        $nowVer = ConvertTo-NvidiaVersion $now.DriverVersion
        $ok = $nowVer -and ([version]$nowVer -ge [version]$item.Latest)
        if ($ok) { Say-Ok (M NvOk $item.Latest) } else { Say-Warn (M NvFail $nowVer $item.Latest) }
        [pscustomobject]@{ Ok = $ok; Reboot = $true }
    } finally {
        Remove-Item $file -Force -EA SilentlyContinue
    }
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Host (M NeedAdmin) -ForegroundColor Red; exit 1 }

$logDir = Join-Path $Root 'logs'
New-Item -ItemType Directory $logDir -Force | Out-Null
$logFile = Join-Path $logDir "PC-Driver-Check_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript $logFile | Out-Null

try {
    Write-Host (M Title) -ForegroundColor White

    # --- This PC (different on every machine, detected at runtime) ---
    Say-Head (M PcInfo)
    $cs  = Get-CimInstance Win32_ComputerSystem
    $os  = Get-CimInstance Win32_OperatingSystem
    $gpus = @(Get-CimInstance Win32_VideoController | Where-Object { $_.PNPDeviceID -match '^PCI\\' })
    Write-Host ("{0,-12} {1} {2}" -f (M Model), $cs.Manufacturer, $cs.Model)
    Write-Host ("{0,-12} {1} (build {2})" -f (M Os), $os.Caption, $os.BuildNumber)
    Write-Host ("{0,-12} {1}" -f (M Cpu), (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim())
    foreach ($g in $gpus) { Write-Host ("{0,-12} {1}  [{2}]" -f (M Gpu), $g.Name, $g.DriverVersion) }

    $items = @()

    # --- NVIDIA (official service) ---
    $nvGpus = @($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_10DE' } | Sort-Object Name -Unique)
    $nvChecked = $false
    foreach ($g in $nvGpus) {
        Say-Info (M NvCheck $g.Name)
        try {
            $r = Find-NvidiaDriver $g
            switch ($r.Status) {
                'Update'  { $items += $r; $nvChecked = $true }
                'Current' { Say-Ok (M NvUpToDate $g.Name $r.Installed); $nvChecked = $true }
                'NoMatch' { Say-Warn (M NvNoMatch $g.Name) }
            }
        } catch { Say-Warn (M NvFailed $_.Exception.Message) }
    }

    # --- Windows Update ---
    Say-Info (M WuScan)
    try {
        $wu = @(Find-WUDrivers)
        # NVIDIA's own service is newer; drop WU's NVIDIA display driver so it can't downgrade
        if ($nvChecked) { $wu = @($wu | Where-Object { -not ($_.Class -eq 'Display' -and $_.Manufacturer -match 'NVIDIA') }) }
        if (-not $IncludeDevices) {
            $acc = @($wu | Where-Object { Test-AccessoryDriver $_.Class $_.Title })
            if ($acc) { Say-Info (M WuHidden $acc.Count) }
            $wu = @($wu | Where-Object { -not (Test-AccessoryDriver $_.Class $_.Title) })
        }
        $items += $wu
    } catch { Say-Warn (M WuFailed $_.Exception.Message) }

    # --- List ---
    if (-not $items) { Say-Ok (M NoUpdates); return }
    Say-Head (M Found)
    for ($i = 0; $i -lt $items.Count; $i++) {
        $it = $items[$i]
        $date = if ($it.Date -is [datetime]) { $it.Date.ToString('yyyy-MM-dd') } else { $it.Date }
        $size = if ($it.SizeMB -isnot [double]) { $it.SizeMB }      # NVIDIA gives text, e.g. "1.04 GB"
                elseif ($it.SizeMB -lt 1) { '{0:N0} KB' -f [math]::Max(1, $it.SizeMB * 1024) }
                else { '{0:N1} MB' -f $it.SizeMB }
        Write-Host ("[{0}] {1}" -f ($i + 1), $it.Title) -ForegroundColor White
        Write-Host ("     {0} | {1} | {2} | {3}" -f $it.Source, $it.Class, $date, $size) -ForegroundColor DarkGray
    }
    if ($ScanOnly) { Say-Info (M ScanOnlyDone); return }

    # --- Confirm ---
    do {
        $sel = Read-Selection (Read-Host "`n$(M Ask)") $items.Count
        if ($null -eq $sel) { Say-Warn (M AskInvalid) }
    } while ($null -eq $sel)
    if ($sel.Count -eq 0) { Say-Info (M NothingChosen); return }
    $chosen = @($sel | ForEach-Object { $items[$_ - 1] })

    # --- Restore point ---
    Say-Info (M RpCreating)
    if (-not (New-RestorePoint)) {
        if ((Read-Host (M RpContinue)) -notmatch "^(?i)$(M YesWord)") { Say-Info (M Cancelled); return }
    }

    # --- Install ---
    $okList = @(); $failList = @(); $reboot = $false
    foreach ($it in $chosen) {
        try {
            $r = if ($it.Source -eq 'NVIDIA') { Install-NvidiaDriver $it } else { Install-WUDriver $it }
            if ($r.Reboot) { $reboot = $true }
            if ($r.Ok) { $okList += $it.Title; if ($it.Source -ne 'NVIDIA') { Say-Ok (M WuOk $it.Title) } }
            else { $failList += $it.Title; if ($it.Source -ne 'NVIDIA') { Say-Warn (M WuFail $it.Title $r.Code) } }
        } catch {
            $failList += $it.Title
            Say-Warn (M WuFail $it.Title $_.Exception.Message)
        }
    }

    # --- Summary ---
    Say-Head (M Summary)
    if ($okList)   { Say-Ok   (M SumOk ($okList.Count)) }
    if ($failList) { Say-Warn (M SumFail ($failList -join '; ')) }
    if ($reboot)   { Write-Host "`n$(M Reboot)" -ForegroundColor Red }
}
finally {
    Write-Host ""
    Say-Info (M Log $logFile)
    Stop-Transcript | Out-Null
}
