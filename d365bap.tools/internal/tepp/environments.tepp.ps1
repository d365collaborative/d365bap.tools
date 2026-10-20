<#
    Autocompletion for environments is a bit more complex as it needs to be refreshed based on the tenant that is currently set in context.
    The below implementation will refresh the environments every 15 minutes, but this can be adjusted as needed.
#>
Register-PSFTaskEngineTask -Name EnvironmentRefresh -Interval (New-TimeSpan -Minutes 15) -ResetTask -ScriptBlock {
    Set-PSFTaskEngineCache -Module d365bap.tools -Name Environments -Value (Get-BapEnvironment -ErrorAction SilentlyContinue).EnvName
}

$scbEnvironments = {
    param (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameter
    )

    try {
        $filterWord = $wordToComplete -replace '^[''"]', ''
        $cached = @(Get-PSFTaskEngineCache -Module d365bap.tools -Name Environments -ErrorAction SilentlyContinue | Where-Object { $_ })
        if (-not $cached -or $cached.Count -eq 0) {
            $cached = @(Get-BapEnvironment -ErrorAction SilentlyContinue | Select-Object -ExpandProperty EnvName -Unique | Where-Object { $_ })
        }
        $merged = @($cached) | Sort-Object -Unique | Where-Object { $_ -like "$filterWord*" }

        foreach ($v in $merged) {
            $escaped = $v -replace "'", "''"
            $quoted = "'$escaped'"
            [System.Management.Automation.CompletionResult]::new($quoted, $v, 'ParameterValue', $v)
        }
    }
    catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.environments" -ScriptBlock $scbEnvironments -Mode Full

$teppParameters = @("EnvironmentId", "SourceEnvironmentId", "DestinationEnvironmentId")

foreach ($paramName in $teppParameters) {
    # Discover commands from this module's own session state (function: drive).
    # Must NOT use 'Get-Command -Module d365bap.tools' here: during module import that
    # triggers auto-loading of the released module version from PSModulePath, which then
    # re-registers this same TEPP name in Simple mode and shadows the dev copy's commands.
    $commands = Get-ChildItem function: | Where-Object {
        (Get-Command $_.Name -CommandType Function -ErrorAction SilentlyContinue).Parameters.Keys -contains $paramName
    }

    foreach ($command in $commands) {
        Register-PSFTeppArgumentCompleter -Command $command.Name -Parameter $paramName -Name "d365bap.tools.tepp.environments"
    }
}
