﻿
<#
    .SYNOPSIS
        Get application users from environment
        
    .DESCRIPTION
        Enables the user to fetch all application users from the environment
        
        Utilizes the built-in "applicationusers" OData entity
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
        This can be obtained from the Get-BapEnvironment cmdlet
        
    .PARAMETER IncludePpacApplications
        Instruct the cmdlet to include all PPAC applications in the output
        
        This will include all applications that are "hidden", but utilized by the PPAC Environment
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentApplicationUser -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will fetch all ApplicationUsers from the environment.
        
        Sample output:
        PpacSystemUserId                     PpacAppName                    PpacAppId                            State
        ----------------                     -----------                    ---------                            -----
        b6e52ceb-f771-41ff-bd99-917523b28eaf Power Apps Checker Application 3bafba76-60bf-413d-a4c4-5c49ccabfb12 Active
        21ceaf7c-054c-43f6-8b14-ef6d04b90a21 Microsoft Forms Pro            560c9a6c-4535-4066-a415-480d1493cf98 Active
        c76313fd-5c6f-4f1f-9869-c884fa7fe226 # PowerPlatform-essence-uat    d88a3535-ebf0-4b2b-ad23-90e686660a64 Active
        29494271-7e38-4433-8bf8-06d335299a17 # PowerPlatform-essence-uat    8bf8862f-5036-42b0-a4f8-1b638db7896b Active
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentApplicationUser -EnvironmentId *test*
        
        This will fetch all ApplicationUsers from the environment.
        
        Sample output:
        PpacSystemUserId                     PpacAppName                    PpacAppId                            State
        ----------------                     -----------                    ---------                            -----
        b6e52ceb-f771-41ff-bd99-917523b28eaf Power Apps Checker Application 3bafba76-60bf-413d-a4c4-5c49ccabfb12 Active
        21ceaf7c-054c-43f6-8b14-ef6d04b90a21 Microsoft Forms Pro            560c9a6c-4535-4066-a415-480d1493cf98 Active
        c76313fd-5c6f-4f1f-9869-c884fa7fe226 # PowerPlatform-essence-uat    d88a3535-ebf0-4b2b-ad23-90e686660a64 Active
        29494271-7e38-4433-8bf8-06d335299a17 # PowerPlatform-essence-uat    8bf8862f-5036-42b0-a4f8-1b638db7896b Active
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentApplicationUser -EnvironmentId *test* -IncludePpacApplications
        
        This will fetch all ApplicationUsers from the environment.
        It will include all "hidden" PPAC applications in the output.
        
        Sample output:
        PpacSystemUserId                     PpacAppName                    PpacAppId                            State
        ----------------                     -----------                    ---------                            -----
        b6e52ceb-f771-41ff-bd99-917523b28eaf Power Apps Checker Application 3bafba76-60bf-413d-a4c4-5c49ccabfb12 Active
        21ceaf7c-054c-43f6-8b14-ef6d04b90a21 Microsoft Forms Pro            560c9a6c-4535-4066-a415-480d1493cf98 Active
        d88a3535-ebf0-4b2b-ad23-90e686660a64 # URAssignment                 c76313fd-5c6f-4f1f-9869-c884fa7fe226 Active
        8bf8862f-5036-42b0-a4f8-1b638db7896b # UnifiedRoutingForRecord_App  29494271-7e38-4433-8bf8-06d335299a17 Active
        
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

        [switch] $IncludePpacApplications,

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
        
        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $resSystemUsers = Invoke-RestMethod -Method Get -Uri $($baseUri + '/api/data/v9.2/systemusers?$filter=applicationid ne null&$expand=systemuserroles_association($select=name,roleid),businessunitid($select=name,businessunitid),teammembership_association($select=name,teamid)') -Headers $headersWebApi

        [System.Collections.Generic.List[System.Object]] $resCol = @()
        
        foreach ($appUsrObj in  $($resSystemUsers.value | Sort-Object -Property fullname -Descending)) {
            $tmp = $appUsrObj | Select-PSFObject -TypeName "D365Bap.Tools.PpacApplicationUser" `
                -ExcludeProperty "@odata.etag" `
                -Property "systemuserid as PpacSystemUserId",
            "fullname as PpacAppName",
            @{Name = "PpacAppId"; Expression = { $_.applicationid } },
            @{Name = "State"; Expression = { if (-not $_.isdisabled) { "Active" } else { "Inactive" } } },
            @{Name = "StateIsActive"; Expression = { -not $_.isdisabled } },
            "applicationid as EntraClientId",
            "azureactivedirectoryobjectid as EntraObjectId",
            *

            if (-not $IncludePpacApplications) {
                if ($tmp.EntraObjectId) {
                    $resCol.Add($tmp)
                }
                elseif (-not ($tmp.internalemailaddress -like '*@onmicrosoft.com')) {
                    $resCol.Add($tmp)
                }
            }
            else {
                $resCol.Add($tmp)
            }
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel
            return
        }

        $resCol
    }

    end {
        
    }
    
}