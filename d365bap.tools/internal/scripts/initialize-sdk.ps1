Import-BapSdk
$sdkMapping = Import-PowerShellDataFile (Join-Path $script:ModuleRoot 'internal/sdk/commands.psd1')
$script:BapSdkCommands = @{}
$script:BapSdkApiVersion = [Microsoft.PowerPlatform.Management.ApiVersionHandler]::ApiVersion
$script:BapSdkEnvironmentCompletionCache = @{}

foreach ($resource in $sdkMapping.Resources) {
    foreach ($verb in ($resource.Methods.Keys | Sort-Object)) {
        $commandName = "$verb-$($resource.Noun)"
        $method = $resource.Methods[$verb]
        $parameters = @(Get-BapSdkParameter -Resource $resource -Method $method)
        $script:BapSdkCommands[$commandName] = @{
            Resource = $resource
            Method = $method
            Parameters = $parameters
        }
        $parameterDefinitions = @(
            '[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)][Alias(''EnvironmentName'',''PpacEnvId'')][ValidateNotNullOrEmpty()][string]$EnvironmentId'
        )
        $parameterHelp = @('.PARAMETER EnvironmentId', 'An exact environment name or Power Platform environment GUID.')
        foreach ($parameter in $parameters) {
            $values = ($parameter.Values | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }) -join ','
            $type = if ($parameter.Collection) { 'string[]' } else { 'string' }
            $parameterDefinitions += '[Parameter()][ValidateNotNullOrEmpty()][ValidateSet(' + $values + ')][' + $type + ']$' + $parameter.Name
            $parameterHelp += '.PARAMETER ' + $parameter.Name
            $parameterHelp += 'Allowed values from the SDK: ' + ($parameter.Values -join ', ') + '. If omitted, the current environment value is preserved.'
        }
        $binding = '[CmdletBinding()]'
        $invoke = "Invoke-BapSdkCommand -CommandName '$commandName' -BoundParameters `$PSBoundParameters"
        if ($verb -ne 'Get') {
            $binding = '[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact=''Medium'')]'
            $names = ($parameters | ForEach-Object { "`$PSBoundParameters.ContainsKey('$($_.Name)')" }) -join ' -or '
            $invoke = "if (-not ($names)) { throw 'Specify at least one maintenance setting to update.' }; if (`$PSCmdlet.ShouldProcess(`$EnvironmentId, 'Update Finance and Operations maintenance settings')) { $invoke }"
        }
        $exampleArguments = if ($parameters.Count) { ' -' + $parameters[0].Name + ' ' + $parameters[0].Values[0] + ' -WhatIf' } else { '' }
        $help = @(
            '.SYNOPSIS', $resource.Synopsis,
            '.DESCRIPTION', 'Generated from the bundled Microsoft.PowerPlatform.Management SDK. Uses the current Az context. Unspecified update settings retain their current values.'
        ) + $parameterHelp + @(
            '.EXAMPLE', "PS C:\> $commandName -EnvironmentId 'es-ude-motz-01'$exampleArguments", '',
            'Uses the generated SDK command with an environment name.',
            '.INPUTS', 'An object with an EnvironmentId, EnvironmentName, or PpacEnvId property.',
            '.OUTPUTS', 'System.Management.Automation.PSCustomObject'
        )
        $definition = 'function ' + $commandName + " {`n<#`n" + ($help -join "`n") + "`n#>`n" +
            $binding + "`n[OutputType([PSCustomObject])]`nparam(" + ($parameterDefinitions -join ",`n") + ")`nprocess { $invoke }`n}"
        . ([scriptblock]::Create($definition))
    }
}
