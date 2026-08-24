$scbBapTenantTenantId = {
    param (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameter
    )

    try {
        $contexts = Get-AzContext -ListAvailable -ErrorAction SilentlyContinue
        if (-not $contexts) { return }

        $tenantIds = $contexts |
            Where-Object { $null -ne $_.Tenant -and $null -ne $_.Tenant.Id -and $_.Tenant.Id } |
            Select-Object -ExpandProperty Tenant |
            Select-Object -ExpandProperty Id -Unique |
            Sort-Object |
            Where-Object { $_ -like "$wordToComplete*" }

        foreach ($id in $tenantIds) {
            [System.Management.Automation.CompletionResult]::new($id, $id, 'ParameterValue', $id)
        }
    }
    catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.bap.tenant.tenantid" -ScriptBlock $scbBapTenantTenantId -Mode Full
