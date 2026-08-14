
<#
    .SYNOPSIS
        Add a user to a Finance and Operations environment and assign them a security role.
        
    .DESCRIPTION
        This cmdlet adds a user to a Finance and Operations environment and assigns them a security role.
        It retrieves the user information from Azure AD / Entra ID based on the provided user identifier, creates or updates the user in the Finance and Operations environment, and assigns the specified security role to the user.
        
    .PARAMETER EnvironmentId
        The ID of the environment to add the user to.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER User
        The name or ID of the user to add to the environment.
        
        Can be either the user name, user ID or user principal name (UPN).
        
    .PARAMETER Role
        The security role to assign to the user.
        
        Can be either the role name or role ID. If not specified, the default role "System user" will be assigned.
        
    .PARAMETER RemapExisting
        Instructs the function to remap existing users to the specified security role.
        
        If a user is not found in the Finance and Operations environment based on the UPN, but a user with the same UserId exists, the function will - by default - skip the user.
        
        If this switch is used, it will remap the existing user to the new UPN and assign the specified security role.
        
    .EXAMPLE
        PS C:\> Add-FscmUser -EnvironmentId "ContosoEnv" -User "john.doe"
        
        This command adds the user with the user name "john.doe" to the environment "ContosoEnv".
        It will assign the default security role "System user".
        
    .EXAMPLE
        PS C:\> Add-FscmUser -EnvironmentId "ContosoEnv" -User "john.doe" -Role "Sales tax manager"
        
        This command adds the user with the user name "john.doe" to the environment "ContosoEnv".
        It will assign the security role "Sales tax manager".
        
    .EXAMPLE
        PS C:\> Add-FscmUser -EnvironmentId "ContosoEnv" -User "john.doe" -RemapExisting
        
        This command adds the user with the user name "john.doe" to the environment "ContosoEnv".
        If a user with the same UserId as "john.doe" already exists in the environment, it will remap the existing user to the new UPN.
        It will assign the default security role "System user".
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Add-FscmUser {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,
        
        [Parameter (Mandatory = $true)]
        [string] $User,
        
        [Alias('RoleName')]
        [string] $Role = "System user",

        [switch] $RemapExisting
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
        
        $usrObj = Get-GraphUser `
            -User $User

        if ($null -eq $usrObj) {
            $messageString = "The supplied User: <c='em'>$User</c> didn't return any matching user details in Azure AD / Entra ID. Please verify that the User is correct - try running the <c='em'>Get-AzADUser</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because user was NOT found based on the UPN." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $secRoleObj = Get-FscmSecurityRole `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $Role | `
            Select-Object -First 1

        if ($null -eq $secRoleObj) {
            $messageString = "The supplied Role Name / Id: <c='em'>$Role</c> didn't return any matching Security Role in the Dynamics 365 ERP environment. Please verify that the Role Name / Id is correct - try running the <c='em'>Get-FscmSecurityRole</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Security Role was NOT found based on the Role Name / Id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }
    
        $colUsers = Get-FscmUser `
            -EnvironmentId $envObj.PpacEnvId
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $matchedUser = $colUsers | Where-Object {
            $_.Upn -eq $usrObj.userPrincipalName `
                -or $_.Upn -eq $usrObj.mail
        } | Select-Object -First 1

        if ($null -eq $matchedUser) {
            $tenantExternal = ''
            $tmpId = $usrObj.mail.Split('@')[0]
                
            if ($tmpId -in $colUsers.UserId -and (-not $RemapExisting)) {
                $messageString = "The user: <c='em'>$($usrObj.userPrincipalName) | $($usrObj.mail)</c> was not found as a user in the Dynamics 365 ERP environment based on the UPN. However, a user with the same UserId: <c='em'>$tmpId</c> exists in the environment. Skipping the user - if you want to remap the existing user to the new UPN, please run the command with the <c='em'>-RemapExisting</c> switch."
                Write-PSFMessage -Level Warning -Message $messageString
                Stop-PSFFunction -Message "Stopping because user with same UserId already exists and -RemapExisting switch was not used." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
            
            if ($usrObj.userPrincipalName -ne $usrObj.mail) {
                $tenantExternal = $usrObj.mail.Split('@')[1] + "/"
            }
            
            if ($tmpId -in $colUsers.UserId) {
                $payloadUser = [PsCustomObject][ordered]@{
                    "NetworkDomain" = "https://sts.windows.net/$tenantExternal"
                    "UserName"      = $usrObj.displayName
                    "Email"         = $usrObj.mail
                    "Alias"         = $usrObj.mail
                    "Enabled"       = $true
                } | ConvertTo-Json
                    
                $parmsUser = @{
                    Method = "Patch"
                    Uri    = $baseUri + "/data/SystemUsers(UserID='$tmpId')"
                }
            }
            else {
                $payloadUser = [PsCustomObject][ordered]@{
                    "UserID"            = $usrObj.mail.Split('@')[0]
                    "NetworkDomain"     = "https://sts.windows.net/$tenantExternal"
                    "UserInfo_language" = "en-us"
                    "Helplanguage"      = "en-us"
                    "UserName"          = $usrObj.displayName
                    "Email"             = $usrObj.mail
                    "Company"           = "DAT"
                    "Alias"             = $usrObj.mail
                    "AccountType"       = "ClaimsUser"
                    "Theme"             = "Theme1"
                    "Enabled"           = $true
                } | ConvertTo-Json

                $parmsUser = @{
                    Method = "Post"
                    Uri    = $baseUri + "/data/SystemUsers"
                }
            }

            Invoke-RestMethod @parmsUser `
                -Headers $headersFnO `
                -Body $payloadUser `
                -ContentType $headersFnO.'Content-Type' `
                -StatusCodeVariable statusUser > $null 4> $null

            if (-not $statusUser -like "2*" ) {
                $messageString = "Something went wrong when creating/updating the user: <c='em'>$($usrObj.userPrincipalName)</c> in the Dynamics 365 ERP environment. HTTP Status Code: <c='em'>$statusUser</c>. Please investigate."
                Write-PSFMessage -Level Warning -Message $messageString
                Stop-PSFFunction -Message "Stopping because user could not be created/updated." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
        }

        $colUsers = Get-FscmUser `
            -EnvironmentId $envObj.PpacEnvId
            
        $colAssignedUsers = Get-FscmSecurityRoleMember `
            -EnvironmentId $envObj.PpacEnvId `
            -Role $secRoleObj.FscmRoleId

        $matchedUser = $colUsers | Where-Object {
            $_.Upn -eq $usrObj.userPrincipalName `
                -or $_.Upn -eq $usrObj.mail
        } | Select-Object -First 1
            
        if ($null -eq $matchedUser) {
            $messageString = "The user: <c='em'>$($usrObj.userPrincipalName)</c> was expected to be found as a user in the Dynamics 365 ERP environment based on the UPN after the creation/update, but was not found. Please verify that the user was created/updated successfully and investigate."
            Write-PSFMessage -Level Warning -Message $messageString
            Stop-PSFFunction -Message "Stopping because user was NOT found based on the UPN after creation/update." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        if ($matchedUser.FscmUserId -in $colAssignedUsers.FscmUserId) {
            return
        }

        if ($matchedUser.FscmUserId -eq 'Admin') {
            return
        }

        $payload = [PsCustomObject][ordered]@{
            "SecurityRoleIdentifier" = $secRoleObj.FscmRoleId
            "UserId"                 = $matchedUser.FscmUserId
            "AssignmentStatus"       = "Enabled"
            "AssignmentMode"         = "Manual"
            "SecurityRoleName"       = $secRoleObj.Name
            "UserLicenseType"        = $secRoleObj.License
        } | ConvertTo-Json

        Invoke-RestMethod -Method Post `
            -Uri ($baseUri + '/data/SecurityUserRoles') `
            -Headers $headersFnO `
            -Body $payload `
            -ContentType $headersFnO.'Content-Type' `
            -StatusCodeVariable statusUserRoleMapping > $null 4> $null

        if (-not $statusUserRoleMapping -like "2*" ) {
            $messageString = "Something went wrong when assigning the user: <c='em'>$($matchedUser.Upn)</c> to the role: <c='em'>$($secRoleObj.Name)</c> in the Dynamics 365 ERP environment. HTTP Status Code: <c='em'>$statusUserRoleMapping</c>. Please investigate."
            Write-PSFMessage -Level Warning -Message $messageString
            Stop-PSFFunction -Message "Stopping because user could not be assigned to the role." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
    }

    end {
        
    }
}