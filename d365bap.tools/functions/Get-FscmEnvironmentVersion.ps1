
<#
    .SYNOPSIS
        Get version numbers from a Finance and Operations environment.
        
    .DESCRIPTION
        Retrieves the application version, application build version, and platform build version from a Finance and Operations environment using OData actions.
        
        Returns a single object with the ApplicationVersion, ApplicationBuild, and PlatformBuild values.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve version numbers from.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved version numbers to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-FscmEnvironmentVersion -EnvironmentId "ContosoEnv"
        
        This command retrieves the version numbers from the environment "ContosoEnv" and displays them in the console.
        
    .EXAMPLE
        PS C:\> Get-FscmEnvironmentVersion -EnvironmentId "ContosoEnv" -AsExcelOutput
        
        This command retrieves the version numbers from the environment "ContosoEnv" and exports the results to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmEnvironmentVersion {
    [CmdletBinding()]
    [OutputType('System.Object')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

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

        $secureToken = Get-BapAccessToken -ResourceUrl $baseUri
        $tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersFnO = @{
            "Authorization" = "Bearer $($tokenFnoOdataValue)"
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $actions = [Ordered]@{
            ApplicationVersion = 'GetApplicationVersion'
            ApplicationBuild   = 'GetApplicationBuildVersion'
            PlatformBuild      = 'GetPlatformBuildVersion'
        }

        $props = [Ordered]@{}

        foreach ($key in $actions.Keys) {
            $localUri = $baseUri + "/data/DataManagementEntities/Microsoft.Dynamics.DataEntities.$($actions[$key])"
            $resValue = Invoke-RestMethod -Method Post `
                -Uri $localUri `
                -Headers $headersFnO `
                -ContentType 'application/json' `
                -Body '{}' | Select-Object -ExpandProperty value

            $props[$key] = $resValue
        }

        $res = [PSCustomObject]$props | Select-PSFObject `
            -TypeName "D365Bap.Tools.FscmEnvironmentVersion" `
            -Property ApplicationVersion,
        ApplicationBuild,
        PlatformBuild

        if ($AsExcelOutput) {
            $res | Export-Excel -WorksheetName "Get-FscmEnvironmentVersion"
            return
        }

        $res
    }

    end {

    }
}