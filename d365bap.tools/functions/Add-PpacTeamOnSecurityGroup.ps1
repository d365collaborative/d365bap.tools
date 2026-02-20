
<#
    .SYNOPSIS
        Enables assignment of a Microsoft Entra ID security group as a team in the Power Platform environment.
        
    .DESCRIPTION
        This cmdlet assigns a Microsoft Entra ID security group as a team in the specified Power Platform environment and assigns a security role to the team.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Name
        The name of the team to create in the Power Platform environment.
        
    .PARAMETER SecurityGroup
        The Microsoft Entra ID security group that you want to assign as a team in the Power Platform environment.
        
        Can be either the name or the id (objectId) of the Microsoft Entra ID security group.
        
    .PARAMETER MembershipType
        The membership type of the team.
        
        Can be either "Members and Guests", "Members", "Guests", or "Owners".
        
    .PARAMETER Role
        The security role that you want to assign to the team.
        
        Can be either the role name or the role ID.
        
    .PARAMETER TeamAdmin
        The User Principal Name (UPN) of the admin user in the Power Platform environment.
        
        This user needs to have sufficient permissions to create teams and assign security roles in the Power Platform environment.
        
        If not provided, the cmdlet will use the account used to authenticate to Azure.
        
    .EXAMPLE
        PS C:\> Add-PpacTeamOnSecurityGroup -EnvironmentId "env-123" -Name "Contoso Sales Team" -SecurityGroup "Contoso Sales Security Group" -MembershipType "Members and Guests" -Role "System Customizer"
        
        This will add the Microsoft Entra ID security group "Contoso Sales Security Group" as a team in the Power Platform environment with the id "env-123".
        The team will be named "Contoso Sales Team" and have the membership type "Members and Guests".
        The "System Customizer" security role will be assigned to the team.
        The administrator of the team will be the user running the cmdlet.
        
    .EXAMPLE
        C:\> Add-PpacTeamOnSecurityGroup -EnvironmentId "env-123" -Name "Contoso Sales Team" -SecurityGroup "Contoso Sales Security Group" -MembershipType "Members and Guests" -Role "System Customizer" -TeamAdmin "admin@contoso.com"
        
        This will add the Microsoft Entra ID security group "Contoso Sales Security Group" as a team in the Power Platform environment with the id "env-123".
        The team will be named "Contoso Sales Team" and have the membership type "Members and Guests".
        The "System Customizer" security role will be assigned to the team.
        The administrator of the team will be "admin@contoso.com".
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Add-PpacTeamOnSecurityGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [Alias('Team')]
        [string] $Name,

        [Parameter (Mandatory = $true)]
        [Alias('EntraGroup')]
        [string] $SecurityGroup,

        [ValidateSet("Members and Guests", "Members", "Guests", "Owners")]
        [string] $MembershipType = "Members",

        [Parameter (Mandatory = $true)]
        [Alias('RoleName')]
        [string] $Role,

        [string] $TeamAdmin
    )
    
    begin {
        $secGrp = $null

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

        $secGrp = Get-GraphGroup `
            -Group $SecurityGroup
            
        if (Test-PSFFunctionInterrupt) { return }

        if ([System.String]::IsNullOrEmpty($TeamAdmin)) {
            $TeamAdmin = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString).UserId
        }
        
        $userObj = Get-PpacUser `
            -EnvironmentId $envObj.PpacEnvId `
            -User $TeamAdmin | `
            Select-Object -First 1
        
        if ($null -eq $userObj) {
            $messageString = "The supplied TeamAdmin: <c='em'>$TeamAdmin</c> didn't return any matching user details in the Power Platform environment. Please verify that the TeamAdmin is correct and that the user exists in the environment."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because no matching user was found for the supplied TeamAdmin." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        $secRoleObj = Get-PpacSecurityRole `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $Role | `
            Select-Object -First 1

        if ($null -eq $secRoleObj) {
            $messageString = "The supplied Role: <c='em'>$Role</c> didn't return any matching security role details in the Power Platform environment. Please verify that the Role name is correct and that the role exists in the environment."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because no matching security role was found for the supplied Role name." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $colTeams = Get-PpacTeam `
            -EnvironmentId $envObj.PpacEnvId

        $teamObj = $colTeams | `
            Where-Object { $_.EntraObjectId -eq $secGrp.id `
                -and $_.MembershipType -eq $MembershipType } | `
            Select-Object -First 1

        if ($null -ne $teamObj) {
            $messageString = "A team with the same Microsoft Entra ID Object Id and Membership Type already exists in the Power Platform environment. Please verify that the supplied Security Group and Membership Type combination is correct. Existing team: <c='em'>$($teamObj.TeamName)</c> - Membership Type: <c='em'>$($teamObj.MembershipType)</c>."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because a team with the same Microsoft Entra ID Object Id and Membership Type already exists in the Power Platform environment." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

            return
        }

        #First we need to get the default Business Unit
        $colBunits = Get-CrmBusinessUnit -BaseUri $baseUri

        $businessObj = $colBunits | `
            Where-Object IsRoot -eq $true | `
            Select-Object -First 1

        $hashMembType = @{
            "Members and Guests" = 0
            "Members"            = 1
            "Guests"             = 2
            "Owners"             = 3
        }

        $payload = [PsCustomObject][ordered]@{
            "teamtype"                     = 2 # Security Group
            "name"                         = $Name
            "membershiptype"               = $hashMembType[$MembershipType]
            "isdefault"                    = $false
            "azureactivedirectoryobjectid" = $secGrp.id
            "businessunitid@odata.bind"    = "/businessunits($($businessObj.Id))"
            "administratorid@odata.bind"   = "/systemusers($($userObj.PpacSystemUserId))"
        } | ConvertTo-Json -Depth 10


        $localHeaders = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
            "Content-Type"  = "application/json"
        }

        $localUri = $baseUri + "/api/data/v9.2/teams"
        
        Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $localHeaders `
            -ContentType $localHeaders."Content-Type" `
            -Body $payload `
            -StatusCodeVariable statusTeam > $null 4> $null

        if (-not ($statusTeam -like "2*")) {
            $messageString = "Failed to create the team in the Power Platform environment. Please try creating the team manually via the Power Platform admin center - <c='em'>https://aka.ms/ppac</c>"
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because creating the team in the Power Platform environment failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $crmTeam = Get-PpacTeam `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $Name | `
            Select-Object -First 1

        # Now we need to assign the Security Role to the application user in the Power Platform environment using the Web API
        $payload = [PsCustomObject][ordered]@{
            "@odata.id" = $baseUri + "/api/data/v9.2/roles($($secRoleObj.PpacRoleId))"
        } | ConvertTo-Json -Depth 10

        $localUri = $baseUri + "/api/data/v9.2/teams($($crmTeam.PpacTeamId))/teamroles_association/`$ref"

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

        Get-PpacTeam `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $Name | `
            Select-Object -First 1
    }
    
    end {
        
    }
}