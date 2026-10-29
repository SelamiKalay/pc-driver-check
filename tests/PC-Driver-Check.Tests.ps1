# Cevrimdisi birim testleri: yonetici izni, ag ve Windows Update gerektirmez.
# Calistirma: powershell -ExecutionPolicy Bypass -File tests\PC-Driver-Check.Tests.ps1
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '..\PC-Driver-Check.ps1'

# Kullanicilarin cogu Turkce Windows'ta: buyuk/kucuk harf duyarsiz regex orada I'yi i'ye degil noktasiz i'ye cevirir
# ("OEM12.INF" -match "oem\d+\.inf" false olur). CI en-US oldugu icin testler hep tr-TR ile calisir.
[Threading.Thread]::CurrentThread.CurrentCulture = 'tr-TR'

$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$errors)
if ($errors.Count) { $errors | ForEach-Object { Write-Host "PARSE: $_" }; exit 1 }

# Ana akis yonetici izni ister ve araci calistirir; sadece fonksiyonlar ve $Msg sozlugu yuklenir
$ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) |
    ForEach-Object { . ([scriptblock]::Create($_.Extent.Text)) }
$msgAst = $ast.Find({ $args[0] -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                      $args[0].Left.Extent.Text -eq '$Msg' }, $false)
. ([scriptblock]::Create($msgAst.Extent.Text))

$fail = 0
function Check($name, $got, $want) {
    $ok = ($got -join ',') -eq ($want -join ',')
    if (-not $ok) { $script:fail++ }
    Write-Host ("{0} {1,-40} got=[{2}] want=[{3}]" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, ($got -join ','), ($want -join ','))
}

Write-Host "PowerShell $($PSVersionTable.PSVersion), culture $([Threading.Thread]::CurrentThread.CurrentCulture.Name)"

Write-Host '--- ConvertTo-NvidiaVersion'
Check '32.0.16.2101' (ConvertTo-NvidiaVersion '32.0.16.2101') '621.01'
Check '31.0.15.5222' (ConvertTo-NvidiaVersion '31.0.15.5222') '552.22'
Check '31.0.15.601 (short last part)' (ConvertTo-NvidiaVersion '31.0.15.601') '506.01'
Check '27.21.14.5671' (ConvertTo-NvidiaVersion '27.21.14.5671') '456.71'

Write-Host '--- Get-NormalizedGpuName'
Check 'NVIDIA GeForce RTX 4070' (Get-NormalizedGpuName 'NVIDIA GeForce RTX 4070') 'geforce rtx 4070'
Check 'GeForce RTX 4070 Laptop GPU' (Get-NormalizedGpuName 'GeForce RTX 4070 Laptop GPU') 'geforce rtx 4070 laptop gpu'

Write-Host '--- Test-AccessoryDriver'
Check 'Android (OtherHardware)' (Test-AccessoryDriver 'OtherHardware' 'SAMSUNG AndroidUsbDeviceClass Driver Update') $true
Check 'Apple USB' (Test-AccessoryDriver 'USB' 'Apple, Inc. USBDevice Driver Update') $true
Check 'Intel ComputeAccelerator' (Test-AccessoryDriver 'ComputeAccelerator' 'Intel Corporation ComputeAccelerator Driver Update') $false
Check 'Realtek audio extension' (Test-AccessoryDriver 'MEDIA' 'Realtek Semiconductor Corp. Extension') $false
Check 'upper-case MOBILE (Turkish I)' (Test-AccessoryDriver 'USB' 'ACME MOBILE COMPOSITE DEVICE') $true

Write-Host '--- Read-Selection'
Check '"1,3" of 5' (Read-Selection '1,3' 5) @(1, 3)
Check '"1-3" of 5' (Read-Selection '1-3' 5) @(1, 2, 3)
Check '"T" of 3' (Read-Selection 'T' 3) @(1, 2, 3)
Check '"a" of 2' (Read-Selection 'a' 2) @(1, 2)
Check '"3, 1 3" (duplicates/spaces)' (Read-Selection '3, 1 3' 5) @(1, 3)
Check 'empty -> none' (Read-Selection '' 5).Count 0
Check '"9" of 5 -> invalid' ($null -eq (Read-Selection '9' 5)) $true
Check '"abc" -> invalid' ($null -eq (Read-Selection 'abc' 5)) $true
Check '"0" -> invalid' ($null -eq (Read-Selection '0' 5)) $true
Check '"2-0" reversed range -> invalid' ($null -eq (Read-Selection '2-0' 5)) $true

Write-Host '--- Get-NvidiaOsId'
Check 'build 26100 -> Windows 11' (Get-NvidiaOsId 26100) 135
Check 'build 22000 -> Windows 11' (Get-NvidiaOsId 22000) 135
Check 'build 19045 -> Windows 10' (Get-NvidiaOsId 19045) 57

Write-Host '--- ConvertTo-NvidiaVersion (bad input)'
Check 'empty -> null' ($null -eq (ConvertTo-NvidiaVersion '')) $true
Check '"1.2" -> null' ($null -eq (ConvertTo-NvidiaVersion '1.2')) $true

# NVIDIA servisi icin sahte yanitlar: ayni isimli fonksiyon cmdlet'in onune gecer, aga cikilmaz
$fakeProducts = @'
<LookupValueSearch><LookupValues>
  <LookupValue ParentID="129"><Name>GeForce RTX 4070 Laptop GPU</Name><Value>1007</Value></LookupValue>
  <LookupValue ParentID="127"><Name>GeForce RTX 4070</Name><Value>1015</Value></LookupValue>
</LookupValues></LookupValueSearch>
'@
$script:fakeDriver = $null
$script:lastUrl = $null
function Invoke-WebRequest {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'test mock')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'same signature as the cmdlet')]
    param($Uri, [switch]$UseBasicParsing)
    $script:lastPage = $Uri
    if ($Uri -match 'amd\.com') { return [pscustomobject]@{ Content = $script:fakeAmdPage } }
    [pscustomobject]@{ Content = $fakeProducts }
}
function Invoke-RestMethod {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'test mock')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'same signature as the cmdlet')]
    param($Uri, [switch]$UseBasicParsing)
    $script:lastUrl = $Uri
    $script:fakeDriver
}
function New-FakeDriver($version, $name = 'GeForce%20Game%20Ready%20Driver') {
    # Servis JSON'u text/html olarak donduruyor, yani Invoke-RestMethod string verir
    '{"Success":"1","IDS":[{"downloadInfo":{"Version":"' + $version + '","Name":"' + $name + '","ReleaseDateTime":"Wed Oct 21, 2026",' +
    '"DownloadURLFileSize":"1.04 GB","DownloadURL":"https://us.download.nvidia.com/Windows/' + $version + '/x.exe"}}]}'
}
$gpu = [pscustomobject]@{ Name = 'NVIDIA GeForce RTX 4070 Laptop GPU'; DriverVersion = '32.0.15.5222' }

Write-Host '--- Find-NvidiaDriver (mocked service)'
$script:fakeDriver = New-FakeDriver '621.01'
$r = Find-NvidiaDriver $gpu 135
Check 'newer driver -> Update' $r.Status 'Update'
Check 'installed / latest' "$($r.Installed) -> $($r.Latest)" '552.22 -> 621.01'
Check 'product ids in URL' ($script:lastUrl -match 'psid=129&pfid=1007&') $true
Check 'osID in URL' ($script:lastUrl -match '&osID=135&') $true

$script:fakeDriver = New-FakeDriver '552.22'
Check 'same driver -> Current' (Find-NvidiaDriver $gpu 57).Status 'Current'
$script:fakeDriver = New-FakeDriver '546.33'
Check 'older driver -> Current (no downgrade)' (Find-NvidiaDriver $gpu 57).Status 'Current'

$script:fakeDriver = '{"Success":"0","IDS":[]}'
Check 'no driver for GPU/OS -> NoMatch' (Find-NvidiaDriver $gpu 57).Status 'NoMatch'

$other = [pscustomobject]@{ Name = 'NVIDIA GeForce GTX 9999'; DriverVersion = '32.0.15.5222' }
Check 'unknown model -> NoMatch' (Find-NvidiaDriver $other 57).Status 'NoMatch'

$noVer = [pscustomobject]@{ Name = 'NVIDIA GeForce RTX 4070'; DriverVersion = $null }
Check 'unreadable version -> NoVersion' (Find-NvidiaDriver $noVer 57).Status 'NoVersion'

Write-Host '--- Find-NvidiaDriver -studio (mocked service)'
$script:fakeDriver = New-FakeDriver '617.42' 'NVIDIA%20Studio%20Driver'
$r = Find-NvidiaDriver $gpu 135 -studio
Check 'Studio newer than installed -> Update' "$($r.Status) $($r.Latest)" 'Update 617.42'
Check 'Studio query: isWHQL=0 + upCRD=1' ($script:lastUrl -match '&isWHQL=0&upCRD=1') $true
Check 'Studio in title' ($r.Title -match '\(Studio\)$') $true
[void](Find-NvidiaDriver $gpu 135)
Check 'Game Ready query: isWHQL=1 + upCRD=0' ($script:lastUrl -match '&isWHQL=1&upCRD=0') $true
$newer = [pscustomobject]@{ Name = 'NVIDIA GeForce RTX 4070 Laptop GPU'; DriverVersion = '32.0.16.2101' }   # 621.01 Game Ready
Check 'Game Ready 621.01 installed, Studio 617.42 -> no downgrade' (Find-NvidiaDriver $newer 135 -studio).Status 'Current'
$script:fakeDriver = New-FakeDriver '621.01'
Check 'service ignores Studio, returns Game Ready -> NoMatch' (Find-NvidiaDriver $gpu 135 -studio).Status 'NoMatch'

Write-Host '--- Get-AmdBranch'
Check 'RX 7900 XTX' (Get-AmdBranch 'AMD Radeon RX 7900 XTX') 'Mainline'
Check 'RX 9070 XT' (Get-AmdBranch 'AMD Radeon RX 9070 XT') 'Mainline'
Check 'RX 6600M (laptop)' (Get-AmdBranch 'AMD Radeon RX 6600M') 'Mainline'
Check 'RX 5500 XT is not RX 550' (Get-AmdBranch 'AMD Radeon RX 5500 XT') 'Mainline'
Check 'Radeon 780M iGPU' (Get-AmdBranch 'AMD Radeon(TM) 780M') 'Mainline'
Check 'RX 580' (Get-AmdBranch 'Radeon RX 580 Series') 'Legacy'
Check 'RX 550' (Get-AmdBranch 'AMD Radeon RX 550') 'Legacy'
Check 'RX 7600S (laptop)' (Get-AmdBranch 'AMD Radeon RX 7600S') 'Mainline'
Check 'RX 560X (laptop)' (Get-AmdBranch 'Radeon RX 560X Series') 'Legacy'
Check 'Vega 8 iGPU' (Get-AmdBranch 'AMD Radeon(TM) Vega 8 Graphics') 'Legacy'
Check 'generic APU name -> unknown' ($null -eq (Get-AmdBranch 'AMD Radeon(TM) Graphics')) $true
Check 'upper-case name (Turkish I)' (Get-AmdBranch 'AMD RADEON RX 7600') 'Mainline'

Write-Host '--- Test-AmdVendor'
Check 'Advanced Micro Devices, Inc.' (Test-AmdVendor 'Advanced Micro Devices, Inc.') $true
Check 'ATI Technologies Inc.' (Test-AmdVendor 'ATI Technologies Inc.') $true
Check 'NVIDIA Corporation (has "ati")' (Test-AmdVendor 'NVIDIA Corporation') $false
Check 'Intel Corporation' (Test-AmdVendor 'Intel Corporation') $false

Write-Host '--- Find-AmdDriver (mocked amd.com)'
$script:fakeAmdPage = '<a href="https://drivers.amd.com/drivers/whql-amd-software-adrenalin-edition-26.10.1-win11-b.exe">' +
    '<a href="https://drivers.amd.com/drivers/whql-amd-software-adrenalin-edition-26.9.2-win11-a.exe">Release Notes 24.9.1</a>'
Check 'page -> newest version' (Get-AdrenalinLatest $script:fakeAmdPage) '26.10.1'
Check '26.10.1 > 26.9.2 (not string order)' (Get-AdrenalinLatest 'whql-amd-software-adrenalin-edition-26.9.2 whql-amd-software-adrenalin-edition-26.10.1') '26.10.1'
Check 'no version on page' ($null -eq (Get-AdrenalinLatest '<html></html>')) $true
$rx = [pscustomobject]@{ Name = 'AMD Radeon RX 7800 XT' }
$r = Find-AmdDriver $rx '26.5.1'
Check 'older Adrenalin -> Update' "$($r.Status) $($r.Installed) -> $($r.Latest)" 'Update 26.5.1 -> 26.10.1'
Check 'mainline reference page' ($script:lastPage -match 'rx-7900-xtx') $true
Check 'same version -> Current' (Find-AmdDriver $rx '26.10.1').Status 'Current'
Check 'no Adrenalin installed -> NoVersion' (Find-AmdDriver $rx $null).Status 'NoVersion'
[void](Find-AmdDriver ([pscustomobject]@{ Name = 'Radeon RX 590' }) '26.5.2')
Check 'legacy GPU -> Vega/Polaris page' ($script:lastPage -match 'vega-64') $true
Check 'unknown GPU -> UnknownGpu, no request' (Find-AmdDriver ([pscustomobject]@{ Name = 'AMD Radeon(TM) Graphics' }) '26.5.1').Status 'UnknownGpu'
$script:fakeAmdPage = '<html>page changed</html>'
$threw = $false; try { [void](Find-AmdDriver $rx '26.5.1') } catch { $threw = $true }
Check 'page without versions -> error, not "Current"' $threw $true

Write-Host '--- Get-DeviceProblemKey'
Check 'code 28 (no driver)' (Get-DeviceProblemKey 28) 'DevCode28'
Check 'code 43' (Get-DeviceProblemKey 43) 'DevCode43'
Check 'code 12 -> generic' (Get-DeviceProblemKey 12) 'DevCodeOther'
Check 'every key exists in $Msg' (@(1, 10, 18, 28, 31, 43, 52, 12 | Where-Object { -not $Msg.en.ContainsKey((Get-DeviceProblemKey $_)) }).Count) 0

Write-Host '--- Get-MemorySummary'
$dimm = { param($gb, $speed, $cfg) [pscustomobject]@{ Capacity = [int64]$gb * 1GB; Speed = $speed; ConfiguredClockSpeed = $cfg; SMBIOSMemoryType = 34 } }
$m = Get-MemorySummary @((& $dimm 16 5600 5600), (& $dimm 16 5600 5600)) 2
Check '2x16 GB DDR5 full speed' "$($m.TotalGB) $($m.Type) $($m.Count)/$($m.Slots) slow=$($m.Slow) single=$($m.Single)" '32 DDR5 2/2 slow=False single=False'
$m = Get-MemorySummary @((& $dimm 16 6000 4800), (& $dimm 16 6000 4800)) 2
Check 'rated 6000, running 4800 -> Slow' "$($m.Slow) $($m.Actual)/$($m.Rated)" 'True 4800/6000'
$m = Get-MemorySummary @(& $dimm 8 3200 3200) 2
Check 'one module, two slots -> Single' $m.Single $true
$m = Get-MemorySummary @(& $dimm 8 3200 0) 1
Check 'speed not reported -> not Slow' $m.Slow $false
Check 'slots reported lower than modules' (Get-MemorySummary @((& $dimm 8 3200 3200), (& $dimm 8 3200 3200)) 0).Slots 2

Write-Host '--- Get-DiskWarnings'
$disk = { param($health, $wear, $temp, $err) [pscustomobject]@{ Name = 'SSD'; Health = $health; Wear = $wear; Temperature = $temp; ReadErrors = $err } }
Check 'healthy, new, cool -> none' (Get-DiskWarnings (& $disk 'Healthy' 3 38 0)).Count 0
Check 'no counters (SATA/USB) -> none' (Get-DiskWarnings (& $disk 'Healthy' $null $null $null)).Count 0
Check 'wear 69 -> none' (Get-DiskWarnings (& $disk 'Healthy' 69 40 0)).Count 0
Check 'wear 70 -> WearWarn' ((Get-DiskWarnings (& $disk 'Healthy' 70 40 0)) | ForEach-Object Key) 'DiskWearWarn'
Check 'wear 90 -> WearHigh only' ((Get-DiskWarnings (& $disk 'Healthy' 90 40 0)) | ForEach-Object Key) 'DiskWearHigh'
Check 'wear 120 (past rated life)' ((Get-DiskWarnings (& $disk 'Healthy' 120 40 0)) | ForEach-Object Key) 'DiskWearHigh'
Check 'temp 69 -> none' (Get-DiskWarnings (& $disk 'Healthy' 5 69 0)).Count 0
Check 'temp 70 -> Hot' ((Get-DiskWarnings (& $disk 'Healthy' 5 70 0)) | ForEach-Object Key) 'DiskHot'
Check 'unhealthy + errors, serious first' ((Get-DiskWarnings (& $disk 'Unhealthy' 95 75 3)) | ForEach-Object Key) @('DiskBad', 'DiskErrors', 'DiskWearHigh', 'DiskHot')
# Ana akistaki gibi: once degiskene ata, sonra foreach + mesaj
$warnings = Get-DiskWarnings (& $disk 'Healthy' 92 40 0)
$script:Lang = 'en'   # M() bunu okur
$text = foreach ($w in $warnings) { $a = $w.Args; M $w.Key @a }
Check 'warning renders as text' $text "SSD: 92% of the SSD's rated life is used. Back up and plan a replacement."

Write-Host '--- Get-BackupInfNames'
$entities = @(
    [pscustomobject]@{ DeviceID = 'PCI\VEN_10DE&DEV_2820\4&1'; HardwareID = @('PCI\VEN_10DE&DEV_2820&SUBSYS_A7621558'); CompatibleID = @('PCI\CC_0300') }
    [pscustomobject]@{ DeviceID = 'PCI\VEN_8086&DEV_7E28\3&2'; HardwareID = @('PCI\VEN_8086&DEV_7E28&REV_04'); CompatibleID = @('PCI\VEN_8086&DEV_7E28') }
    [pscustomobject]@{ DeviceID = 'HDAUDIO\FUNC_01\5&3'; HardwareID = @('HDAUDIO\FUNC_01&VEN_10EC'); CompatibleID = @() }
)
$signed = @(
    [pscustomobject]@{ DeviceID = 'PCI\VEN_10DE&DEV_2820\4&1'; InfName = 'oem91.inf' }
    [pscustomobject]@{ DeviceID = 'PCI\VEN_8086&DEV_7E28\3&2'; InfName = 'OEM12.INF' }
    [pscustomobject]@{ DeviceID = 'HDAUDIO\FUNC_01\5&3'; InfName = 'hdaudio.inf' }
)
Check 'NVIDIA item by device id' (Get-BackupInfNames @([pscustomobject]@{ DeviceId = 'PCI\VEN_10DE&DEV_2820\4&1' }) $entities $signed) 'oem91.inf'
Check 'WU item via compatible id, lower-cased' (Get-BackupInfNames @([pscustomobject]@{ HardwareId = 'pci\ven_8086&dev_7e28' }) $entities $signed) 'oem12.inf'
Check 'inbox driver is skipped' (Get-BackupInfNames @([pscustomobject]@{ HardwareId = 'HDAUDIO\FUNC_01&VEN_10EC' }) $entities $signed).Count 0
Check 'device not present -> nothing' (Get-BackupInfNames @([pscustomobject]@{ HardwareId = 'USB\VID_FFFF' }) $entities $signed).Count 0
Check 'two items, unique + sorted' (Get-BackupInfNames @([pscustomobject]@{ HardwareId = 'PCI\VEN_8086&DEV_7E28&REV_04' }, [pscustomobject]@{ DeviceId = 'PCI\VEN_10DE&DEV_2820\4&1' }, [pscustomobject]@{ DeviceId = 'PCI\VEN_10DE&DEV_2820\4&1' }) $entities $signed) @('oem12.inf', 'oem91.inf')

Write-Host '--- Test-TrustedAcl'
$ace = { param($sid, $rights, $type) [pscustomobject]@{ IdentityReference = $sid; FileSystemRights = $rights; AccessControlType = $type } }
$locked = @((& $ace 'S-1-5-18' 'FullControl' 'Allow'), (& $ace 'S-1-5-32-544' 'FullControl' 'Allow'))
Check 'SYSTEM + Administrators only' (Test-TrustedAcl 'S-1-5-32-544' $locked) $true
Check 'owned by a user' (Test-TrustedAcl 'S-1-5-21-1-2-3-1001' $locked) $false
Check 'Users can create folders' (Test-TrustedAcl 'S-1-5-32-544' ($locked + (& $ace 'S-1-5-32-545' 'Write' 'Allow'))) $false
Check 'CREATOR OWNER GENERIC_ALL' (Test-TrustedAcl 'S-1-5-18' ($locked + (& $ace 'S-1-3-0' 268435456 'Allow'))) $false
Check 'Users read-only is fine' (Test-TrustedAcl 'S-1-5-32-544' ($locked + (& $ace 'S-1-5-32-545' 'ReadAndExecute, Synchronize' 'Allow'))) $true
Check 'Deny for Everyone is fine' (Test-TrustedAcl 'S-1-5-32-544' ($locked + (& $ace 'S-1-1-0' 'Write' 'Deny'))) $true
# Gercek ornek: %ProgramData%'nin kendisi Users'a klasor olusturma izni verir, guvenilmez sayilmali
$pd = Get-Acl -LiteralPath $env:ProgramData
$sidType = [Security.Principal.SecurityIdentifier]
Check 'real %ProgramData% ACL is not trusted' (Test-TrustedAcl $pd.GetOwner($sidType).Value $pd.GetAccessRules($true, $true, $sidType)) $false

Write-Host '--- Get-ArgConflict'
Check 'nothing set' ($null -eq (Get-ArgConflict $false '' $false)) $true
Check '-All alone' ($null -eq (Get-ArgConflict $false '' $true)) $true
Check '-ScanOnly + -All' (Get-ArgConflict $true '' $true) '-ScanOnly, -All'
Check '-Install + -All' (Get-ArgConflict $false '1,2' $true) '-Install, -All'

Write-Host '--- Read-Config'
$tmp = Join-Path ([IO.Path]::GetTempPath()) "pcdc-test-$PID"
New-Item -ItemType Directory $tmp -Force | Out-Null
$cfg = Join-Path $tmp 'PC-Driver-Check.config.json'
Check 'missing file -> no patterns' (Read-Config $cfg).Ignore.Count 0
[IO.File]::WriteAllText($cfg, '{ "ignore": [ "*ComputeAccelerator*", "", "Realtek*" ] }')
Check 'patterns, empty entries dropped' (Read-Config $cfg).Ignore @('*ComputeAccelerator*', 'Realtek*')
[IO.File]::WriteAllText($cfg, '{ "ignore": "*Bluetooth*" }')
Check 'single string -> one pattern' (Read-Config $cfg).Ignore '*Bluetooth*'
[IO.File]::WriteAllText($cfg, '{ "ignore": [ "*broken" ')
$threw = $false; try { [void](Read-Config $cfg) } catch { $threw = $true }
Check 'invalid JSON -> error (not silently empty)' $threw $true
Remove-Item $tmp -Recurse -Force

Write-Host '--- Test-Ignored'
Check 'wildcard match' (Test-Ignored 'Intel Corporation ComputeAccelerator Driver Update' @('*ComputeAccelerator*')) $true
Check 'no match' (Test-Ignored 'Realtek Audio' @('*ComputeAccelerator*')) $false
Check 'upper-case title (Turkish I)' (Test-Ignored 'INTEL BLUETOOTH DRIVER' @('*intel*bluetooth*')) $true
Check 'no patterns' (Test-Ignored 'Anything' @()) $false

Write-Host '--- ConvertTo-ReportHtml'
$script:Lang = 'en'
$rep = [ordered]@{
    Date = '2026-10-30T10:00:00'; ExitCode = 0
    Pc = [ordered]@{ Model = 'Test PC'; Windows = 'Windows 11'; Cpu = 'CPU'; Gpus = @([ordered]@{ Name = 'GPU <b>'; DriverVersion = '1.0' }) }
    Memory = [pscustomobject]@{ TotalGB = 32; Type = 'DDR5'; Count = 2; Slots = 2; Rated = 5600; Actual = 5600 }
    Disks = @(); ProblemDevices = @()
    Updates = @([ordered]@{ Source = 'WU'; Title = 'Evil <script>alert(1)</script> & Co'; Class = 'USB'; Date = '2026-10-01'; Size = '1 MB' })
    Ignored = @(); Warnings = @('disk is hot'); Installed = @(); Failed = @(); RebootRequired = $false
}
$html = ConvertTo-ReportHtml $rep
Check 'update title is HTML-encoded' ($html.Contains('Evil &lt;script&gt;alert(1)&lt;/script&gt; &amp; Co')) $true
Check 'no raw <script> from data' ($html -notmatch '<script') $true
Check 'GPU name encoded' ($html.Contains('GPU &lt;b&gt;')) $true
Check 'warnings listed' ($html.Contains('<li>disk is hot</li>')) $true
Check 'empty sections say "none"' ($html.Contains('<p class="none">none</p>')) $true
Check 'utf-8 + lang' ($html -match '<meta charset="utf-8">' -and $html -match '<html lang="en">') $true

Write-Host '--- Messages'
$missing = @($Msg.tr.Keys | Where-Object { -not $Msg.en.ContainsKey($_) }) + @($Msg.en.Keys | Where-Object { -not $Msg.tr.ContainsKey($_) })
Check 'tr/en have the same keys' ($missing -join ' ') ''
$holes = { param($s) (([regex]::Matches($s, '\{\d+\}') | ForEach-Object Value | Sort-Object -Unique) -join '') }
$mismatch = @($Msg.tr.Keys | Where-Object { $Msg.en.ContainsKey($_) -and (& $holes $Msg.tr[$_]) -ne (& $holes $Msg.en[$_]) })
Check 'tr/en have the same {n} placeholders' ($mismatch -join ' ') ''

Write-Host "=== FAILED: $fail"
exit [int]($fail -gt 0)
