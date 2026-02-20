
<#
    .SYNOPSIS
        Set Security Role for a team in a Power Platform environment.
        
    .DESCRIPTION
        This cmdlet allows you to set a Security Role for a team in a Power Platform environment. It can be used to configure a Security Role to a team.
        
    .PARAMETER EnvironmentId
        The ID of the environment to set the Security Role for.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Team
        The name or ID of the team to set the Security Role for.
        
        Can be either the team name or the team ID.
        
    .PARAMETER Role
        The name or ID of the Security Role to assign to the team.
        
        Can be either the role name or the role ID.
        
        Multiple roles / array of roles are supported.
        
    .EXAMPLE
        PS C:\> Set-PpacTeamSecurityRole -EnvironmentId "ContosoEnv" -Team "ContosoTeam" -Role "ContosoRole"
        
        This command sets the Security Role "ContosoRole" for the team "ContosoTeam" in the Power Platform environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Set-PpacTeamSecurityRole -EnvironmentId "ContosoEnv" -Team "ContosoTeam" -Role "ContosoRole1","ContosoRole2"
        
        This command sets the Security Roles "ContosoRole1" and "ContosoRole2" for the team "ContosoTeam" in the Power Platform environment "ContosoEnv".
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-PpacTeamSecurityRole {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [Alias('Name')]
        [string] $Team,

        [Parameter (Mandatory = $true)]
        [Alias('RoleName')]
        [string[]] $Role
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

        $teamObj = Get-PpacTeam `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $Team | `
            Select-Object -First 1

        if ($null -eq $teamObj) {
            $messageString = "The supplied team name: <c='em'>$Team</c> didn't return any matching team details in the Power Platform environment. Please verify that the team name is correct - try running the <c='em'>Get-PpacTeam</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because team was NOT found based on the name." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        $colSecurityRoles = Get-PpacSecurityRole `
            -EnvironmentId $envObj.PpacEnvId

        if (Test-PSFFunctionInterrupt) { return }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $localHeaders = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
            "Content-Type"  = "application/json"
        }

        foreach ($roleName in $role) {
            $roleObj = $colSecurityRoles | `
                Where-Object Name -eq $roleName | `
                Select-Object -First 1

            if ($null -eq $roleObj) {
                $messageString = "The supplied role name: <c='em'>$roleName</c> didn't return any matching role details in the Power Platform environment. Please verify that the role name is correct - try running the <c='em'>Get-PpacSecurityRole</c> cmdlet."
                Write-PSFMessage -Level Important -Message $messageString
                continue
            }

            # Now we need to assign the Security Role to the application user in the Power Platform environment using the Web API
            $payload = [PsCustomObject][ordered]@{
                "@odata.id" = $baseUri + "/api/data/v9.2/roles($($roleObj.PpacRoleId))"
            } | ConvertTo-Json -Depth 10

            $localUri = $baseUri + "/api/data/v9.2/teams($($teamObj.PpacTeamId))/teamroles_association/`$ref"

            Invoke-RestMethod -Method Post `
                -Uri $localUri `
                -Headers $localHeaders `
                -ContentType $localHeaders."Content-Type" `
                -Body $payload `
                -StatusCodeVariable statusRole > $null 4> $null

            if (-not ($statusRole -like "2*")) {
                $messageString = "Failed to assign the security role to the team in the Power Platform environment. Please try assigning the role manually via the Power Platform admin center - <c='em'>https://aka.ms/ppac</c>"
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because assigning the security role to the team in the Power Platform environment failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
        }
        
        Get-PpacTeam `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $Team | `
            Select-Object -First 1
    }
    
    end {
        
    }
}