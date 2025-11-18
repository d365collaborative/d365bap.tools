
<#
    .SYNOPSIS
        Set Security Role members from Entra Group in environment
        
    .DESCRIPTION
        Enables the user to set Security Role members in the Power Platform environment based on members from a Security Group in Azure AD / Entra ID.
        
    .PARAMETER EnvironmentId
        Id of the environment that you want to work against.
        
    .PARAMETER ObjectId
        The ObjectId or Display Name of the Security Group in Azure AD / Entra ID that you want to use as source for members to add to the Security Role.
        
    .PARAMETER Role
        The name of the Security Role in the Power Platform environment to which you want to add members from the specified Security Group.
        
    .EXAMPLE
        PS C:\> Set-BapEnvironmentSecurityRoleMember -EnvironmentId *uat* -ObjectId 12345678-90ab-cdef-1234-567890abcdef -Role "System Administrator"
        
        This will add all members from the Security Group with ObjectId "12345678-90ab-cdef-1234-567890abcdef" to the Security Role "System Administrator" in the environment with id containing "uat".
        
    .EXAMPLE
        PS C:\> Set-BapEnvironmentSecurityRoleMember -EnvironmentId *uat* -ObjectId "My Security Group" -Role "Basic User"
        
        This will add all members from the Security Group with Display Name "My Security Group" to the Security Role "Basic User" in the environment with id containing "uat".
        
    .NOTES
        author: Mötz Jensen (@Splaxi)
#>
function Set-BapEnvironmentSecurityRoleMember {
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
        [string] $Role
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

        $baseUri = $envObj.PpacEnvUri

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
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

        $colSecurityRoles = Get-BapEnvironmentSecurityRole -EnvironmentId $envObj.PpacEnvId -Name $Role

        if ($colSecurityRoles.Count -eq 0) {
            $messageString = "The supplied Role Name / Id: <c='em'>$Role</c> didn't return any matching Security Role in the Power Platform environment. Please verify that the Role Name / Id is correct - try running the <c='em'>Get-BapEnvironmentSecurityRole</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Security Role was NOT found based on the Role Name / Id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if ($colSecurityRoles.Count -gt 1) {
            $messageString = "The supplied Role Name / Id: <c='em'>$Role</c> returned multiple matching Security Roles in the Power Platform environment. Please verify that the Role Name / Id is correct - try running the <c='em'>Get-BapEnvironmentSecurityRole</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because multiple Security Roles were found based on the Role Name / Id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $colUsers = Get-BapEnvironmentUser -EnvironmentId $envObj.PpacEnvId

        foreach ($usrObj in $colMembers | Where-Object { $_.'@odata.type' -eq "#microsoft.graph.user" }) {
            $matchedUser = $colUsers | Where-Object { $_.EntraObjectId -eq $usrObj.id } | Select-Object -First 1

            if ($null -eq $matchedUser) {
                $messageString = "The member: <c='em'>$($usrObj.displayName) - $($usrObj.userPrincipalName)</c> from the Security Group: <c='em'>$($colGroups[0].displayName)</c> was not found as a user in the Power Platform environment. Please verify that the user exists in the environment."
                Write-PSFMessage -Level Warning -Message $messageString
                continue
            }

            $payLoad = [PsCustomObject][ordered]@{
                "@odata.id" = $baseUri + "/api/data/v9.2/roles($($colSecurityRoles[0].PpacRoleId))"
            } | ConvertTo-Json -Depth 10

            $localUri = $baseUri + "/api/data/v9.2/systemusers($($matchedUser.PpacSystemUserId))/systemuserroles_association/`$ref"
           
            Invoke-RestMethod -Method Post `
                -Uri $localUri `
                -Headers $headersWebApi `
                -ContentType "application/json" `
                -Body $payLoad > $null
        }
    }
    
    end {
        
    }
}