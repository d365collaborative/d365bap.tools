<#
    Location-aware template completion for New-UnifiedEnvironmentV2.

    Registered as a native argument completer (rather than through the
    PSFramework TEPP host) because the completion needs $fakeBoundParameters
    to filter templates by the -Location value on the command line.
#>
Register-ArgumentCompleter -CommandName New-UnifiedEnvironmentV2 -ParameterName Template -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $word = "$wordToComplete".Trim("'", '"')
    $index = Get-PSFConfigValue -FullName 'd365bap.tools.provisioning.templates' -Fallback @{}
    $allowed = @(Get-PSFConfigValue -FullName 'd365bap.tools.provisioning.v2TemplateFilter' -Fallback @())

    $locationKey = $null
    if ($fakeBoundParameters -and $fakeBoundParameters.ContainsKey('Location') -and $fakeBoundParameters['Location']) {
        $wanted = "$($fakeBoundParameters['Location'])".Trim("'", '"')
        $locationKey = @($index.Keys | Where-Object { $_ -like $wanted }) | Select-Object -First 1
        if (-not $locationKey) {
            $locations = Get-PSFConfigValue -FullName 'd365bap.tools.provisioning.locations' -Fallback @()
            $locationKey = @($locations | Where-Object { $_.displayName -like $wanted } | ForEach-Object { $_.name }) | Select-Object -First 1
        }
    }

    if ($locationKey) { $candidates = @($index[$locationKey]) }
    else {
        $seen = @{}
        $candidates = foreach ($key in @($index.Keys)) {
            foreach ($template in @($index[$key])) {
                if (-not $seen.ContainsKey($template.name)) {
                    $seen[$template.name] = $true
                    $template
                }
            }
        }
    }

    if ($fakeBoundParameters -and $fakeBoundParameters.ContainsKey('Type') -and $fakeBoundParameters['Type']) {
        $typeWanted = "$($fakeBoundParameters['Type'])".Trim("'", '"')
        if ($typeWanted -eq 'UDE') { $candidates = @($candidates | Where-Object { $_.name -eq 'D365_DeveloperEdition' }) }
        elseif ($typeWanted -eq 'USE') { $candidates = @($candidates | Where-Object { $_.name -ne 'D365_DeveloperEdition' }) }
    }

    foreach ($template in @($candidates | Sort-Object -Property name -Unique)) {
        if ($allowed.Count -and -not @($allowed | Where-Object { $template.name -like $_ }).Count) { continue }
        if ($template.name -like "$word*") {
            $tooltip = if ($template.displayName) { "$($template.displayName) ($($template.skus -join ', '))" } else { $template.name }
            [Management.Automation.CompletionResult]::new("'$($template.name)'", $template.name, 'ParameterValue', "$tooltip")
        }
    }
}
