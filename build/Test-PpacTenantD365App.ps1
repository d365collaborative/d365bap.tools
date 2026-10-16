#Requires -Version 7.6
#Requires -PSEdition Core
[CmdletBinding()]
param (
    [string] $ModulePath,
    [string] $Name = '*Sales*',
    [string] $ResultDirectory
)

$ErrorActionPreference = 'Stop'
if (-not $ModulePath) { $ModulePath = Join-Path $PSScriptRoot '../d365bap.tools/d365bap.tools.psd1' }
if (-not $ResultDirectory) { $ResultDirectory = Join-Path $PSScriptRoot '../TestResults/TenantD365App' }
$null = New-Item -ItemType Directory -Path $ResultDirectory -Force
$ResultDirectory = (Resolve-Path $ResultDirectory).Path
Import-Module $ModulePath -Force
$command = Get-Command Get-PpacTenantD365App
$moduleFile = [IO.Path]::ChangeExtension((Resolve-Path $ModulePath).Path, '.psm1')
if ($command.Module.Path -ne $moduleFile) { throw 'The command came from a different installed module.' }
$module = $command.Module

$apps = @(Get-PpacTenantD365App)
if (-not $apps.Count) { throw 'The live API did not return tenant applications.' }
$expected = @($apps | Where-Object { $_.ApplicationName -like $Name -or $_.UniqueName -like $Name })
$filtered = @(Get-PpacTenantD365App -Name $Name)
if (-not $expected.Count -or (Compare-Object $expected.PpacD365AppId $filtered.PpacD365AppId -SyncWindow 0)) {
    throw 'The live name filter did not return the expected applications.'
}
$sortedNames = @($apps.PpacD365AppName | Sort-Object)
if (Compare-Object $apps.PpacD365AppName $sortedNames -SyncWindow 0) { throw 'Tenant applications are not sorted by name.' }

$workbookPath = Join-Path $ResultDirectory 'TenantD365Apps.xlsx'
& $module {
    param ($Path)
    $script:TenantAppVerificationWorkbookPath = $Path
    function script:Export-Excel {
        [CmdletBinding()]
        param ([Parameter(ValueFromPipeline = $true)] $InputObject, [string] $WorksheetName)

        begin { $rows = [Collections.Generic.List[object]]::new() }
        process { $rows.Add($InputObject) }
        end {
            $rows | ImportExcel\Export-Excel -Path $script:TenantAppVerificationWorkbookPath -WorksheetName $WorksheetName
        }
    }
} $workbookPath
try {
    $exportOutput = @(Get-PpacTenantD365App -Name $Name -AsExcelOutput)
    if ($exportOutput.Count) { throw 'Excel export also returned application objects.' }
}
finally {
    & $module { Remove-Item Function:script:Export-Excel }
}
$excelRows = @(Import-Excel -Path $workbookPath -WorksheetName 'Get-PpacTenantD365App')
if (Compare-Object $filtered.PpacD365AppId $excelRows.PpacD365AppId -SyncWindow 0) {
    throw 'The Excel workbook differs from the filtered results.'
}

$proof = [ordered]@{
    TimestampUtc = [datetime]::UtcNow.ToString('o')
    ModulePath = $moduleFile
    PowerShell = $PSVersionTable.PSVersion.ToString()
    TotalApplications = $apps.Count
    Filter = $Name
    MatchingApplications = $filtered.Count
    ExcelRows = $excelRows.Count
    WorkbookPath = $workbookPath
    Checks = @('Live SDK listing', 'Wildcard filter matches names and unique names', 'Sorted application names', 'Filtered Excel workbook readback')
    Sample = @($filtered | Select-Object -First 3 PpacD365AppId, PpacD365AppName, PpacPackageName, Publisher)
}
$proof | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $ResultDirectory 'proof.json') -Encoding utf8
$proof | ConvertTo-Json -Depth 5
