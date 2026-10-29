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

.PARAMETER NvidiaStudio
    Offer NVIDIA Studio drivers (for creative apps) instead of Game Ready drivers.
    A newer Game Ready driver that is already installed is never downgraded.

.PARAMETER NoBackup
    Do not back up the current drivers of the devices being updated
    (by default they are exported to %ProgramData%\PC-Driver-Check\backups).

.PARAMETER Install
    Install these list numbers without asking, e.g. "1,3" or "1-3". Numbers follow the
    list of this run, so for scheduled runs -All plus an ignore list is safer.

.PARAMETER All
    Install everything that is listed, without asking.

.PARAMETER Yes
    If no restore point can be created, continue anyway instead of asking (interactive)
    or cancelling (with -Install / -All).

.PARAMETER Report
    Also save a json or html report next to the log file.

.PARAMETER NoUpdateCheck
    Do not check GitHub for a newer version of this tool.

.NOTES
    Exit codes: 0 = done / nothing to do, 1 = error or incomplete scan,
                2 = some installs failed, 3010 = installed, restart required.
    Ignore list: PC-Driver-Check.config.json next to the script, e.g.
                { "ignore": [ "*ComputeAccelerator*" ] }   (title wildcards)

.EXAMPLE
    .\Check-Drivers.bat
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\PC-Driver-Check.ps1 -ScanOnly -Report html
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\PC-Driver-Check.ps1 -All -Report json
#>
param(
    [switch]$ScanOnly,
    [switch]$IncludeDevices,
    [switch]$NoBackup,
    [switch]$NvidiaStudio,
    [string]$Install,
    [switch]$All,
    [switch]$Yes,
    [ValidateSet('json', 'html')]
    [string]$Report,
    [switch]$NoUpdateCheck
)

# Must match the release tag (vX.Y.Z); the release workflow checks it
$Version = '1.0.0'
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
        Health         = 'Donanım sağlığı'
        DevNone        = 'Sorunlu aygıt yok.'
        DevProblem     = 'Sorunlu aygıt: {0} - {1}'
        DevId          = 'Donanım kimliği (sürücü aramak için): {0}'
        DevCode1       = 'yapılandırılmamış'
        DevCode10      = 'başlatılamıyor'
        DevCode18      = 'sürücü yeniden kurulmalı'
        DevCode28      = 'sürücü yüklü değil'
        DevCode31      = 'düzgün çalışmıyor'
        DevCode43      = 'Windows aygıtı durdurdu (aygıt sorun bildirdi)'
        DevCode52      = 'sürücü imzası doğrulanamadı'
        DevCodeOther   = 'hata kodu {0}'
        Ram            = 'RAM'
        RamLine        = '{0} GB {1}, {2}/{3} yuva dolu, {4} MT/s'
        RamSlow        = 'RAM desteklediği hızın altında çalışıyor ({0} / {1} MT/s). Masaüstünde BIOS''ta XMP/EXPO ayarına bakın; işlemci bu hızı desteklemiyorsa bu normaldir.'
        RamSingle      = 'Tek RAM modülü takılı (tek kanal). Boş yuvaya eş bir modül eklemek performansı artırabilir.'
        Disk           = 'Disk'
        DiskLine       = '{0} | {1} {2} | {3} GB | firmware {4}'
        DiskStats      = 'sağlık: {0} | aşınma: {1} | sıcaklık: {2}'
        DiskHealthy    = 'iyi'
        DiskWarning    = 'uyarı'
        DiskUnhealthy  = 'SAĞLIKSIZ'
        DiskBad        = '{0}: Windows diskin sağlıklı olmadığını bildiriyor ({1}). Verilerinizi hemen yedekleyin.'
        DiskErrors     = '{0}: {1} düzeltilemeyen okuma hatası. Verilerinizi yedekleyin.'
        DiskWearHigh   = '{0}: SSD ömrünün %{1} kadarı kullanılmış. Yedek alın ve değiştirmeyi planlayın.'
        DiskWearWarn   = '{0}: SSD ömrünün %{1} kadarı kullanılmış, takip edin.'
        DiskHot        = '{0}: disk sıcak ({1}°C). Havalandırmayı kontrol edin.'
        HealthFailed   = 'Donanım bilgisi okunamadı: {0}'
        Unknown        = 'bilinmiyor'
        WuScan        = 'Windows Update taranıyor (1-2 dakika sürebilir)...'
        WuFailed       = 'Windows Update taranamadı: {0}'
        WuHidden       = '{0} telefon/USB aygıtı sürücüsü gizlendi (göstermek için -IncludeDevices).'
        NvCheck        = 'NVIDIA sürücüsü kontrol ediliyor: {0}'
        NvUpToDate     = '{0}: güncel ({1})'
        NvNoMatch      = '{0}: model NVIDIA listesinde bulunamadı. nvidia.com/drivers adresinden elle kontrol edin.'
        NvNoVersion    = '{0}: kurulu sürücü sürümü okunamadı ({1}). nvidia.com/drivers adresinden elle kontrol edin.'
        NvFailed       = 'NVIDIA servisine ulaşılamadı: {0}'
        AmdCheck       = 'AMD sürücüsü kontrol ediliyor: {0}'
        AmdUpToDate    = '{0}: güncel (Adrenalin {1})'
        AmdUpdate      = '{0}: yeni sürüm var, Adrenalin {1} -> {2}. AMD Software içinden ya da amd.com/support adresinden kurun.'
        AmdNoVersion   = '{0}: kurulu Adrenalin sürümü okunamadı; en son sürüm {1}. amd.com/support adresinden kontrol edin.'
        AmdUnknownGpu  = '{0}: kartın nesli belirlenemedi. amd.com/support adresindeki otomatik algılama aracını kullanın.'
        AmdFailed      = 'AMD sitesinden sürüm okunamadı: {0}'
        AmdChipset     = 'AMD işlemci: yonga seti sürücüleri için amd.com/support (Windows Update''tekiler genelde daha eskidir).'
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
        ArgConflict    = 'Bu seçenekler birlikte kullanılamaz: {0}'
        InstallInvalid = '-Install "{0}" geçersiz (1-{1} arası numaralar, örnek: 1,3 veya 1-3).'
        Unattended     = 'Gözetimsiz kurulum, {0} güncelleme seçildi.'
        RpAbort        = 'Geri yükleme noktası olmadan gözetimsiz kurulum yapılmadı (yine de kurmak için -Yes).'
        Ignored        = '{0} güncelleme yoksayma listesinde olduğu için gizlendi ({1}).'
        ConfigBad      = 'Ayar dosyası okunamadı, yok sayıldı ({0}): {1}'
        ReportSaved    = 'Rapor: {0}'
        ReportFailed   = 'Rapor yazılamadı: {0}'
        ReportWarnings = 'Uyarılar'
        ReportIgnored  = 'Yoksayılanlar'
        ReportNone     = 'yok'
        NewVersion     = 'PC-Driver-Check''in yeni sürümü var: {0} (kullandığın: {1}). İndirmek için: {2}'
        BackupCreating = 'Güncellenecek aygıtların mevcut sürücüleri yedekleniyor...'
        BackupOk       = 'Sürücü yedeği ({1}): {0}'
        BackupHow      = 'Geri yüklemek için: pnputil /add-driver "{0}\*.inf" /subdirs /install'
        BackupNone     = 'Yedeklenecek üçüncü parti sürücü yok (aygıtlar Windows''un kendi sürücüsünü kullanıyor ya da henüz sürücüsü yok).'
        BackupNoSpace  = 'Sürücü yedeği atlandı: {0} sürücüsünde sadece {1} GB boş alan var.'
        BackupFailed   = 'Sürücü yedeği alınamadı ({0}); kuruluma devam ediliyor.'
        Installing     = 'Kuruluyor: {0}'
        Downloading    = 'İndiriliyor: {0}'
        WuOk           = 'Kuruldu: {0}'
        WuFail         = 'Kurulamadı: {0} (sonuç kodu {1})'
        WuDlFail       = 'İndirilemedi, kurulmadı: {0} (sonuç kodu {1})'
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
        Health         = 'Hardware health'
        DevNone        = 'No problem devices.'
        DevProblem     = 'Problem device: {0} - {1}'
        DevId          = 'Hardware ID (search this to find a driver): {0}'
        DevCode1       = 'not configured'
        DevCode10      = 'cannot start'
        DevCode18      = 'driver must be reinstalled'
        DevCode28      = 'no driver installed'
        DevCode31      = 'not working properly'
        DevCode43      = 'stopped by Windows (device reported a problem)'
        DevCode52      = 'driver signature could not be verified'
        DevCodeOther   = 'error code {0}'
        Ram            = 'RAM'
        RamLine        = '{0} GB {1}, {2}/{3} slots used, {4} MT/s'
        RamSlow        = 'RAM runs below its rated speed ({0} / {1} MT/s). On a desktop, check XMP/EXPO in the BIOS; if the CPU does not support that speed, this is normal.'
        RamSingle      = 'Only one RAM module installed (single channel). Adding a matching module to the free slot can improve performance.'
        Disk           = 'Disk'
        DiskLine       = '{0} | {1} {2} | {3} GB | firmware {4}'
        DiskStats      = 'health: {0} | wear: {1} | temperature: {2}'
        DiskHealthy    = 'good'
        DiskWarning    = 'warning'
        DiskUnhealthy  = 'UNHEALTHY'
        DiskBad        = '{0}: Windows reports the disk is not healthy ({1}). Back up your data now.'
        DiskErrors     = '{0}: {1} uncorrectable read error(s). Back up your data.'
        DiskWearHigh   = '{0}: {1}% of the SSD''s rated life is used. Back up and plan a replacement.'
        DiskWearWarn   = '{0}: {1}% of the SSD''s rated life is used, keep an eye on it.'
        DiskHot        = '{0}: disk is hot ({1}°C). Check the cooling.'
        HealthFailed   = 'Could not read hardware information: {0}'
        Unknown        = 'unknown'
        WuScan        = 'Scanning Windows Update (this can take 1-2 minutes)...'
        WuFailed       = 'Windows Update scan failed: {0}'
        WuHidden       = '{0} phone/USB accessory driver(s) hidden (use -IncludeDevices to show).'
        NvCheck        = 'Checking NVIDIA driver: {0}'
        NvUpToDate     = '{0}: up to date ({1})'
        NvNoMatch      = '{0}: model not found in NVIDIA''s list. Check nvidia.com/drivers manually.'
        NvNoVersion    = '{0}: could not read the installed driver version ({1}). Check nvidia.com/drivers manually.'
        NvFailed       = 'Could not reach NVIDIA''s service: {0}'
        AmdCheck       = 'Checking AMD driver: {0}'
        AmdUpToDate    = '{0}: up to date (Adrenalin {1})'
        AmdUpdate      = '{0}: newer version available, Adrenalin {1} -> {2}. Install it from AMD Software or amd.com/support.'
        AmdNoVersion   = '{0}: could not read the installed Adrenalin version; latest is {1}. Check amd.com/support.'
        AmdUnknownGpu  = '{0}: GPU generation not recognised. Use the auto-detect tool on amd.com/support.'
        AmdFailed      = 'Could not read the version from AMD''s site: {0}'
        AmdChipset     = 'AMD CPU: get chipset drivers from amd.com/support (the ones on Windows Update are usually older).'
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
        ArgConflict    = 'These options cannot be used together: {0}'
        InstallInvalid = '-Install "{0}" is not valid (numbers 1-{1}, e.g. 1,3 or 1-3).'
        Unattended     = 'Unattended install, {0} update(s) selected.'
        RpAbort        = 'No unattended install without a restore point (add -Yes to install anyway).'
        Ignored        = '{0} update(s) hidden by the ignore list ({1}).'
        ConfigBad      = 'Could not read the config file, ignoring it ({0}): {1}'
        ReportSaved    = 'Report: {0}'
        ReportFailed   = 'Could not write the report: {0}'
        ReportWarnings = 'Warnings'
        ReportIgnored  = 'Ignored'
        ReportNone     = 'none'
        NewVersion     = 'A newer PC-Driver-Check is available: {0} (you have {1}). Download: {2}'
        BackupCreating = 'Backing up the current drivers of the devices being updated...'
        BackupOk       = 'Driver backup ({1}): {0}'
        BackupHow      = 'To restore: pnputil /add-driver "{0}\*.inf" /subdirs /install'
        BackupNone     = 'No third-party drivers to back up (the devices use Windows'' own driver or have none yet).'
        BackupNoSpace  = 'Driver backup skipped: only {1} GB free on drive {0}.'
        BackupFailed   = 'Could not back up the drivers ({0}); continuing with the install.'
        Installing     = 'Installing: {0}'
        Downloading    = 'Downloading: {0}'
        WuOk           = 'Installed: {0}'
        WuFail         = 'Failed: {0} (result code {1})'
        WuDlFail       = 'Download failed, not installed: {0} (result code {1})'
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
function Say-Warn($m) {
    Write-Host "[!!] $m" -ForegroundColor Yellow
    if ($null -ne $script:WarnLog) { [void]$script:WarnLog.Add([string]$m) }   # for -Report
}
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

# NVIDIA's OS id (lookupValueSearch.aspx?TypeID=4): Windows 11 = 135, Windows 10 64-bit = 57
function Get-NvidiaOsId([int]$build) {
    if ($build -ge 22000) { 135 } else { 57 }
}

function Get-NormalizedGpuName([string]$name) {
    ($name -replace '^\s*NVIDIA\s+', '').Trim().ToLowerInvariant()
}

# Phone / USB accessory drivers: offered only because a phone was plugged in once.
# CultureInvariant: with -match, Turkish Windows would not match "MOBILE" to "Mobile" (I -> ı)
function Test-AccessoryDriver($driverClass, [string]$title) {
    ($driverClass -eq 'OtherHardware') -or
        [regex]::IsMatch($title, '\b(Android|Apple|iPhone|iPad|MTP|ADB|Mobile|Phone|Modem)\b', 'IgnoreCase, CultureInvariant')
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

# Release tag ("v1.2.0") is newer than this version. Unparsable tags are never "newer".
function Test-NewerRelease([string]$tag, [string]$current) {
    $t = $null; $c = $null
    [version]::TryParse(($tag -replace '^v', ''), [ref]$t) -and [version]::TryParse($current, [ref]$c) -and $t -gt $c
}

# Latest GitHub release of this tool, or $null (offline, no release yet, rate limit...).
# Only informs; never downloads anything.
function Find-LatestRelease {
    try {
        $r = Invoke-RestMethod 'https://api.github.com/repos/SelamiKalay/pc-driver-check/releases/latest' -UseBasicParsing -TimeoutSec 5
        [pscustomobject]@{ Tag = [string]$r.tag_name; Url = [string]$r.html_url }
    } catch { $null }
}

# Options that cannot be combined -> "-A, -B", or $null
function Get-ArgConflict([bool]$scanOnly, [string]$install, [bool]$all) {
    $set = @()
    if ($scanOnly) { $set += '-ScanOnly' }
    if ($install)  { $set += '-Install' }
    if ($all)      { $set += '-All' }
    if ($set.Count -gt 1) { $set -join ', ' }
}

# PC-Driver-Check.config.json: { "ignore": [ "*ComputeAccelerator*", ... ] }. Missing file = defaults;
# invalid JSON throws so the caller can say so instead of silently ignoring nothing.
function Read-Config([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return [pscustomobject]@{ Ignore = @() } }
    $c = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    [pscustomobject]@{ Ignore = @($c.ignore | Where-Object { $_ } | ForEach-Object { [string]$_ }) }
}

# Title matches an ignore pattern. WildcardPattern + CultureInvariant: plain -like is
# culture-sensitive ("INTEL" -like "*intel*" is false on Turkish Windows).
function Test-Ignored([string]$title, [string[]]$patterns) {
    foreach ($p in $patterns) {
        if ([Management.Automation.WildcardPattern]::new($p, 'IgnoreCase, CultureInvariant').IsMatch($title)) { return $true }
    }
    $false
}

# Report (New-Report shape) -> self-contained HTML page; every value is HTML-encoded
function ConvertTo-ReportHtml($r) {
    $e = { param($s) [Net.WebUtility]::HtmlEncode([string]$s) }
    $table = {
        param($rows, [string[]]$cols)
        $rows = @($rows | Where-Object { $_ })
        if (-not $rows) { return "<p class=""none"">$(& $e (M ReportNone))</p>" }
        $h = ($cols | ForEach-Object { "<th>$(& $e $_)</th>" }) -join ''
        $b = foreach ($row in $rows) { '<tr>' + (($cols | ForEach-Object { "<td>$(& $e $row.$_)</td>" }) -join '') + '</tr>' }
        "<table><tr>$h</tr>$($b -join '')</table>"
    }
    $list = { param($items) $items = @($items | Where-Object { $_ }); if (-not $items) { "<p class=""none"">$(& $e (M ReportNone))</p>" } else { '<ul>' + (($items | ForEach-Object { "<li>$(& $e $_)</li>" }) -join '') + '</ul>' } }
    @"
<!doctype html>
<html lang="$Lang"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>PC-Driver-Check $(& $e $r.Date)</title>
<style>
body { font: 14px/1.5 'Segoe UI', sans-serif; margin: 24px; color: #1b1b1b; background: #fff; }
h1 { font-size: 20px; } h2 { font-size: 16px; margin-top: 28px; border-bottom: 1px solid #ddd; }
table { border-collapse: collapse; margin: 8px 0; } th, td { border: 1px solid #ddd; padding: 4px 10px; text-align: left; }
th { background: #f3f3f3; } .none { color: #777; } li { margin: 2px 0; }
@media (prefers-color-scheme: dark) { body { background: #1e1e1e; color: #ddd; } th { background: #2b2b2b; } th, td, h2 { border-color: #444; } }
</style></head><body>
<h1>$(& $e (M Title))</h1>
<p>v$(& $e $r.Version) &middot; $(& $e $r.Date) &middot; exit code $(& $e $r.ExitCode)</p>
<h2>$(& $e (M PcInfo))</h2>
$(& $table @($r.Pc) @('Model', 'Windows', 'Cpu'))
$(& $table $r.Pc.Gpus @('Name', 'DriverVersion'))
<h2>$(& $e (M Health))</h2>
$(& $table @($r.Memory) @('TotalGB', 'Type', 'Count', 'Slots', 'Rated', 'Actual'))
$(& $table $r.Disks @('Name', 'Bus', 'Media', 'SizeGB', 'Firmware', 'Health', 'Wear', 'Temperature'))
$(& $table $r.ProblemDevices @('Name', 'Code', 'HardwareId'))
<h2>$(& $e (M Found))</h2>
$(& $table $r.Updates @('Source', 'Title', 'Class', 'Date', 'Size'))
<h2>$(& $e (M ReportIgnored))</h2>
$(& $list $r.Ignored)
<h2>$(& $e (M ReportWarnings))</h2>
$(& $list $r.Warnings)
<h2>$(& $e (M Summary))</h2>
<p>$(& $e (M SumOk (@($r.Installed).Count)))</p>
$(& $list $r.Installed)
$(if (@($r.Failed).Count) { "<p>$(& $e (M SumFail (@($r.Failed) -join '; ')))</p>" })
$(if ($r.RebootRequired) { "<p><strong>$(& $e (M Reboot))</strong></p>" })
</body></html>
"@
}

# AMD GPU name -> Adrenalin branch. RDNA (RX 5000-9000, Radeon 6x0M-8x0M iGPUs) share one
# release; Polaris / Vega (RX 400/500, Vega, Radeon VII) get a separate maintenance release.
# $null: generation unknown (e.g. "AMD Radeon(TM) Graphics" on many APUs).
function Get-AmdBranch([string]$name) {
    $opt = 'IgnoreCase, CultureInvariant'
    # Suffixes: M / S laptop (RX 6600M, RX 7600S), X refresh (RX 560X)
    if ([regex]::IsMatch($name, '\bRX\s*[5-9]\d{3}[MS]?\b', $opt) -or [regex]::IsMatch($name, '\bRadeon\b.*\b[678]\d0M\b', $opt)) { return 'Mainline' }
    if ([regex]::IsMatch($name, '\bRX\s*[45]\d0X?\b|\bVega\b|\bRadeon VII\b', $opt)) { return 'Legacy' }
    $null
}

# WU driver manufacturer is AMD. Whole words: "ATI" must not match "NVIDIA Corporation".
function Test-AmdVendor([string]$manufacturer) {
    [regex]::IsMatch($manufacturer, '\b(AMD|Advanced Micro Devices|ATI)\b', 'IgnoreCase, CultureInvariant')
}

# amd.com driver page HTML -> newest Adrenalin version in its installer file names
function Get-AdrenalinLatest([string]$html) {
    [regex]::Matches($html, 'whql-amd-software-adrenalin-edition-(\d+\.\d+\.\d+)') |
        ForEach-Object { [version]$_.Groups[1].Value } | Sort-Object -Descending | Select-Object -First 1 |
        ForEach-Object { $_.ToString() }
}

# Device Manager error code -> message key (22 = disabled, 45 = not plugged in: not shown at all)
function Get-DeviceProblemKey([int]$code) {
    if ($code -in 1, 10, 18, 28, 31, 43, 52) { "DevCode$code" } else { 'DevCodeOther' }
}

# SMBIOS memory type -> name
function ConvertTo-MemoryType([int]$type) {
    switch ($type) {
        24 { 'DDR3' } 26 { 'DDR4' } 29 { 'LPDDR3' } 30 { 'LPDDR4' } 34 { 'DDR5' } 35 { 'LPDDR5' }
        default { '' }
    }
}

# Win32_PhysicalMemory modules + slot count -> one summary
function Get-MemorySummary($modules, [int]$slots) {
    $modules = @($modules)
    $rated = [int]($modules | Measure-Object Speed -Maximum).Maximum
    $actual = [int](@($modules | Where-Object { $_.ConfiguredClockSpeed -gt 0 }) | Measure-Object ConfiguredClockSpeed -Minimum).Minimum
    [pscustomobject]@{
        TotalGB = [math]::Round(($modules | Measure-Object Capacity -Sum).Sum / 1GB)
        Type    = ConvertTo-MemoryType @($modules)[0].SMBIOSMemoryType
        Count   = $modules.Count
        Slots   = [math]::Max($slots, $modules.Count)
        Rated   = $rated
        Actual  = $actual
        Slow    = $actual -gt 0 -and $rated -gt 0 -and $actual -lt $rated
        Single  = $modules.Count -eq 1 -and $slots -ge 2
    }
}

# Disk (Get-DiskInfo shape) -> list of @{ Key; Args } warnings, most serious first.
# 0 / missing counters mean "not reported" (common on SATA and USB disks), not "perfect".
function Get-DiskWarnings($disk) {
    # Wear is the NVMe "percentage used" (100 = rated life reached, can go above)
    $wearCritical = 90
    $wearWarn     = 70
    $tempWarn     = 70   # °C; most NVMe drives start throttling around 70-80
    $w = @()
    if ($disk.Health -and $disk.Health -ne 'Healthy') { $w += @{ Key = 'DiskBad'; Args = @($disk.Name, $disk.Health) } }
    if ($disk.ReadErrors -gt 0) { $w += @{ Key = 'DiskErrors'; Args = @($disk.Name, $disk.ReadErrors) } }
    if ($disk.Wear -ge $wearCritical) { $w += @{ Key = 'DiskWearHigh'; Args = @($disk.Name, $disk.Wear) } }
    elseif ($disk.Wear -ge $wearWarn) { $w += @{ Key = 'DiskWearWarn'; Args = @($disk.Name, $disk.Wear) } }
    if ($disk.Temperature -ge $tempWarn) { $w += @{ Key = 'DiskHot'; Args = @($disk.Name, $disk.Temperature) } }
    ,$w
}

# Updates about to be installed -> oem*.inf packages their devices use now.
# WU items carry the hardware ID they target, NVIDIA items the GPU's device ID.
# Inbox drivers (e.g. hdaudbus.inf) are part of Windows and cannot be exported.
function Get-BackupInfNames($chosen, $entities, $signed) {
    $ids = @($chosen | ForEach-Object { $_.DeviceId } | Where-Object { $_ })
    $hw = @($chosen | ForEach-Object { $_.HardwareId } | Where-Object { $_ })
    if ($hw) {
        $ids += @($entities | Where-Object { @(@($_.HardwareID) + @($_.CompatibleID) | Where-Object { $_ -in $hw }).Count } |
            ForEach-Object { $_.DeviceID })
    }
    # Lower-case first, then -cmatch: a plain -match on "OEM12.INF" fails on Turkish Windows (I -> ı)
    ,@($signed | Where-Object { $_.DeviceID -in $ids } | ForEach-Object { ([string]$_.InfName).ToLowerInvariant() } |
        Where-Object { $_ -cmatch '^oem\d+\.inf$' } | Sort-Object -Unique)
}

# Backup folder may only be owned / writable by SYSTEM and Administrators. Standard users can
# create folders under %ProgramData%, and the backup is written and cleaned up with admin
# rights, so a folder or junction planted there could redirect that delete.
# $rules: FileSystemAccessRule list with SecurityIdentifier identities.
function Test-TrustedAcl([string]$ownerSid, $rules) {
    $trusted = 'S-1-5-18', 'S-1-5-32-544'   # SYSTEM, Administrators
    # WriteData, AppendData, WriteEA, DeleteChild, WriteAttributes, Delete, WRITE_DAC, WRITE_OWNER, GENERIC_ALL, GENERIC_WRITE
    $writeMask = 0x2 -bor 0x4 -bor 0x10 -bor 0x40 -bor 0x100 -bor 0x10000 -bor 0x40000 -bor 0x80000 -bor 0x10000000 -bor 0x40000000
    if ($ownerSid -notin $trusted) { return $false }
    -not @($rules | Where-Object {
        # GENERIC_ALL (CREATOR OWNER) is not a named FileSystemRights value: never cast numbers to the enum
        $mask = if ($_.FileSystemRights -is [string]) { [int64][Security.AccessControl.FileSystemRights]$_.FileSystemRights } else { [int64]$_.FileSystemRights }
        [string]$_.AccessControlType -eq 'Allow' -and ($mask -band $writeMask) -and [string]$_.IdentityReference -notin $trusted
    }).Count
}

# ------------------------------------------------------------------
# Hardware health (read-only)
# ------------------------------------------------------------------
function Get-ProblemDevices {
    Get-CimInstance Win32_PnPEntity |
        Where-Object { $_.ConfigManagerErrorCode -notin 0, 22, 45 -and $_.Present -ne $false } |
        ForEach-Object {
            [pscustomobject]@{
                Name       = if ($_.Name) { $_.Name } else { $_.DeviceID }
                Code       = [int]$_.ConfigManagerErrorCode
                HardwareId = @($_.HardwareID)[0]
            }
        }
}

function Get-MemoryInfo {
    $slots = (Get-CimInstance Win32_PhysicalMemoryArray | Measure-Object MemoryDevices -Sum).Sum
    Get-MemorySummary (Get-CimInstance Win32_PhysicalMemory) $slots
}

function Get-DiskInfo {
    foreach ($d in Get-PhysicalDisk) {
        $rel = $d | Get-StorageReliabilityCounter -EA SilentlyContinue
        [pscustomobject]@{
            Name        = $d.FriendlyName
            Media       = [string]$d.MediaType
            Bus         = [string]$d.BusType
            SizeGB      = [math]::Round($d.Size / 1e9)   # decimal GB, as printed on the box
            Firmware    = $d.FirmwareVersion
            Health      = [string]$d.HealthStatus
            Wear        = $rel.Wear
            Temperature = $rel.Temperature
            ReadErrors  = $rel.ReadErrorsUncorrected
        }
    }
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
            HardwareId   = $u.DriverHardwareID
            Update       = $u
        }
    }
}

# Installed AMD Software (Adrenalin) version, e.g. "26.5.1", or $null
function Get-AdrenalinVersion {
    $v = (Get-ItemProperty 'HKLM:\SOFTWARE\AMD\CN' -EA SilentlyContinue).RadeonSoftwareVersion
    if (-not $v) {
        $v = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA SilentlyContinue |
            Where-Object { $_.DisplayName -like 'AMD Software*' } | Select-Object -ExpandProperty DisplayVersion -First 1
    }
    if ("$v" -match '^\d+\.\d+\.\d+') { $Matches[0] }
}

# Information only: AMD has no public driver API, and its download server rejects direct links.
# The latest version is read from a reference product page of the GPU's branch.
function Find-AmdDriver($gpu, [string]$installed) {
    $branch = Get-AmdBranch $gpu.Name
    if (-not $branch) { return [pscustomobject]@{ Status = 'UnknownGpu'; Gpu = $gpu.Name } }
    $page = 'https://www.amd.com/en/support/downloads/drivers.html/graphics/radeon-rx/' +
        $(if ($branch -eq 'Legacy') { 'radeon-rx-vega-series/radeon-rx-vega-64.html' } else { 'radeon-rx-7000-series/amd-radeon-rx-7900-xtx.html' })
    $latest = Get-AdrenalinLatest (Invoke-WebRequest $page -UseBasicParsing).Content
    if (-not $latest) { throw "no Adrenalin version found on $page" }
    $status = if (-not $installed) { 'NoVersion' } elseif ([version]$latest -gt [version]$installed) { 'Update' } else { 'Current' }
    [pscustomobject]@{ Status = $status; Gpu = $gpu.Name; Branch = $branch; Installed = $installed; Latest = $latest }
}

# $studio: NVIDIA Studio instead of Game Ready. The service returns Studio drivers only with
# isWHQL=0 + upCRD=1 (isWHQL=1 + upCRD=1 comes back empty); they are still signature-checked.
function Find-NvidiaDriver($gpu, [int]$osId, [switch]$studio) {
    $installed = ConvertTo-NvidiaVersion $gpu.DriverVersion
    if (-not $installed) { return [pscustomobject]@{ Status = 'NoVersion'; Gpu = $gpu.Name; Raw = $gpu.DriverVersion } }
    $products = [xml](Invoke-WebRequest 'https://www.nvidia.com/Download/API/lookupValueSearch.aspx?TypeID=3' -UseBasicParsing).Content
    $want = Get-NormalizedGpuName $gpu.Name
    $match = $products.LookupValueSearch.LookupValues.LookupValue |
        Where-Object { (Get-NormalizedGpuName $_.Name) -eq $want } | Select-Object -First 1
    if (-not $match) { return [pscustomobject]@{ Status = 'NoMatch'; Gpu = $gpu.Name } }

    $url = 'https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php' +
           "?func=DriverManualLookup&psid=$($match.ParentID)&pfid=$($match.Value)&osID=$osId&languageCode=1033&dch=1&sort1=0&numberOfResults=1" +
           $(if ($studio) { '&isWHQL=0&upCRD=1' } else { '&isWHQL=1&upCRD=0' })
    $resp = Invoke-RestMethod $url -UseBasicParsing
    if ($resp -is [string]) { $resp = $resp | ConvertFrom-Json }   # served as text/html
    $info = @($resp.IDS)[0].downloadInfo
    $latest = [string]$info.Version
    if ($latest -notmatch '^\d+\.\d+$') { return [pscustomobject]@{ Status = 'NoMatch'; Gpu = $gpu.Name } }   # no driver for this GPU/OS
    # Never install a Game Ready driver when Studio was asked for (e.g. if the service ignored upCRD)
    $name = [uri]::UnescapeDataString([string]$info.Name)
    if ($studio -and $name -notmatch 'Studio') { return [pscustomobject]@{ Status = 'NoMatch'; Gpu = $gpu.Name } }

    [pscustomobject]@{
        Status    = if ([version]$latest -gt [version]$installed) { 'Update' } else { 'Current' }
        Source    = 'NVIDIA'
        Gpu       = $gpu.Name
        DeviceId  = $gpu.PNPDeviceID
        Installed = $installed
        Latest    = $latest
        Title     = "$($gpu.Name)  $installed -> $latest$(if ($studio) { ' (Studio)' })"
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

# Creates %ProgramData%\PC-Driver-Check locked to SYSTEM + Administrators, or checks that an
# existing one still is. Throws (backup is skipped) instead of using a folder it cannot trust.
function Initialize-BackupRoot([string]$root) {
    $admins = [Security.Principal.SecurityIdentifier]'S-1-5-32-544'
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory $root | Out-Null
        $acl = New-Object Security.AccessControl.DirectorySecurity
        $acl.SetOwner($admins)
        $acl.SetAccessRuleProtection($true, $false)   # no inherited "Users: create folders"
        foreach ($sid in 'S-1-5-18', 'S-1-5-32-544') {
            $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule(
                [Security.Principal.SecurityIdentifier]$sid, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')))
        }
        Set-Acl -LiteralPath $root $acl
        # Anything that appeared before Set-Acl was not created by us
        if (Get-ChildItem -LiteralPath $root -Force) { throw "unexpected content in new folder $root" }
    }
    $item = Get-Item -LiteralPath $root -Force
    $acl = Get-Acl -LiteralPath $root
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        -not (Test-TrustedAcl $owner $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))) {
        throw "$root is not protected (owner $owner); delete it or restrict it to Administrators"
    }
}

# Exports the given oem*.inf packages with pnputil. Not next to the script: that folder may be
# synced (OneDrive Desktop) and an NVIDIA package alone is ~3 GB.
function New-DriverBackup([string[]]$infNames) {
    $root = Join-Path $env:ProgramData 'PC-Driver-Check'
    Initialize-BackupRoot $root
    $base = Join-Path $root 'backups'
    $drive = Get-PSDrive ($base.Substring(0, 1))
    $freeGB = [math]::Round($drive.Free / 1GB, 1)
    if ($freeGB -lt 10) { Say-Warn (M BackupNoSpace "$($drive.Name):" $freeGB); return }

    $dir = Join-Path $base (Get-Date -Format 'yyyyMMdd_HHmmss')
    foreach ($inf in $infNames) {
        $out = Join-Path $dir ($inf -replace '\.inf$')   # one folder per package: no file name clashes
        New-Item -ItemType Directory $out -Force | Out-Null
        $text = & pnputil.exe /export-driver $inf $out 2>&1
        if ($LASTEXITCODE -ne 0) { throw "pnputil $inf ($LASTEXITCODE): $(($text | Select-Object -Last 1))" }
    }
    $size = (Get-ChildItem $dir -Recurse -File | Measure-Object Length -Sum).Sum
    Say-Ok (M BackupOk $dir $(if ($size -ge 1GB) { '{0:N1} GB' -f ($size / 1GB) } else { '{0:N0} MB' -f ($size / 1MB) }))
    Say-Info (M BackupHow $dir)

    # Keep the two newest backups; each can be several GB. Only our own yyyyMMdd_HHmmss
    # folders, never a junction / symlink (Remove-Item -Recurse could follow it).
    Get-ChildItem -LiteralPath $base -Directory -Force |
        Where-Object { $_.Name -match '^\d{8}_\d{6}$' -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |
        Sort-Object Name -Descending | Select-Object -Skip 2 |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -EA SilentlyContinue }
}

function Install-WUDriver($item) {
    $session = New-Object -ComObject Microsoft.Update.Session
    $coll = New-Object -ComObject Microsoft.Update.UpdateColl
    if (-not $item.Update.EulaAccepted) { $item.Update.AcceptEula() }
    [void]$coll.Add($item.Update)

    Say-Info (M Downloading $item.Title)
    $dl = $session.CreateUpdateDownloader(); $dl.Updates = $coll
    $dlCode = $dl.Download().ResultCode
    if ($dlCode -notin 2, 3) { return [pscustomobject]@{ Ok = $false; Code = $dlCode; Stage = 'Download'; Reboot = $false } }
    Say-Info (M Installing $item.Title)
    $inst = $session.CreateUpdateInstaller(); $inst.Updates = $coll
    $res = $inst.Install()
    $code = $res.GetUpdateResult(0).ResultCode   # 2 = succeeded, 3 = succeeded with errors
    [pscustomobject]@{ Ok = $code -in 2, 3; Code = $code; Stage = 'Install'; Reboot = [bool]$res.RebootRequired }
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
$exitCode = 0
$WarnLog = New-Object Collections.Generic.List[string]   # not $Warnings: names are case-insensitive, $warnings is used below
$unattended = $All -or $Install
$okList = @(); $failList = @(); $reboot = $false; $ignored = @()

try {
    Write-Host "$(M Title)  v$Version" -ForegroundColor White
    $conflict = Get-ArgConflict $ScanOnly $Install $All
    if ($conflict) { Say-Warn (M ArgConflict $conflict); $exitCode = 1; return }

    if (-not $NoUpdateCheck) {
        $rel = Find-LatestRelease
        # Only https links on github.com are printed; anything else from the API is ignored
        if ($rel -and (Test-NewerRelease $rel.Tag $Version) -and $rel.Url -match '^https://github\.com/') {
            Say-Info (M NewVersion $rel.Tag $Version $rel.Url)
        }
    }

    $cfgPath = Join-Path $Root 'PC-Driver-Check.config.json'
    try { $config = Read-Config $cfgPath }
    catch { Say-Warn (M ConfigBad (Split-Path $cfgPath -Leaf) $_.Exception.Message); $config = [pscustomobject]@{ Ignore = @() } }

    # --- This PC (different on every machine, detected at runtime) ---
    Say-Head (M PcInfo)
    $cs  = Get-CimInstance Win32_ComputerSystem
    $os  = Get-CimInstance Win32_OperatingSystem
    $gpus = @(Get-CimInstance Win32_VideoController | Where-Object { $_.PNPDeviceID -match '^PCI\\' })
    Write-Host ("{0,-12} {1} {2}" -f (M Model), $cs.Manufacturer, $cs.Model)
    Write-Host ("{0,-12} {1} (build {2})" -f (M Os), $os.Caption, $os.BuildNumber)
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    Write-Host ("{0,-12} {1}" -f (M Cpu), $cpu.Name.Trim())
    foreach ($g in $gpus) { Write-Host ("{0,-12} {1}  [{2}]" -f (M Gpu), $g.Name, $g.DriverVersion) }

    # --- Hardware health (information only, never changes anything) ---
    Say-Head (M Health)
    try {
        $mem = Get-MemoryInfo
        $disks = @(Get-DiskInfo)
        Write-Host ("{0,-12} {1}" -f (M Ram), (M RamLine $mem.TotalGB $mem.Type $mem.Count $mem.Slots $mem.Actual))
        if ($mem.Slow)   { Say-Warn (M RamSlow $mem.Actual $mem.Rated) }
        if ($mem.Single) { Say-Info (M RamSingle) }

        foreach ($d in $disks) {
            $health = switch ($d.Health) { 'Healthy' { M DiskHealthy } 'Warning' { M DiskWarning } 'Unhealthy' { M DiskUnhealthy } default { M Unknown } }
            $wear = if ($null -ne $d.Wear -and ($d.Wear -gt 0 -or $d.Bus -eq 'NVMe')) { "%$($d.Wear)" } else { M Unknown }
            $temp = if ($d.Temperature -gt 0) { "$($d.Temperature)°C" } else { M Unknown }
            Write-Host ("{0,-12} {1}" -f (M Disk), (M DiskLine $d.Name $d.Bus $d.Media $d.SizeGB $d.Firmware))
            Write-Host ("{0,-12} {1}" -f '', (M DiskStats $health $wear $temp)) -ForegroundColor DarkGray
            $warnings = Get-DiskWarnings $d   # assign first: foreach over the call would not unroll ,@()
            foreach ($w in $warnings) { $a = $w.Args; Say-Warn (M $w.Key @a) }
        }

        $devs = @(Get-ProblemDevices)
        if (-not $devs) { Say-Ok (M DevNone) }
        foreach ($dev in $devs) {
            Say-Warn (M DevProblem $dev.Name (M (Get-DeviceProblemKey $dev.Code) $dev.Code))
            if ($dev.HardwareId) { Write-Host "     $(M DevId $dev.HardwareId)" -ForegroundColor DarkGray }
        }
    } catch { Say-Warn (M HealthFailed $_.Exception.Message) }

    $items = @()

    # --- NVIDIA (official service) ---
    $nvGpus = @($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_10DE' } | Sort-Object Name -Unique)
    $nvOsId = Get-NvidiaOsId $os.BuildNumber
    $nvChecked = $false
    foreach ($g in $nvGpus) {
        Say-Info (M NvCheck "$($g.Name)$(if ($NvidiaStudio) { ' (Studio)' })")
        try {
            $r = Find-NvidiaDriver $g $nvOsId -studio:$NvidiaStudio
            switch ($r.Status) {
                'Update'    { $items += $r; $nvChecked = $true }
                'Current'   { Say-Ok (M NvUpToDate $g.Name $r.Installed); $nvChecked = $true }
                'NoMatch'   { Say-Warn (M NvNoMatch $g.Name) }
                'NoVersion' { Say-Warn (M NvNoVersion $g.Name $r.Raw) }
            }
        } catch { Say-Warn (M NvFailed $_.Exception.Message); $exitCode = 1 }
    }

    # --- AMD (information only, see Find-AmdDriver) ---
    if ($cpu.Manufacturer -eq 'AuthenticAMD') { Say-Info (M AmdChipset) }
    $amdGpus = @($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_1002' } | Sort-Object Name -Unique)
    $amdCurrent = $false
    if ($amdGpus) { $adrenalin = Get-AdrenalinVersion }
    foreach ($g in $amdGpus) {
        Say-Info (M AmdCheck $g.Name)
        try {
            $r = Find-AmdDriver $g $adrenalin
            switch ($r.Status) {
                'Current'    { Say-Ok (M AmdUpToDate $g.Name $r.Installed); $amdCurrent = $true }
                'Update'     { Say-Warn (M AmdUpdate $g.Name $r.Installed $r.Latest) }
                'NoVersion'  { Say-Warn (M AmdNoVersion $g.Name $r.Latest) }
                'UnknownGpu' { Say-Warn (M AmdUnknownGpu $g.Name) }
            }
        } catch { Say-Warn (M AmdFailed $_.Exception.Message); $exitCode = 1 }
    }

    # --- Windows Update ---
    Say-Info (M WuScan)
    try {
        $wu = @(Find-WUDrivers)
        # NVIDIA's own service is newer; drop WU's NVIDIA display driver so it can't downgrade
        if ($nvChecked) { $wu = @($wu | Where-Object { -not ($_.Class -eq 'Display' -and $_.Manufacturer -match 'NVIDIA') }) }
        # Adrenalin is already the newest: WU's AMD display driver could only swap it for an older OEM package
        if ($amdCurrent) { $wu = @($wu | Where-Object { -not ($_.Class -eq 'Display' -and (Test-AmdVendor $_.Manufacturer)) }) }
        if (-not $IncludeDevices) {
            $acc = @($wu | Where-Object { Test-AccessoryDriver $_.Class $_.Title })
            if ($acc) { Say-Info (M WuHidden $acc.Count) }
            $wu = @($wu | Where-Object { -not (Test-AccessoryDriver $_.Class $_.Title) })
        }
        $items += $wu
    } catch { Say-Warn (M WuFailed $_.Exception.Message); $exitCode = 1 }

    # --- Ignore list (PC-Driver-Check.config.json) ---
    if ($config.Ignore) {
        $ignored = @($items | Where-Object { Test-Ignored $_.Title $config.Ignore })
        if ($ignored) {
            Say-Info (M Ignored $ignored.Count (Split-Path $cfgPath -Leaf))
            $items = @($items | Where-Object { -not (Test-Ignored $_.Title $config.Ignore) })
        }
    }

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

    # --- Confirm (or -Install / -All) ---
    if ($unattended) {
        $sel = if ($All) { ,@(1..$items.Count) } else { Read-Selection $Install $items.Count }
        if ($null -eq $sel -or $sel.Count -eq 0) { Say-Warn (M InstallInvalid $Install $items.Count); $exitCode = 1; return }
        Say-Info (M Unattended $sel.Count)
    } else {
        do {
            $sel = Read-Selection (Read-Host "`n$(M Ask)") $items.Count
            if ($null -eq $sel) { Say-Warn (M AskInvalid) }
        } while ($null -eq $sel)
        if ($sel.Count -eq 0) { Say-Info (M NothingChosen); return }
    }
    $chosen = @($sel | ForEach-Object { $items[$_ - 1] })

    # --- Restore point ---
    Say-Info (M RpCreating)
    if (-not (New-RestorePoint) -and -not $Yes) {
        # Unattended: nobody to ask, and installing without a safety net is not a default
        if ($unattended) { Say-Warn (M RpAbort); $exitCode = 1; return }
        if ((Read-Host (M RpContinue)) -notmatch "^(?i)$(M YesWord)") { Say-Info (M Cancelled); return }
    }

    # --- Driver backup (second safety net next to the restore point) ---
    if (-not $NoBackup) {
        Say-Info (M BackupCreating)
        try {
            $infs = Get-BackupInfNames $chosen (Get-CimInstance Win32_PnPEntity) (Get-CimInstance Win32_PnPSignedDriver)
            if ($infs.Count) { New-DriverBackup $infs } else { Say-Info (M BackupNone) }
        } catch { Say-Warn (M BackupFailed $_.Exception.Message) }
    }

    # --- Install ---
    foreach ($it in $chosen) {
        try {
            $r = if ($it.Source -eq 'NVIDIA') { Install-NvidiaDriver $it } else { Install-WUDriver $it }
            if ($r.Reboot) { $reboot = $true }
            if ($r.Ok) { $okList += $it.Title; if ($it.Source -ne 'NVIDIA') { Say-Ok (M WuOk $it.Title) } }
            else {
                $failList += $it.Title
                if ($it.Source -ne 'NVIDIA') { Say-Warn (M $(if ($r.Stage -eq 'Download') { 'WuDlFail' } else { 'WuFail' }) $it.Title $r.Code) }
            }
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
    if ($failList) { $exitCode = 2 } elseif ($reboot -and $exitCode -eq 0) { $exitCode = 3010 }
}
catch {
    Say-Warn $_.Exception.Message
    $exitCode = 1
}
finally {
    # Written here so -ScanOnly, "nothing to do" and errors also get a report
    if ($Report) {
        try {
            $data = [ordered]@{
                Version        = $Version
                Date           = Get-Date -Format 's'
                ExitCode       = $exitCode
                Pc             = [ordered]@{
                    Model   = "$($cs.Manufacturer) $($cs.Model)".Trim()
                    Windows = "$($os.Caption) (build $($os.BuildNumber))"
                    Cpu     = "$($cpu.Name)".Trim()
                    Gpus    = @($gpus | ForEach-Object { [ordered]@{ Name = $_.Name; DriverVersion = $_.DriverVersion } })
                }
                Memory         = $mem
                Disks          = @($disks)
                ProblemDevices = @($devs)
                Updates        = @($items | ForEach-Object {
                    [ordered]@{ Source = $_.Source; Title = $_.Title; Class = $_.Class
                                Date = $(if ($_.Date -is [datetime]) { $_.Date.ToString('yyyy-MM-dd') } else { [string]$_.Date })
                                Size = $(if ($_.SizeMB -is [double]) { '{0:N1} MB' -f $_.SizeMB } else { [string]$_.SizeMB }) } })
                Ignored        = @($ignored | ForEach-Object { $_.Title })
                Warnings       = @($WarnLog)
                Installed      = @($okList)
                Failed         = @($failList)
                RebootRequired = $reboot
            }
            $reportFile = [IO.Path]::ChangeExtension($logFile, $Report)
            $text = if ($Report -eq 'json') { $data | ConvertTo-Json -Depth 5 } else { ConvertTo-ReportHtml $data }
            [IO.File]::WriteAllText($reportFile, $text, (New-Object Text.UTF8Encoding $false))
            Say-Info (M ReportSaved $reportFile)
        } catch { Say-Warn (M ReportFailed $_.Exception.Message) }
    }
    Write-Host ""
    Say-Info (M Log $logFile)
    Stop-Transcript | Out-Null
    # Inside finally so the early 'return's above still report a code
    exit $exitCode
}
