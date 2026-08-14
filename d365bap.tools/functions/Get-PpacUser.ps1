
<#
    .SYNOPSIS
        Get information about users in a Power Platform environment.
        
    .DESCRIPTION
        This cmdlet retrieves information about users in a Power Platform environment. It allows filtering by user name or ID, including application users, and exporting the results to Excel.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve users from.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER User
        The name or ID of the user to filter the users by.
        
        Can be either the user name, user ID, user principal name (UPN) or application ID.
        
        Supports wildcard characters for flexible matching.
        
    .PARAMETER IncludeAppIds
        Instructs the cmdlet to include application users (service principals) in the results. By default, application users are excluded.
        
        Application users can be identified by their application ID and typically do not have an email address or UPN.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved user information to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-PpacUser -EnvironmentId "ContosoEnv"
        
        This command retrieves all users from the Power Platform environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-PpacUser -EnvironmentId "ContosoEnv" -User "john.doe"
        
        This command retrieves the user with the name "john.doe" from the Power Platform environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-PpacUser -EnvironmentId "ContosoEnv" -User "*john*"
        
        This command retrieves all users with names, user IDs, UPNs or application IDs matching "*john*" from the Power Platform environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-PpacUser -EnvironmentId "ContosoEnv" -IncludeAppIds
        
        This command retrieves all users, including application users, from the Power Platform environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-PpacUser -EnvironmentId "ContosoEnv" -IncludeAppIds -AsExcelOutput
        
        This command retrieves all users, including application users, from the Power Platform environment "ContosoEnv".
        It will export the information to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacUser {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Alias('Upn')]
        [string] $User = "*",

        [switch] $IncludeAppIds,

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
        
        $colUsersRaw = Invoke-RestMethod `
            -Method Get `
            -Uri $($baseUri + '/api/data/v9.2/systemusers?$select=fullname,internalemailaddress,applicationid,azureactivedirectoryobjectid') `
            -Headers $headersWebApi 4> $null | `
            Select-Object -ExpandProperty value

        $colUsers = $colUsersRaw | Where-Object {
            ($_.systemuserid -like $User -or $_.systemuserid -eq $User) `
                -or ($_.internalemailaddress -like $User -or $_.internalemailaddress -eq $User) `
                -or ($_.applicationid -like $User -or $_.applicationid -eq $User) `
                -or ($_.azureactivedirectoryobjectid -like $User -or $_.azureactivedirectoryobjectid -eq $User) `
                -or ($_.fullname -like $User -or $_.fullname -eq $User)
        }

        $resCol = @($colUsers | Select-PSFObject -TypeName "D365Bap.Tools.PpacUser" `
                -ExcludeProperty "@odata.etag" `
                -Property "systemuserid as PpacSystemUserId",
            "internalemailaddress as Email",
            "internalemailaddress as Upn",
            "fullname as Name",
            "applicationid as PpacAppId",
            "azureactivedirectoryobjectid as EntraObjectId",
            @{Name = "NameSortable"; Expression = { $_.fullname.Replace("# ", "") } },
            *
        )

        $resCol = $resCol | Sort-Object -Property NameSortable

        if (-not $IncludeAppIds) {
            $resCol = $resCol | Where-Object PpacAppId -eq $null
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacUser"
            return
        }

        $resCol
    }
    
    end {
        
    }
}