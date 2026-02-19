
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
        
        Can be either the user name, user ID or user principal name (UPN).
        
        Supports wildcard characters for flexible matching.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved security role member information to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-FscmSecurityRoleMember -EnvironmentId "ContosoEnv" -Role "System Administrator"
        
        This command retrieves the members of the Finance and Operations security role with the name "System Administrator" from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-FscmSecurityRoleMember -EnvironmentId "ContosoEnv" -Role "-SYSADMIN-" -User "*john*"
        
        This command retrieves the members of the Finance and Operations security role with names matching "-SYSADMIN-" from the environment "ContosoEnv" and filters the members to those with user names, user IDs or UPNs matching "*john*". The information is displayed in the console.
        
    .EXAMPLE
        PS C:\> Get-FscmSecurityRoleMember -EnvironmentId "ContosoEnv" -Role "System Administrator" -AsExcelOutput
        
        This command retrieves the members of the Finance and Operations security role with the name "System Administrator" from the environment "ContosoEnv".
        It will export the information to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmSecurityRoleMember {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [Alias("Name")]
        [Alias("SecurityRoleId")]
        [string] $Role,

        [string] $User = "*",

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

        $secRoleObj = Get-FscmSecurityRole -EnvironmentId $EnvironmentId `
            -Name $Role | `
            Select-Object -First 1

        if ($null -eq $secRoleObj) {
            $messageString = "The supplied: <c='em'>$Role</c> didn't return any matching security details from the Environment. Please verify that the EnvironmentId & Role is correct - try running the <c='em'>Get-BapEnvironment</c> or <c='em'>Get-FscmSecurityRole</c> cmdlets."
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

        $localUri = $baseUri + '/data/SystemUsers?$select=UserID,UserName,Alias,Company,UserInfo_language,Enabled'
        $colUsersRaw = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersFnO | Select-Object -ExpandProperty value

        $localUri = $baseUri + "/data/SecurityUserRoles?`$filter=SecurityRoleIdentifier eq '$($secRoleObj.FscmRoleId)'"
        $colUserRolesRaw = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersFnO | Select-Object -ExpandProperty value
            
        $colUsers = $colUsersRaw | Where-Object {
            $_.UserID -in $colUserRolesRaw.UserId
        } | Sort-Object -Property UserID

        $colUsers = $colUsers | Where-Object {
            ($_.UserID -like $User -or $_.UserID -eq $User) `
                -or ($_.UserName -like $User -or $_.UserName -eq $User) `
                -or ($_.Alias -like $User -or $_.Alias -eq $User)
        } | Sort-Object -Property UserID

        $resCol = @(
            $colUsers | Select-PSFObject -TypeName "D365Bap.Tools.FscmUser" `
                -ExcludeProperty "@odata.etag", "Language", "UserID" `
                -Property "UserID as FscmUserId",
            "UserID as UserId",
            "Company as LegalEntity",
            "UserName as Name",
            "Alias as Upn",
            "UserInfo_language as Language",
            *
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-FscmSecurityRoleMember"
            return
        }

        $resCol
    }
    
    end {
        
    }
}