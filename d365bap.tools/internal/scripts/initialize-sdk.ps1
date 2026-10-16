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
        $parameterDefinitions = @()
        $parameterHelp = @()
        $exampleArguments = ''
        $description = 'Uses the current Az context.'
        $inputHelp = 'None.'
        if ($resource.Scope -eq 'Environment') {
            $parameterDefinitions += '[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)][Alias(''EnvironmentName'',''PpacEnvId'')][ValidateNotNullOrEmpty()][string]$EnvironmentId'
            $parameterHelp += '.PARAMETER EnvironmentId', 'An exact environment name or Power Platform environment GUID.'
            $exampleArguments = " -EnvironmentId 'es-ude-motz-01'"
            $description += ' Unspecified update settings retain their current values.'
            $inputHelp = 'An object with an EnvironmentId, EnvironmentName, or PpacEnvId property.'
        }
        if ($resource.CollectionProperty) {
            $parameterDefinitions += '[Parameter()][SupportsWildcards()][ValidateNotNullOrEmpty()][string]$Name = ''*''', '[Parameter()][switch]$AsExcelOutput'
            $parameterHelp += '.PARAMETER Name', 'Filter by application name or unique name. Wildcards are accepted. Defaults to all applications.',
                '.PARAMETER AsExcelOutput', 'Export the filtered results to an Excel workbook.'
            $description += ' Retrieves all result pages. Filters application names and unique names, then sorts results by application name.'
        }
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
        if ($parameters.Count) { $exampleArguments += ' -' + $parameters[0].Name + ' ' + $parameters[0].Values[0] + ' -WhatIf' }
        $help = @(
            '.SYNOPSIS', $resource.Synopsis,
            '.DESCRIPTION', ('Generated from the bundled Microsoft.PowerPlatform.Management SDK. ' + $description)
        ) + $parameterHelp + @(
            '.EXAMPLE', "PS C:\> $commandName$exampleArguments", '',
            'Uses the current Az context.'
        )
        if ($resource.CollectionProperty) {
            $help += '.EXAMPLE', "PS C:\> $commandName -Name '*Sales*'", '', 'Returns applications with Sales in the application name or unique name.',
                '.EXAMPLE', "PS C:\> $commandName -Name '*Sales*' -AsExcelOutput", '', 'Exports matching applications to an Excel workbook.'
        }
        $help += @(
            '.INPUTS', $inputHelp,
            '.OUTPUTS', 'System.Management.Automation.PSCustomObject'
        )
        $definition = 'function ' + $commandName + " {`n<#`n" + ($help -join "`n") + "`n#>`n" +
            $binding + "`n[OutputType([PSCustomObject])]`nparam(" + ($parameterDefinitions -join ",`n") + ")`nprocess { $invoke }`n}"
        . ([scriptblock]::Create($definition))
    }
}
