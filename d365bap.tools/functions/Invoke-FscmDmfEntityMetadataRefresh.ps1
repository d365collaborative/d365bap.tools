<#
    .SYNOPSIS
        Refresh all Data Management Framework entity metadata in a Finance and Operations environment.
        
    .DESCRIPTION
        Invokes the InitializeDataManagement OData action on the DataManagementDefinitionGroups entity, which refreshes all Data Management Framework (DMF) entities in the Finance and Operations environment.
        
    .PARAMETER EnvironmentId
        The ID of the environment to refresh DMF entity metadata in.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .EXAMPLE
        PS C:\> Invoke-FscmDmfEntityMetadataRefresh -EnvironmentId "ContosoEnv"
        
        This command refreshes all DMF entity metadata in the environment "ContosoEnv".
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Invoke-FscmDmfEntityMetadataRefresh {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId
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
            "Content-Type"  = "application/json;charset=utf-8"
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $localUri = $baseUri + '/data/DataManagementDefinitionGroups/Microsoft.Dynamics.DataEntities.InitializeDataManagement'

        Write-PSFMessage -Level Verbose -Message "Invoking the DMF InitializeDataManagement OData action."

        Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersFnO `
            -Body '{}' `
            -ContentType $headersFnO.'Content-Type' `
            -StatusCodeVariable statusInit > $null 4> $null

        if (-not $statusInit -like "2*") {
            $messageString = "Something went wrong while refreshing the DMF entity metadata in the Dynamics 365 ERP environment. HTTP Status Code: <c='em'>$statusInit</c>. Please investigate."
            Write-PSFMessage -Level Warning -Message $messageString
            Stop-PSFFunction -Message "Stopping because the DMF metadata refresh could not be invoked." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
    }

    end {

    }
}
