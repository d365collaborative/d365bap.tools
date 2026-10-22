$environmentCommands = @($script:BapSdkCommands.Keys | Where-Object { $script:BapSdkCommands[$_].Resource.Scope -eq 'Environment' })
Register-ArgumentCompleter -CommandName $environmentCommands -ParameterName EnvironmentId -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $null = $commandName, $parameterName, $commandAst, $fakeBoundParameters
    $provider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'
    if ($provider -eq 'AzCli') {
        try {
            $raw = az account show --query '{tenant:tenantId, user:user.name}' -o json 2>$null
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace("$raw")) { return }
            $cliContext = "$raw" | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($null -eq $cliContext -or [string]::IsNullOrWhiteSpace("$($cliContext.tenant)")) { return }
            $cacheKey = "$($cliContext.tenant)/$($cliContext.user)"
        }
        catch { return }
    }
    else {
        $context = Get-AzContext -ErrorAction SilentlyContinue
        if (-not $context) { return }
        $cacheKey = "$($context.Tenant.Id)/$($context.Account.Id)"
    }
    $cached = $script:BapSdkEnvironmentCompletionCache[$cacheKey]
    if (-not $cached -or $cached.Expires -lt [datetime]::UtcNow) {
        try {
            $cached = @{
                Expires = [datetime]::UtcNow.AddMinutes(15)
                Environments = @(Get-BapEnvironment -ErrorAction Stop)
            }
            $script:BapSdkEnvironmentCompletionCache[$cacheKey] = $cached
        }
        catch { return }
    }
    foreach ($environment in $cached.Environments) {
        if ($environment.EnvName.StartsWith($wordToComplete.Trim("'", '"'), [StringComparison]::OrdinalIgnoreCase)) {
            [Management.Automation.CompletionResult]::new(
                "'" + $environment.EnvName.Replace("'", "''") + "'",
                $environment.EnvName, 'ParameterValue', "$($environment.EnvName) ($($environment.PpacEnvId))")
        }
    }
}
