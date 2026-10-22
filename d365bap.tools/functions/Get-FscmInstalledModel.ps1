
<#
    .SYNOPSIS
        Get installed models from a Finance and Operations environment.
        
    .DESCRIPTION
        Retrieves the list of installed models from a Finance and Operations environment using the GetInstalledModules OData action.
        
        Each installed model is parsed into its Name, Version, Module, Publisher, and DisplayName parts.
        
        Supports wildcard and exact matching against the Name, DisplayName, and Module fields.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve installed models from.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Name
        The value to filter the results by.
        
        Filters against the model Name, DisplayName, and Module fields — any match on any of the three will include the record.
        
        Supports wildcard characters for flexible matching.
        
        Default value is "*", which returns all installed models.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved installed models to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-FscmInstalledModel -EnvironmentId "ContosoEnv"
        
        This command retrieves all installed models from the environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Get-FscmInstalledModel -EnvironmentId "ContosoEnv" -Name "*Application*"
        
        This command retrieves all installed models whose Name, DisplayName, or Module contains "Application" from the environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Get-FscmInstalledModel -EnvironmentId "ContosoEnv" -Name "ApplicationSuite"
        
        This command retrieves installed models with the Module "ApplicationSuite" from the environment "ContosoEnv".
        
        The filter matches against the model Name, DisplayName, and Module fields.
        
    .EXAMPLE
        PS C:\> Get-FscmInstalledModel -EnvironmentId "ContosoEnv" -AsExcelOutput
        
        This command retrieves all installed models from the environment "ContosoEnv" and exports the results to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmInstalledModel {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [string] $Name = "*",

        [switch] $AsExcelOutput
    )

    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment `
            -EnvironmentId $EnvironmentId | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersFnO = @{
            "Authorization" = "Bearer $($tokenFnoOdataValue)"
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $localUri = $baseUri + '/data/SystemNotifications/Microsoft.Dynamics.DataEntities.GetInstalledModules'
        $colModulesRaw = Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersFnO `
            -ContentType 'application/json' `
            -Body '{}' | Select-Object -ExpandProperty value

        $colParsed = foreach ($entry in $colModulesRaw) {
            $props = @{}

            foreach ($part in ($entry -split '\s*\|\s*')) {
                $idx = $part.IndexOf(':')
                if ($idx -gt 0) {
                    $key = $part.Substring(0, $idx).Trim()
                    $val = $part.Substring($idx + 1).Trim()
                    $props[$key] = $val
                }
            }

            [PSCustomObject]@{
                DisplayName = $props['DisplayName']
                Name        = $props['Name']
                Version     = $props['Version']
                Module      = $props['Module']
                Publisher   = $props['Publisher']
            }
        }

        $resCol = $colParsed | Where-Object {
            ($_.Name -like $Name -or $_.Name -eq $Name) `
                -or ($_.DisplayName -like $Name -or $_.DisplayName -eq $Name) `
                -or ($_.Module -like $Name -or $_.Module -eq $Name)
        } | Sort-Object -Property 'DisplayName' `
        | Select-PSFObject -TypeName "D365Bap.Tools.FscmInstalledModel" `
            -Property DisplayName,
        Name,
        Version,
        Module,
        Publisher

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-FscmInstalledModel"
            return
        }

        $resCol
    }

    end {

    }
}