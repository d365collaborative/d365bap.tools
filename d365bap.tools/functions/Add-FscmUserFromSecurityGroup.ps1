
<#
    .SYNOPSIS
        Enables creation of users from an Entra Security Group in the Dynamics 365 ERP environment.
        
    .DESCRIPTION
        This cmdlet creates users in the specified Dynamics 365 ERP environment based on the members of an Entra Security Group.
        
        It will also assign the created users to a specified security role in the Dynamics 365 ERP environment.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER SecurityGroup
        The name or ID of the Entra Security Group from which to create users.
        
    .PARAMETER Role
        The security role to assign to the created users.
        
    .PARAMETER RemapExisting
        Instructs the function to remap existing users to the specified security role.
        
        If a user from the Security Group is not found in the Dynamics 365 ERP environment based on the UPN, but a user with the same UserId exists, the function will - by default - skip the user.
        
        If this switch is used, it will remap the existing user to the new UPN and assign the specified security role.
        
    .EXAMPLE
        PS C:\> Add-FscmUserFromSecurityGroup -EnvironmentId "env-123" -SecurityGroup "Contoso Sales Team" -Role "Sales Clerk"
        
        This will create users in the environment with the id "env-123" based on the members of the Entra Security Group "Contoso Sales Team" and assign them to the "Sales Clerk" security role.
        It will validate users based on their UPN, and if a user is not found but a user with the same UserId exists, it will skip the user.
        
    .EXAMPLE
        PS C:\> Add-FscmUserFromSecurityGroup -EnvironmentId "env-123" -SecurityGroup "Contoso Sales Team" -Role "Sales Clerk" -RemapExisting
        
        This will create users in the environment with the id "env-123" based on the members of the Entra Security Group "Contoso Sales Team" and assign them to the "Sales Clerk" security role.
        It will validate users based on their UPN, and if a user is not found but a user with the same UserId exists, it will remap the existing user to the new UPN and assign the specified security role.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Add-FscmUserFromSecurityGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [Alias('EntraGroup')]
        [string] $SecurityGroup,

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

        $secGrp = Get-GraphGroup `
            -Group $SecurityGroup
            
        if (Test-PSFFunctionInterrupt) { return }
        
        $colMembersRaw = Get-GraphGroupMember `
            -GroupId $secGrp.id

        $colMembers = $colMembersRaw | Where-Object {
            $_.'@odata.type' -eq "#microsoft.graph.user"
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

        foreach ($usrObj in $colMembers) {
            $matchedUser = $colUsers | Where-Object {
                $_.Upn -eq $usrObj.userPrincipalName
            } | Select-Object -First 1

            if ($null -eq $matchedUser) {
                $tmpId = $usrObj.userPrincipalName.Split('@')[0]
                
                if ($tmpId -in $colUsers.UserId -and (-not $RemapExisting)) {
                    $messageString = "The member: <c='em'>$($usrObj.userPrincipalName)</c> from the Security Group: <c='em'>$($secGrp.displayName)</c> was not found as a user in the Dynamics 365 ERP environment based on the UPN. However, a user with the same UserId: <c='em'>$tmpId</c> exists in the environment. Skipping the user - if you want to remap the existing user to the new UPN, please run the command with the <c='em'>-RemapExisting</c> switch."
                    Write-PSFMessage -Level Warning -Message $messageString

                    continue
                }

                if ($tmpId -in $colUsers.UserId) {
                    $payloadUser = [PsCustomObject][ordered]@{
                        "Email"   = $usrObj.userPrincipalName
                        "Alias"   = $usrObj.userPrincipalName
                        "Enabled" = $true
                    } | ConvertTo-Json
                    
                    $parmsUser = @{
                        Method = "Patch"
                        Uri    = $baseUri + "/data/SystemUsers(UserID='$tmpId')"
                    }
                }
                else {
                    $payloadUser = [PsCustomObject][ordered]@{
                        "UserID"            = $usrObj.userPrincipalName.Split('@')[0]
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

                    continue
                }
            }
        }

        $colUsers = Get-FscmUser `
            -EnvironmentId $envObj.PpacEnvId
            
        $colAssignedUsers = Get-FscmSecurityRoleMember `
            -EnvironmentId $envObj.PpacEnvId `
            -Role $secRoleObj.FscmRoleId

        foreach ($usrObj in $colMembers) {
            $matchedUser = $colUsers | Where-Object { $_.Upn -eq $usrObj.userPrincipalName } | Select-Object -First 1
            
            if ($null -eq $matchedUser) {
                continue
            }

            if ($matchedUser.FscmUserId -in $colAssignedUsers.FscmUserId) {
                continue
            }

            if ($matchedUser.FscmUserId -eq 'Admin') {
                continue
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

                continue
            }
        }
    }

    end {
        
    }
}