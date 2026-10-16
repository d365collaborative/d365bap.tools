#Requires -Version 7.6
#Requires -PSEdition Core
[CmdletBinding()]
param (
    [switch] $Live,
    [switch] $WriteCurrentSettings,
    [switch] $RoundTrip,
    [string] $EnvironmentId = 'es-ude-motz-01',
    [string] $ModulePath,
    [string] $ResultPath
)

$ErrorActionPreference = 'Stop'
if (-not $ModulePath) { $ModulePath = Join-Path $PSScriptRoot '../d365bap.tools/d365bap.tools.psd1' }
if (-not $ResultPath) { $ResultPath = Join-Path $PSScriptRoot '../TestResults/PowerPlatformSdk.json' }
if (($WriteCurrentSettings -or $RoundTrip) -and -not $Live) { throw 'WriteCurrentSettings and RoundTrip require Live.' }
Import-Module $ModulePath -Force
$checks = [Collections.Generic.List[string]]::new()
$setter = Get-Command Set-UnifiedEnvironmentMaintenanceV2
$moduleFile = [IO.Path]::ChangeExtension((Resolve-Path $ModulePath).Path, '.psm1')
if ($setter.Module.Path -ne $moduleFile) { throw 'The command came from a different installed module.' }
$checks.Add('Commands came from the requested module artifact.')
$model = [Microsoft.PowerPlatform.Management.Models.UpdateFinOpsAdminSettingsRequestBody]
$enum = [Nullable]::GetUnderlyingType($model.GetProperty('UpdatedMaintenanceWindowCadence').PropertyType)
$actualValues = @($setter.Parameters.Cadence.Attributes | Where-Object { $_ -is [Management.Automation.ValidateSetAttribute] }).ValidValues
if (Compare-Object ([Enum]::GetNames($enum)) $actualValues) { throw 'Cadence values differ from the SDK.' }
$checks.Add('Parameter validation matches the bundled SDK enum.')

foreach ($case in @(
    @{ Line = 'Set-UnifiedEnvironmentMaintenanceV2 -EnvironmentId unused -Cadence Every'; Expected = @('EveryOtherUpdate', 'EveryUpdate') },
    @{ Line = 'Set-UnifiedEnvironmentMaintenanceV2 -EnvironmentId unused -DaysOfWeek S'; Expected = @('Saturday', 'Sunday') }
)) {
    $completionValues = @([Management.Automation.CommandCompletion]::CompleteInput($case.Line, $case.Line.Length, $null).CompletionMatches.CompletionText)
    if (Compare-Object $case.Expected $completionValues) { throw "Unexpected completion for $($case.Line): $completionValues" }
}
$checks.Add('Cadence and days complete from SDK values.')

$invalidRejected = $false
try { Set-UnifiedEnvironmentMaintenanceV2 -EnvironmentId unused -Cadence Invalid -WhatIf } catch [Management.Automation.ParameterBindingException] { $invalidRejected = $true }
if (-not $invalidRejected) { throw 'Invalid enum input was accepted.' }
$checks.Add('Invalid values are rejected before dispatch.')

$emptyRejected = $false
try { Set-UnifiedEnvironmentMaintenanceV2 -EnvironmentId unused } catch { $emptyRejected = $_.Exception.Message -like '*Specify at least one*' }
if (-not $emptyRejected) { throw 'An update without settings was accepted.' }
$checks.Add('An empty update is rejected.')

$module = Get-Module d365bap.tools | Where-Object Path -EQ $moduleFile
& $module {
    $script:SdkVerificationOriginalInvoker = (Get-Command Invoke-BapSdkCommand).ScriptBlock
    function script:Invoke-BapSdkCommand { throw 'WhatIf dispatched an SDK call.' }
}
try {
    $output = @(Set-UnifiedEnvironmentMaintenanceV2 -EnvironmentId unused -Cadence EveryUpdate -WhatIf)
    if ($output.Count) { throw 'WhatIf returned an API result.' }
}
finally {
    & $module {
        Set-Item Function:script:Invoke-BapSdkCommand -Value $script:SdkVerificationOriginalInvoker
    }
}
$checks.Add('WhatIf performs no environment lookup, authentication, or SDK dispatch.')

foreach ($command in 'Get-UnifiedEnvironmentMaintenanceV2', 'Set-UnifiedEnvironmentMaintenanceV2') {
    $help = Get-Help $command -Full
    if (-not $help.Description -or -not $help.Examples.Example) { throw "Generated help is missing for $command." }
}
Import-Module $ModulePath -Force
if (@(Get-Command -Module d365bap.tools | Where-Object Name -Like '*EnvironmentMaintenanceV2').Count -ne 2) { throw 'Reimport changed command exports.' }
if (Get-Command Invoke-BapSdkCommand -ErrorAction SilentlyContinue) { throw 'SDK internals were exported.' }
$checks.Add('Generated help, private scope, and repeated import work.')

$before = $null
$writeResult = $null
$after = $null
$temporary = $null
if ($Live) {
    $before = Get-UnifiedEnvironmentMaintenanceV2 -EnvironmentId $EnvironmentId
    if (-not $before.EnvironmentId -or -not $before.maintenanceWindowCadence -or -not $before.maintenanceWindowDaysOfWeek) {
        throw 'The live GET did not return maintenance settings.'
    }
    $checks.Add('Live SDK GET returned maintenance settings.')
    $pipelineResult = @($before | Get-UnifiedEnvironmentMaintenanceV2)
    if ($pipelineResult.Count -ne 1 -or $pipelineResult[0].EnvironmentId -ne $before.EnvironmentId) { throw 'Live pipeline binding failed.' }
    $checks.Add('Live pipeline binding resolves EnvironmentId.')
    $line = 'Get-UnifiedEnvironmentMaintenanceV2 -EnvironmentId ' + $EnvironmentId
    $completion = [Management.Automation.CommandCompletion]::CompleteInput($line, $line.Length, $null)
    if ($before.EnvironmentName -ne $before.EnvironmentId -and $completion.CompletionMatches.ListItemText -notcontains $before.EnvironmentName) {
        throw 'The live environment name was absent from completion.'
    }
    $checks.Add('Environment name completion works against the current tenant.')
    if ($WriteCurrentSettings) {
        $writeResult = Set-UnifiedEnvironmentMaintenanceV2 -EnvironmentId $before.EnvironmentId -Cadence $before.maintenanceWindowCadence -Confirm:$false
        if (-not $writeResult -or $writeResult.maintenanceWindowCadence -ne $before.maintenanceWindowCadence -or
            (Compare-Object $before.maintenanceWindowDaysOfWeek $writeResult.maintenanceWindowDaysOfWeek)) {
            throw 'The SDK PUT did not return the original settings.'
        }
        $after = Get-UnifiedEnvironmentMaintenanceV2 -EnvironmentId $before.EnvironmentId
        if ($after.maintenanceWindowCadence -ne $before.maintenanceWindowCadence -or
            (Compare-Object $before.maintenanceWindowDaysOfWeek $after.maintenanceWindowDaysOfWeek)) {
            throw 'Live readback differs from the settings before the test.'
        }
        $checks.Add('Live SDK PUT succeeded and preserved the omitted days; a subsequent GET confirmed both settings.')
    }
    if ($RoundTrip) {
        $temporaryCadence = [Enum]::GetNames($enum) | Where-Object { $_ -ne $before.Cadence } | Select-Object -First 1
        try {
            $writeResult = Set-UnifiedEnvironmentMaintenanceV2 -EnvironmentId $before.EnvironmentId -Cadence $temporaryCadence -Confirm:$false
            $temporary = Get-UnifiedEnvironmentMaintenanceV2 -EnvironmentId $before.EnvironmentId
            if ($temporary.Cadence -ne $temporaryCadence -or
                (Compare-Object $before.DaysOfWeek $temporary.DaysOfWeek)) {
                throw 'Live readback did not confirm the temporary cadence and preserved days.'
            }
            $checks.Add('A temporary cadence change was confirmed by a separate live GET; omitted days were preserved.')
        }
        finally {
            $null = Set-UnifiedEnvironmentMaintenanceV2 -EnvironmentId $before.EnvironmentId -Cadence $before.Cadence -DaysOfWeek $before.DaysOfWeek -Confirm:$false
            $after = Get-UnifiedEnvironmentMaintenanceV2 -EnvironmentId $before.EnvironmentId
            if ($after.Cadence -ne $before.Cadence -or (Compare-Object $before.DaysOfWeek $after.DaysOfWeek)) {
                throw 'The original maintenance settings were not restored.'
            }
            $checks.Add('The original cadence and days were restored and confirmed by a separate live GET.')
        }
    }
}
$null = New-Item -ItemType Directory -Path (Split-Path $ResultPath) -Force
$result = [ordered]@{
    TimestampUtc = [datetime]::UtcNow.ToString('o')
    PowerShell = $PSVersionTable.PSVersion.ToString()
    SdkVersion = [Microsoft.PowerPlatform.Management.ServiceClient].Assembly.GetName().Version.ToString()
    ModulePath = (Resolve-Path $ModulePath).Path
    Checks = @($checks)
    Before = $before
    WriteResult = $writeResult
    Temporary = $temporary
    After = $after
}
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ResultPath -Encoding utf8
$result | ConvertTo-Json -Depth 8
