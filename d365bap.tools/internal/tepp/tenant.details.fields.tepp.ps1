$scbTenantDetailUpn = {
    param (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameter
    )

    try {
        $stored = @(Get-BapTenantDetail -ErrorAction SilentlyContinue | Select-Object -ExpandProperty User -Unique | Where-Object { $_ })
        $live = @(Get-AzContext -ListAvailable -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Account | Select-Object -ExpandProperty Id -Unique | Where-Object { $_ })
        $merged = @($stored + $live) | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }

        foreach ($v in $merged) {
            [System.Management.Automation.CompletionResult]::new($v, $v, 'ParameterValue', $v)
        }
    }
    catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.tenant.details.upn" -ScriptBlock $scbTenantDetailUpn -Mode Full

$scbTenantDetailTenantId = {
    param (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameter
    )

    try {
        $stored = @(Get-BapTenantDetail -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Tenant -Unique | Where-Object { $_ })
        $live = @(Get-AzContext -ListAvailable -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Tenant | Select-Object -ExpandProperty Id -Unique | Where-Object { $_ })
        $merged = @($stored + $live) | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }

        foreach ($v in $merged) {
            [System.Management.Automation.CompletionResult]::new($v, $v, 'ParameterValue', $v)
        }
    }
    catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.tenant.details.tenantid" -ScriptBlock $scbTenantDetailTenantId -Mode Full

$scbTenantDetailFriendly = {
    param (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameter
    )

    try {
        $stored = @(Get-BapTenantDetail -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FriendlyName -Unique | Where-Object { $_ })
        $liveNames = @(Get-AzTenant -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name -Unique | Where-Object { $_ })
        $filterWord = $wordToComplete -replace "^['\""]", ""
        $merged = @($stored + $liveNames) | Sort-Object -Unique | Where-Object { $_ -like "$filterWord*" }

        foreach ($v in $merged) {
            $escaped = $v -replace "'", "''"
            $quoted = "'$escaped'"
            [System.Management.Automation.CompletionResult]::new($quoted, $v, 'ParameterValue', $v)
        }
    }
    catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.tenant.details.friendly" -ScriptBlock $scbTenantDetailFriendly -Mode Full
