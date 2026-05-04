$scbTenant = { Get-BapTenantDetail | Sort-Object Id | Select-Object -ExpandProperty Id }
Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.tenant.details" -ScriptBlock $scbTenant -Mode Simple
