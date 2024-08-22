
<#
    .SYNOPSIS
        Get users from environment
        
    .DESCRIPTION
        Enables the user to fetch all users from the environment
        
        Utilizes the built-in "systemusers" OData entity
        
        Allows the user to include all users, based on those who has the ApplicationId property filled
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
        This can be obtained from the Get-BapEnvironment cmdlet
        
    .PARAMETER IncludeAppIds
        Instruct the cmdlet to include all users that are available from the "systemusers" OData Entity
        
        Simply includes those who has the ApplicationId property filled
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentUser -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will fetch all oridinary users from the environment.
        
        Sample output:
        Email                          Name                           AppId                Systemuserid
        -----                          ----                           -----                ------------
        SYSTEM                                                                             5d2ff978-a74c-4ba4-8cc2-b4c5a23994f7
        INTEGRATION                                                                        baabe592-2860-4d1a-9365-e95317372498
        aba@temp.com                   Austin Baker                                        f85bcd69-ef72-45bd-a338-62670a8cef2a
        ade@temp.com                   Alex Denver                                         39309a5c-7676-4c8a-b702-719fb92c5151
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentUser -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will fetch all users from the environment.
        It will include the ones with the ApplicationId property filled.
        
        Sample output:
        Email                          Name                           AppId                Systemuserid
        -----                          ----                           -----                ------------
        SYSTEM                                                                             5d2ff978-a74c-4ba4-8cc2-b4c5a23994f7
        INTEGRATION                                                                        baabe592-2860-4d1a-9365-e95317372498
        aba@temp.com                   Austin Baker                                        f85bcd69-ef72-45bd-a338-62670a8cef2a
        AIBuilderProd@onmicrosoft.com  AIBuilderProd, #               0a143f2d-2320-4141-â€¦ c96f82b8-320f-4c5e-ac84-1831f4dc7d5f
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentUser -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -AsExcelOutput
        
        This will fetch all oridinary users from the environment.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapEnvironmentUser {
    [CmdletBinding()]
    param (
        [parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [switch] $IncludeAppIds,

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
        
        $resUsers = Invoke-RestMethod -Method Get -Uri $($baseUri + '/api/data/v9.2/systemusers?$select=fullname,internalemailaddress,applicationid&$expand=user_settings($select=uilanguageid)') -Headers $headersWebApi

        $resCol = @(
            foreach ($usrObj in  $($resUsers.value | Sort-Object -Property internalemailaddress)) {
                
                $usrObj | Add-Member -MemberType NoteProperty -Name "lang" -Value $($languages | Where-Object { ($_.localeid -eq $usrObj.user_settings[0].uilanguageid) -or ($_.BaseLocaleId -eq $usrObj.user_settings[0].uilanguageid) } | Select-Object -First 1 -ExpandProperty code)
                $usrObj | Select-PSFObject -TypeName "D365Bap.Tools.User" `
                    -ExcludeProperty "@odata.etag" `
                    -Property "systemuserid as Id",
                "internalemailaddress as Email",
                "fullname as Name",
                "applicationid as AppId",
                "lang as Language",
                "azureactivedirectoryobjectid as EntraObjectId",
                *
            }
        )

        if (-not $IncludeAppIds) {
            $resCol = $resCol | Where-Object applicationid -eq $null
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