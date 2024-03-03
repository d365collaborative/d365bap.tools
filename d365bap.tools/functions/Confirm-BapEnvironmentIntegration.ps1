
<#
    .SYNOPSIS
        Test the integration status
        
    .DESCRIPTION
        Invokes the validation of the PowerPlatform integration, from the Dataverse perspective
        
        If it returns an output, the Dataverse is fully connected to the D365FO environment
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Confirm-BapEnvironmentIntegration -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will invoke the validation from the Dataverse environment.
        It will only output details if the environment is fully connected and working.
        
        Sample output:
        LinkedAppLcsEnvId                    LinkedAppLcsEnvUri                                 IsUnifiedDatabase TenantId
        -----------------                    ------------------                                 ----------------- --------
        0e52661c-0225-4621-b1b4-804712cf6d9a https://new-test.sandbox.operations.eu.dynamics.c… False             8ccb796b-37b…
        
    .EXAMPLE
        PS C:\> Confirm-BapEnvironmentIntegration -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
        
        This will invoke the validation from the Dataverse environment.
        It will only output details if the environment is fully connected and working.
        Will output all details into an Excel file, that will auto open on your machine.
        
        The excel file will be empty if the integration isn't working.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Confirm-BapEnvironmentIntegration {
    [CmdletBinding()]
    param (
        [parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [switch] $AsExcelOutput
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.LinkedMetaPpacEnvUri
        $tokenWebApi = Get-AzAccessToken -ResourceUrl $baseUri
        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApi.Token)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $resValidate = Invoke-RestMethod -Method Get -Uri $($baseUri + '/api/data/v9.2/RetrieveFinanceAndOperationsIntegrationDetails') -Headers $headersWebApi

        $temp = $resValidate | Select-PSFObject -TypeName "D365Bap.Tools.Environment.Integration" -ExcludeProperty "@odata.context" -Property "Id as LinkedAppLcsEnvId",
        "Url as LinkedAppLcsEnvUri",
        *
        
        if ($AsExcelOutput) {
            $temp | Export-Excel
            return
        }

        $temp
    }
    
    end {
        
    }
}