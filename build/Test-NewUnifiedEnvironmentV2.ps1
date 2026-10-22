#Requires -Version 7.6
#Requires -PSEdition Core
[CmdletBinding()]
param (
    [string] $ModulePath,
    [string] $ResultPath
)

$ErrorActionPreference = 'Stop'
if (-not $ModulePath) { $ModulePath = Join-Path $PSScriptRoot '../d365bap.tools/d365bap.tools.psd1' }
if (-not $ResultPath) { $ResultPath = Join-Path $PSScriptRoot '../TestResults/NewUnifiedEnvironmentV2.json' }
Import-Module $ModulePath -Force
$checks = [Collections.Generic.List[string]]::new()

$command = Get-Command New-UnifiedEnvironmentV2
$moduleFile = [IO.Path]::ChangeExtension((Resolve-Path $ModulePath).Path, '.psm1')
if ($command.Module.Path -ne $moduleFile) { throw 'The command came from a different installed module artifact.' }
$checks.Add('New-UnifiedEnvironmentV2 came from the requested module artifact.')

$expectedOrder = @('Type', 'Name', 'CustomDomainName', 'Location', 'Template', 'NoDemoDb', 'Version', 'SecurityGroup', 'EnvironmentGroup', 'PostProvisionDelaySeconds', 'ReadyStateTimeoutMinutes', 'WaitForCompletion', 'EarlyRelease')
$actualOrder = @($command.Parameters.Values | Where-Object { $_.ParameterSets['__AllParameterSets'].IsMandatory -or $true } | ForEach-Object { $_.Name } | Where-Object { $_ -notin @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable', 'ProgressAction', 'WhatIf', 'Confirm') })
if (Compare-Object $expectedOrder $actualOrder -SyncWindow 0) { throw "Parameter order differs. Expected: $($expectedOrder -join ', '). Actual: $($actualOrder -join ', ')." }
$checks.Add('Parameter order matches the specified contract.')

$module = Get-Module d365bap.tools | Where-Object Path -EQ $moduleFile
$cache = & $module { $script:ProvisioningCache }
if (-not $cache.locations.Count) { throw 'The provisioning cache has no locations.' }
if (-not $cache.templates['europe']) { throw 'The provisioning cache has no templates for europe.' }
if (-not (@($cache.templates['europe'] | Where-Object { $_.name -eq 'D365_DeveloperEdition' }))) { throw 'D365_DeveloperEdition is missing from the europe template cache.' }
$checks.Add("Provisioning cache loaded from disk: $($cache.locations.Count) locations, $($cache.templates.Keys.Count) template regions.")

$locationLine = 'New-UnifiedEnvironmentV2 -Location eu'
$locationValues = @([Management.Automation.CommandCompletion]::CompleteInput($locationLine, $locationLine.Length, $null).CompletionMatches.CompletionText | ForEach-Object { "$_".Trim("'", '"') })
if ($locationValues -notcontains 'europe') { throw "Location completion missing europe: $($locationValues -join ', ')." }
$checks.Add('Location tab completion proposes europe.')

$templateLine = 'New-UnifiedEnvironmentV2 -Location europe -Template D365_'
$templateValues = @([Management.Automation.CommandCompletion]::CompleteInput($templateLine, $templateLine.Length, $null).CompletionMatches.CompletionText | ForEach-Object { "$_".Trim("'", '"') })
if ($templateValues -notcontains 'D365_DeveloperEdition') { throw "Location-aware template completion failed: $($templateValues -join ', ')." }
if ($templateValues -notcontains 'D365_FinOps_Finance') { throw "FinOps templates are missing from completion: $($templateValues -join ', ')." }
if ($templateValues -contains 'D365_Sales') { throw "Completion proposed a template outside the V2 allow-list: $($templateValues -join ', ')." }
$checks.Add('Template completion is location-aware, proposes FinOps/DeveloperEdition, and hides other templates.')

$udeWrongTemplate = $false
try { New-UnifiedEnvironmentV2 -Type UDE -Name 'verify-only' -Location 'europe' -Template 'D365_FinOps_Finance' -WhatIf } catch { $udeWrongTemplate = $_.Exception.Message -like "*requires template 'D365_DeveloperEdition'*" }
if (-not $udeWrongTemplate) { throw 'UDE with a FinOps template was accepted.' }
$checks.Add("UDE rejects non-developer templates.")

$useDefaultTemplate = $false
try { New-UnifiedEnvironmentV2 -Type USE -Name 'verify-only' -Location 'europe' -WhatIf } catch { $useDefaultTemplate = $_.Exception.Message -like "*cannot use template 'D365_DeveloperEdition'*" }
if (-not $useDefaultTemplate) { throw 'USE with the default developer template was accepted.' }
$checks.Add('USE rejects the developer template and names the FinOps alternatives.')

$usePreview = @(New-UnifiedEnvironmentV2 -Type USE -Name 'verify-only' -Location 'europe' -Template 'D365_FinOps_Finance' -WhatIf)
if ($usePreview.Count -ne 1 -or $usePreview[0].Template -ne 'D365_FinOps_Finance') { throw 'USE with a FinOps template did not preview.' }
$checks.Add('USE with a FinOps template previews correctly.')

$udeCompletionLine = 'New-UnifiedEnvironmentV2 -Type UDE -Template D365_'
$udeCompletionValues = @([Management.Automation.CommandCompletion]::CompleteInput($udeCompletionLine, $udeCompletionLine.Length, $null).CompletionMatches.CompletionText | ForEach-Object { "$_".Trim("'", '"') })
if ($udeCompletionValues.Count -ne 1 -or $udeCompletionValues[0] -ne 'D365_DeveloperEdition') { throw "UDE completion is not restricted to the developer template: $($udeCompletionValues -join ', ')." }
$useCompletionLine = 'New-UnifiedEnvironmentV2 -Type USE -Location europe -Template D365_'
$useCompletionValues = @([Management.Automation.CommandCompletion]::CompleteInput($useCompletionLine, $useCompletionLine.Length, $null).CompletionMatches.CompletionText | ForEach-Object { "$_".Trim("'", '"') })
if ($useCompletionValues -contains 'D365_DeveloperEdition') { throw 'USE completion proposes the developer template.' }
if ($useCompletionValues -notcontains 'D365_FinOps_Finance') { throw "USE completion is missing FinOps templates: $($useCompletionValues -join ', ')." }
$checks.Add('Template completion follows the Type constraint in both directions.')

$filteredRejected = $false
try { & $module { Resolve-ProvisioningTemplate -Location 'europe' -Template 'D365_Sales' -AllowedPattern $script:ProvisioningV2TemplateFilter } } catch { $filteredRejected = $_.Exception.Message -like '*Supported values:*' }
if (-not $filteredRejected) { throw 'A template outside the V2 allow-list was accepted.' }
$checks.Add('Templates outside D365_FinOps*/D365_DeveloperEdition are rejected with the supported values.')

$invalidLocationRejected = $false
try { & $module { Resolve-ProvisioningLocation -Location 'atlantis' } } catch { $invalidLocationRejected = $_.Exception.Message -like '*Valid values:*' }
if (-not $invalidLocationRejected) { throw 'An unknown location was accepted.' }
$checks.Add('Unknown locations are rejected with the valid values.')

$noSlotRejected = $false
try { & $module { Resolve-ProvisioningTemplate -Location 'europe' -Template 'D365_FinOps_ProjOps' -EnvironmentSku 'Trial' } } catch { $noSlotRejected = $_.Exception.Message -like '*has no Trial slot*' }
if (-not $noSlotRejected) { throw 'A template without a Trial slot was accepted.' }
$checks.Add('Templates without the requested SKU slot are rejected before any API call.')

$disabledWarned = $false
$disabledOutput = @( & $module { Resolve-ProvisioningTemplate -Location 'europe' -Template 'D365_SmbMarketing' -EnvironmentSku 'Sandbox' } 3>&1)
if (($disabledOutput | Where-Object { $_ -is [Management.Automation.WarningRecord] } | Where-Object { "$_" -like '*disabled*' }).Count -eq 0) { throw 'A license-gated template did not raise a disabled warning.' }
if ($disabledOutput[-1] -ne 'D365_SmbMarketing') { throw 'A license-gated template was not resolved after the warning.' }
$checks.Add('License-gated templates warn but do not block (availability flags flap).')

$preview = @(New-UnifiedEnvironmentV2 -Type UDE -Name 'verify-only' -Location 'Europe' -WhatIf)
if ($preview.Count -ne 1) { throw 'WhatIf did not return exactly one payload preview.' }
if ($preview[0].Location -ne 'europe') { throw "WhatIf preview kept the display name instead of the canonical name: $($preview[0].Location)." }
if ($preview[0].Template -ne 'D365_DeveloperEdition') { throw "WhatIf preview template mismatch: $($preview[0].Template)." }
if (-not $preview[0].DevToolsEnabled -or -not $preview[0].DemoDataEnabled) { throw 'WhatIf preview flags are wrong for UDE with demo data.' }
$checks.Add('WhatIf resolves display names, applies the default template, and performs no authentication or API call.')

$help = Get-Help New-UnifiedEnvironmentV2 -Full
if (-not $help.Description -or -not $help.Examples.Example) { throw 'Comment-based help is incomplete.' }
$checks.Add('Help text is present for documentation generation.')

if (@(Get-Command -Module d365bap.tools | Where-Object Name -EQ 'New-UnifiedEnvironmentV2').Count -ne 1) { throw 'The V2 command is not exported exactly once.' }
$checks.Add('The V2 command is exported and the V1 command is untouched.')

Import-Module $ModulePath -Force
if (@(Get-Command -Module d365bap.tools | Where-Object Name -EQ 'New-UnifiedEnvironmentV2').Count -ne 1) { throw 'Reimport changed V2 exports.' }
$checks.Add('Repeated import keeps the V2 export stable.')

$null = New-Item -ItemType Directory -Path (Split-Path $ResultPath) -Force
$result = [ordered]@{
    TimestampUtc = [datetime]::UtcNow.ToString('o')
    PowerShell   = $PSVersionTable.PSVersion.ToString()
    ModulePath   = (Resolve-Path $ModulePath).Path
    Checks       = @($checks)
    Preview      = $preview[0]
}
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ResultPath -Encoding utf8
$result | ConvertTo-Json -Depth 8
