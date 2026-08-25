$scbBapTenantUpn = {
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

        $upns = $contexts |
            Where-Object { $null -ne $_.Account -and $null -ne $_.Account.Id -and $_.Account.Id } |
            Select-Object -ExpandProperty Account |
            Select-Object -ExpandProperty Id -Unique |
            Sort-Object |
            Where-Object { $_ -like "$wordToComplete*" }

        foreach ($upn in $upns) {
            [System.Management.Automation.CompletionResult]::new($upn, $upn, 'ParameterValue', $upn)
        }
    }
    catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.bap.tenant.upn" -ScriptBlock $scbBapTenantUpn -Mode Full
