$scbEnvVersion = {
    param (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameter
    )

    # Get the value of the previous parameter (-EnvironmentId)
    $environmentId = $fakeBoundParameter['EnvironmentId']

    # If no environmentId is specified yet, return nothing or a default set (adjust as needed)
    if (-not $environmentId) {
        return
    }

    $updateVersions = Get-PpacD365PlatformUpdate -EnvironmentId $environmentId

    # Generate completion results
    foreach ($item in $updateVersions) {
        New-PSFTeppCompletionResult -CompletionText $item.Version -ToolTip $item.Platform
    }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.env.temp.versions" -ScriptBlock $scbEnvVersion -Mode Full
