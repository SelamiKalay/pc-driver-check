# Cevrimdisi birim testleri: yonetici izni, ag ve Windows Update gerektirmez.
# Calistirma: powershell -ExecutionPolicy Bypass -File tests\PC-Driver-Check.Tests.ps1
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '..\PC-Driver-Check.ps1'

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

Write-Host "PowerShell $($PSVersionTable.PSVersion)"

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

Write-Host '--- Messages'
$missing = @($Msg.tr.Keys | Where-Object { -not $Msg.en.ContainsKey($_) }) + @($Msg.en.Keys | Where-Object { -not $Msg.tr.ContainsKey($_) })
Check 'tr/en have the same keys' ($missing -join ' ') ''

Write-Host "=== FAILED: $fail"
exit [int]($fail -gt 0)
