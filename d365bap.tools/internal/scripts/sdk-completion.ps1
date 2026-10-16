Register-ArgumentCompleter -CommandName @($script:BapSdkCommands.Keys) -ParameterName EnvironmentId -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $null = $commandName, $parameterName, $commandAst, $fakeBoundParameters
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $context) { return }
    $cacheKey = "$($context.Tenant.Id)/$($context.Account.Id)"
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
