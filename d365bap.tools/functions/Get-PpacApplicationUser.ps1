function Get-PpacApplicationUser {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Alias('Upn')]
        [string] $User = "*",

        [switch] $IncludePpacApplications,

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

        $baseUri = $envObj.PpacEnvUri
        
        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $resSystemUsers = Invoke-RestMethod `
            -Method Get `
            -Uri $($baseUri + '/api/data/v9.2/systemusers?$filter=applicationid ne null&$expand=systemuserroles_association($select=name,roleid),businessunitid($select=name,businessunitid),teammembership_association($select=name,teamid)') `
            -Headers $headersWebApi 4> $null
        
        $colUsersRaw = $resSystemUsers.value | Where-Object {
            ($_.systemuserid -like $User -or $_.systemuserid -eq $User) `
                -or ($_.fullname -like $User -or $_.fullname -eq $User) `
                -or ($_.applicationid -like $User -or $_.applicationid -eq $User)
        } | Sort-Object -Property fullname -Descending

        if (-not $IncludePpacApplications) {
            $colUsers = $colUsersRaw | Where-Object {
                ($null -ne $_.azureactivedirectoryobjectid) `
                    -or (-not ($_.internalemailaddress -like '*@onmicrosoft.com'))
            }
        }
        else {
            $colUsers = $colUsersRaw
        }

        $resCol = $colUsers | Select-PSFObject -TypeName "D365Bap.Tools.PpacApplicationUser" `
            -ExcludeProperty "@odata.etag" `
            -Property "systemuserid as PpacSystemUserId",
        "fullname as PpacAppName",
        @{Name = "PpacAppId"; Expression = { $_.applicationid } },
        @{Name = "State"; Expression = { if (-not $_.isdisabled) { "Active" } else { "Inactive" } } },
        @{Name = "StateIsActive"; Expression = { -not $_.isdisabled } },
        "applicationid as EntraClientId",
        "azureactivedirectoryobjectid as EntraObjectId",
        *

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacApplicationUser"
            return
        }

        $resCol
    }

    end {
        
    }
    
}