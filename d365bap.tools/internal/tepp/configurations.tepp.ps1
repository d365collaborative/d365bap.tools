$scriptBlock = { Get-BapTenantDetail | Sort-Object Id | Select-Object -ExpandProperty Id }

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.tenant.details" -ScriptBlock $scriptBlock -Mode Simple

$scriptBlock = { Get-UdeDbJitCache | Sort-Object Id | Select-Object -ExpandProperty Id }

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.ude.dbjit.credentials" -ScriptBlock $scriptBlock -Mode Simple
