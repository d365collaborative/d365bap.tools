
<#
    .SYNOPSIS
        Get application users from environment
        
    .DESCRIPTION
        Enables the user to fetch all application users from the environment
        
        Utilizes the built-in "applicationusers" OData entity
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
        This can be obtained from the Get-BapEnvironment cmdlet
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentApplicationUser -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will fetch all ApplicationUsers from the environment.
        
        Sample output:
        AppId                                AppName                        ApplicationUserId                    SolutionId
        -----                                -------                        -----------------                    ----------
        b6e52ceb-f771-41ff-bd99-917523b28eaf AIBuilder_StructuredML_Prod_C… 3bafba76-60bf-413d-a4c4-5c49ccabfb12 bf85e0c8-aa47…
        21ceaf7c-054c-43f6-8b14-ef6d04b90a21 AIBuilderProd                  560c9a6c-4535-4066-a415-480d1493cf98 bf85e0c8-aa47…
        c76313fd-5c6f-4f1f-9869-c884fa7fe226 AppDeploymentOrchestration     d88a3535-ebf0-4b2b-ad23-90e686660a64 99aee001-009e…
        29494271-7e38-4433-8bf8-06d335299a17 AriaMdlExporter                8bf8862f-5036-42b0-a4f8-1b638db7896b 99aee001-009e…
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentApplicationUser -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
        
        This will fetch all ApplicationUsers from the environment.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapEnvironmentApplicationUser {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
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
        $resAppUsers = Invoke-RestMethod -Method Get -Uri $($baseUri + '/api/data/v9.2/applicationusers') -Headers $headersWebApi
        $resCol = @(
            foreach ($appUsrObj in  $($resAppUsers.value | Sort-Object -Property applicationname)) {
                $appUsrObj | Select-PSFObject -TypeName "D365Bap.Tools.AppUser" -ExcludeProperty "@odata.etag" -Property "applicationid as AppId",
                "applicationname as AppName",
                *
            }
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel
            return
        }

        $resCol
    }

    end {
        
    }
    
}