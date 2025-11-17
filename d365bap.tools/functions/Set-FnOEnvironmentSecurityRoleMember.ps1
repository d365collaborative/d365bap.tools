
<#
    .SYNOPSIS
        Set security role members in a Finance and Operations environment.
        
    .DESCRIPTION
        Enables the user to assign security roles to users in a Finance and Operations environment based on members of an Entra ID (Azure AD) Security Group.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER ObjectId
        The ObjectId of the Entra ID (Azure AD) Security Group whose members you want to assign to the security role.
        
    .PARAMETER Role
        Name or RoleId of the security role to assign the members to.
        
    .PARAMETER ImportMissing
        Instruct the cmdlet to import missing users from the Entra ID (Azure AD) Security Group into the Finance and Operations environment as Claims Users.
        
    .EXAMPLE
        PS C:\> Set-FnOEnvironmentSecurityRoleMember -EnvironmentId *uat* -ObjectId "Developers" -Role "-SYSADMIN-"
        
        This will assign all members of the Entra ID (Azure AD) Security Group with display name starting with "Developers" to the Security Role with the RoleId "-SYSADMIN-" in the Finance and Operations environment.
        
    .EXAMPLE
        PS C:\> Set-FnOEnvironmentSecurityRoleMember -EnvironmentId *uat* -ObjectId "b1a2c3d4-e5f6-4789-9012-34567abcdef" -Role "System Administrator"
        
        This will assign all members of the Entra ID (Azure AD) Security Group with the ObjectId "b1a2c3d4-e5f6-4789-9012-34567abcdef" to the Security Role with the name "System Administrator" in the Finance and Operations environment.
        
    .EXAMPLE
        PS C:\> Set-FnOEnvironmentSecurityRoleMember -EnvironmentId *uat* -ObjectId "b1a2c3d4-e5f6-4789-9012-34567abcdef" -Role "System Administrator" -ImportMissing
        
        This will assign all members of the Entra ID (Azure AD) Security Group with the ObjectId "b1a2c3d4-e5f6-4789-9012-34567abcdef" to the Security Role with the name "System Administrator" in the Finance and Operations environment.
        Will import any missing users from the Entra ID (Azure AD) Security Group into the Finance and Operations environment as Claims Users prior to assigning the security role.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-FnOEnvironmentSecurityRoleMember {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [Alias('EntraGroup')]
        [string] $ObjectId,

        [Parameter (Mandatory = $true)]
        [Alias('RoleName')]
        [string] $Role,

        [switch] $ImportMissing
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

        $baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'
        
        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersFnO = @{
            "Authorization" = "Bearer $($tokenFnoOdataValue)"
        }
         
        $secureTokenGraph = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/" -AsSecureString).Token
        $tokenGraphValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenGraph

        $headersGraphApi = @{
            "Authorization" = "Bearer $($tokenGraphValue)"
            "Content-Type"  = "application/json"
        }

        $uriGraphBase = 'https://graph.microsoft.com/v1.0/groups?$select=id,displayName&'
        if (Test-Guid -InputObject $ObjectId) {
            # Validate that the Security Group exists in Azure AD / Entra ID
            $uriGraph = "$uriGraphBase`$filter=id eq '$ObjectId'"
        }
        else {
            $uriGraph = "$uriGraphBase`$filter=startswith(displayName, '$ObjectId')"
        }

        $colGroups = Invoke-RestMethod -Method Get `
            -Uri $uriGraph `
            -Headers $headersGraphApi | Select-Object -ExpandProperty Value

        if ($colGroups.Count -eq 0) {
            $messageString = "The supplied ObjectId / Entra Group: <c='em'>$ObjectId</c> didn't return any matching Security Group in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADGroup</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Security Group was NOT found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if ($colGroups.Count -gt 1) {
            $messageString = "The supplied ObjectId / Entra Group: <c='em'>$ObjectId</c> returned multiple matching Security Groups in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADGroup</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because multiple Security Groups were found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        $uriGraphMembers = "https://graph.microsoft.com/v1.0/groups/$($colGroups[0].id)/transitiveMembers`?`$select=id,displayName,mail,userPrincipalName"
        $colMembers = Invoke-RestMethod -Method Get `
            -Uri $uriGraphMembers `
            -Headers $headersGraphApi | Select-Object -ExpandProperty Value

        if ($colMembers.Count -eq 0) {
            $messageString = "The Security Group: <c='em'>$($colGroups[0].displayName)</c> doesn't contain any members. Please verify that the Security Group has members."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because the Security Group has no members." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        $colSecurityRoles = Get-FnOEnvironmentSecurityRole -EnvironmentId $envObj.PpacEnvId -Name $Role

        if ($colSecurityRoles.Count -eq 0) {
            $messageString = "The supplied Role Name / Id: <c='em'>$Role</c> didn't return any matching Security Role in the Dynamics 365 ERP environment. Please verify that the Role Name / Id is correct - try running the <c='em'>Get-FnOEnvironmentSecurityRole</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Security Role was NOT found based on the Role Name / Id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if ($colSecurityRoles.Count -gt 1) {
            $messageString = "The supplied Role Name / Id: <c='em'>$Role</c> returned multiple matching Security Roles in the Dynamics 365 ERP environment. Please verify that the Role Name / Id is correct - try running the <c='em'>Get-FnOEnvironmentSecurityRole</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because multiple Security Roles were found based on the Role Name / Id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $colUsers = Get-FnOEnvironmentUser -EnvironmentId $envObj.PpacEnvId
        $colAssignedUsers = Get-FnOEnvironmentSecurityRoleMember -EnvironmentId $envObj.PpacEnvId `
            -Role $colSecurityRoles[0].FnORoleId

        foreach ($usrObj in $colMembers | Where-Object { $_.'@odata.type' -eq "#microsoft.graph.user" }) {
            $matchedUser = $colUsers | Where-Object { $_.Upn -eq $usrObj.userPrincipalName } | Select-Object -First 1

            if ($null -eq $matchedUser) {
                if ($ImportMissing) {
                    
                    $payloadUser = [PsCustomObject][ordered]@{
                        "UserID"            = $usrObj.userPrincipalName.Split('@')[0] + "_imp"
                        "NetworkDomain"     = "https://sts.windows.net/"
                        "UserInfo_language" = "en-us"
                        "Helplanguage"      = "en-us"
                        "UserName"          = $usrObj.userPrincipalName.Split('@')[0]
                        "Email"             = $usrObj.userPrincipalName
                        "Company"           = "DAT"
                        "Alias"             = $usrObj.userPrincipalName
                        "AccountType"       = "ClaimsUser"
                        "Theme"             = "Theme1"
                        "Enabled"           = $true
                    } | ConvertTo-Json

                    Invoke-RestMethod -Method Post `
                        -Uri ($baseUri + '/data/SystemUsers') `
                        -Headers $headersFnO `
                        -Body $payloadUser `
                        -ContentType 'application/json; charset=utf-8' > $null

                    continue
                }

                $messageString = "The member: <c='em'>$($usrObj.displayName) - $($usrObj.userPrincipalName)</c> from the Security Group: <c='em'>$($colGroups[0].displayName)</c> was not found as a user in the Dynamics 365 ERP environment. Please verify that the user exists in the environment."
                Write-PSFMessage -Level Warning -Message $messageString
                continue
            }

            if ($colAssignedUsers.FnOUserId `
                    -contains $matchedUser.FnOUserId) { continue }

            $payload = [PsCustomObject][ordered]@{
                "SecurityRoleIdentifier" = $colSecurityRoles[0].FnORoleId
                "UserId"                 = $matchedUser.FnOUserId
                "AssignmentStatus"       = "Enabled"
                "AssignmentMode"         = "Manual"
                "SecurityRoleName"       = $colSecurityRoles[0].Name
                "UserLicenseType"        = $colSecurityRoles[0].License
            } | ConvertTo-Json

            Invoke-RestMethod -Method Post `
                -Uri ($baseUri + '/data/SecurityUserRoles') `
                -Headers $headersFnO `
                -Body $payload `
                -ContentType 'application/json; charset=utf-8' > $null
        }
    }
    
    end {
        
    }
}