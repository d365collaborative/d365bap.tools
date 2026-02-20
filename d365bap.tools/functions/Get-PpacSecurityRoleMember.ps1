
<#
    .SYNOPSIS
        Get information about Finance and Operations security role members in a given environment.
        
    .DESCRIPTION
        This cmdlet retrieves information about Finance and Operations security role members in a given environment. It allows filtering by role name or ID, user name or ID, and exporting the results to Excel.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve security role members from.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Role
        The name or ID of the security role to retrieve members from.
        
        Can be either the role name or the role ID.
        
    .PARAMETER User
        The name or ID of the user to filter the security role members by.
        
        Can be either the user name or user ID.
        
        Supports wildcard characters for flexible matching.
        
    .PARAMETER IncludePpacApplications
        Instructs the cmdlet to include service principals (applications) in the results, in addition to user principals.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved security role member information to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-FscmSecurityRoleMember -EnvironmentId "ContosoEnv" -Role "System Customizer"
        
        This command retrieves the members of the Finance and Operations security role with the name "System Customizer" from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-FscmSecurityRoleMember -EnvironmentId "ContosoEnv" -Role "System Customizer" -User "*john*"
        
        This command retrieves the members of the Finance and Operations security role with the name "System Customizer" from the environment "ContosoEnv" and filters the members to those with user names or user IDs matching "*john*". The information is displayed in the console.
        
    .EXAMPLE
        PS C:\> Get-FscmSecurityRoleMember -EnvironmentId "ContosoEnv" -Role "System Customizer" -IncludePpacApplications
        
        This command retrieves the members of the Finance and Operations security role with the name "System Customizer" from the environment "ContosoEnv" and includes service principals (applications) in the results, in addition to user principals. The information is displayed in the console.
        
    .EXAMPLE
        PS C:\> Get-FscmSecurityRoleMember -EnvironmentId "ContosoEnv" -Role "System Customizer" -AsExcelOutput
        
        This command retrieves the members of the Finance and Operations security role with the name "System Customizer" from the environment "ContosoEnv".
        It will export the information to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacSecurityRoleMember {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [Alias('Name')]
        [string] $Role,

        [string] $User = "*",

        [switch] $IncludePpacApplications,

        [switch] $AsExcelOutput
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $secRoleObj = Get-PpacSecurityRole -EnvironmentId $EnvironmentId `
            -Name $Role | `
            Select-Object -First 1

        if ($null -eq $secRoleObj) {
            $messageString = "The supplied: <c='em'>$Role</c> didn't return any matching security details from the Environment. Please verify that the EnvironmentId & Role is correct - try running the <c='em'>Get-BapEnvironment</c> or <c='em'>Get-PpacSecurityRole</c> cmdlets."
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
        
        $localUri = $($baseUri + "/api/data/v9.2/roles($($secRoleObj.PpacRoleId))?`$expand=systemuserroles_association")
        $resRoleObj = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersWebApi

        
        $resCol = @(
            $resRoleObj.systemuserroles_association | Select-PSFObject -TypeName "D365Bap.Tools.PpacUser" `
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
         
        if (-not $IncludePpacApplications) {
            $resCol = $resCol | Where-Object PpacAppId -eq $null
        }

        $resCol = $resCol | Where-Object {
            ($_.Name -like $User -or $_.Name -eq $User) `
                -or ($_.PpacSystemUserId -like $User -or $_.PpacSystemUserId -eq $User) `
                -or ($_.PpacAppId -like $User -or $_.PpacAppId -eq $User) `
                -or ($_.EntraObjectId -like $User -or $_.EntraObjectId -eq $User) `
                -or ($_.Upn -like $User -or $_.Upn -eq $User)
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacSecurityRoleMember"
            return
        }

        $resCol
    }
    
    end {
        
    }
}