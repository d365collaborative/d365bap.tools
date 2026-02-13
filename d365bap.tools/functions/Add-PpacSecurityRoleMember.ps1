
<#
    .SYNOPSIS
        Add user to a security role in the Power Platform environment.
        
    .DESCRIPTION
        Enables the user to add an user to a security role in the Power Platform environment.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER Upn
        The UPN of the user you want to add to the security role in the Power Platform environment.
        
    .PARAMETER Role
        The name of the security role you want to add the user to in the Power Platform environment.
        
    .EXAMPLE
        PS C:\> Add-PpacSecurityRoleMember -EnvironmentId "env-123" -Upn "alice@contoso.com" -Role "System Administrator"
        
        This will add the user with the UPN "alice@contoso.com" to the "System Administrator" security role.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Add-PpacSecurityRoleMember {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [string] $Upn,

        [Parameter (Mandatory = $true)]
        [Alias('RoleName')]
        [string] $Role
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

        if (Test-PSFFunctionInterrupt) { return }
        
        $colSecurityRoles = Get-PpacSecurityRole `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $Role

        if ($colSecurityRoles.Count -eq 0) {
            $messageString = "The supplied Role Name / Id: <c='em'>$Role</c> didn't return any matching Security Role in the Power Platform environment. Please verify that the Role Name / Id is correct - try running the <c='em'>Get-PpacSecurityRole</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Security Role was NOT found based on the Role Name / Id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if ($colSecurityRoles.Count -gt 1) {
            $messageString = "The supplied Role Name / Id: <c='em'>$Role</c> returned multiple matching Security Roles in the Power Platform environment. Please verify that the Role Name / Id is correct - try running the <c='em'>Get-PpacSecurityRole</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because multiple Security Roles were found based on the Role Name / Id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $colUsers = Get-PpacUser `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $Upn

        if (Test-PSFFunctionInterrupt) { return }

        # Check if the upn is already added as an user in the Power Platform environment
        $crmUser = $colUsers | `
            Where-Object Upn -eq $Upn | `
            Select-Object -First 1

        if ($null -eq $crmUser) {
            $messageString = "The supplied User with UPN: <c='em'>$Upn</c> is not an user in the Power Platform environment. Please verify that the user exists in the environment - try running the <c='em'>Get-PpacUser</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because user was NOT found based on the UPN." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        # Now we need to assign the Security Role to the application user in the Power Platform environment using the Web API
        $payLoad = [PsCustomObject][ordered]@{
            "@odata.id" = $baseUri + "/api/data/v9.2/roles($($colSecurityRoles[0].PpacRoleId))"
        } | ConvertTo-Json -Depth 10

        $localUri = $baseUri + "/api/data/v9.2/systemusers($($crmUser.PpacSystemUserId))/systemuserroles_association/`$ref"
           
        Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersWebApi `
            -ContentType "application/json" `
            -Body $payLoad `
            -StatusCodeVariable statusRole > $null 4> $null

        if (-not ($statusRole -like "2*")) {
            $messageString = "Failed to assign the Security Role: <c='em'>$($colSecurityRoles[0].Name)</c> to the user in the Power Platform environment. Please try assigning the role manually via the Power Platform admin center - <c='em'>https://aka.ms/ppac</c>"
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because assigning the Security Role to the user failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        Get-PpacUser `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $Upn
    }
    
    end {
        
    }
}