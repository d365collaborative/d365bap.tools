$scbBapTenantUpn = {
    param (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameter
    )

    try {
        $provider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'
        if ($provider -eq 'AzCli') {
            $upns = @()
            try {
                $raw = az account list --query '[].user.name' -o tsv 2>$null
                if ($LASTEXITCODE -eq 0 -and $raw) {
                    $upns = @($raw | Where-Object { $_ } | Sort-Object -Unique)
                }
            }
            catch { }
            foreach ($upn in ($upns | Where-Object { $_ -like "$wordToComplete*" })) {
                [System.Management.Automation.CompletionResult]::new($upn, $upn, 'ParameterValue', $upn)
            }
            return
        }

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
