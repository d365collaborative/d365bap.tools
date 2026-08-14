
<#
    .SYNOPSIS
        Set the table privileges of a security role in a given environment.
        
    .DESCRIPTION
        This cmdlet sets the privileges of a table (entity) on a security role in a given Power Platform environment.
        
        It mimics editing the table permissions in the security role editor in the Power Platform admin center, where each privilege type (Create, Read, Write, Delete, Append, AppendTo, Assign and Share) can be configured with an access level.
        
        The access levels use the Power Platform admin center naming and are translated automatically to the Dataverse privilege depths accepted by the Web API:
        "User" - Basic
        "BusinessUnit" - Local
        "ParentChildBusinessUnit" - Deep
        "Organization" - Global
        "None" - None
        
        Privilege types that are not supplied (or set to "None") are removed from the role for the table. Access levels of already assigned privileges are updated to the supplied values.
        
        It uses the AddPrivilegesRole and ReplacePrivilegesRole actions of the Dataverse Web API, against the root record of the security role - the inherited business unit copies of the role are managed by Dataverse.
        
    .PARAMETER EnvironmentId
        The ID of the environment to work against.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Role
        The security role that you want to work against.
        
        Can be either the role name or the role ID.
        
    .PARAMETER Table
        The table (entity) that you want to set the privileges for.
        
        Can be either the table display name, the logical name or the schema name.
        
    .PARAMETER Create
        The access level for the Create privilege of the table.
        
        Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".
        
        The default value is "None".
        
    .PARAMETER Read
        The access level for the Read privilege of the table.
        
        Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".
        
        The default value is "None".
        
    .PARAMETER Write
        The access level for the Write privilege of the table.
        
        Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".
        
        The default value is "None".
        
    .PARAMETER Delete
        The access level for the Delete privilege of the table.
        
        Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".
        
        The default value is "None".
        
    .PARAMETER Append
        The access level for the Append privilege of the table.
        
        Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".
        
        The default value is "None".
        
    .PARAMETER AppendTo
        The access level for the AppendTo privilege of the table.
        
        Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".
        
        The default value is "None".
        
    .PARAMETER Assign
        The access level for the Assign privilege of the table.
        
        Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".
        
        The default value is "None".
        
    .PARAMETER Share
        The access level for the Share privilege of the table.
        
        Valid options: "None", "User", "BusinessUnit", "ParentChildBusinessUnit", "Organization".
        
        The default value is "None".
        
    .EXAMPLE
        PS C:\> Set-PpacSecurityRoleTable -EnvironmentId "ContosoEnv" -Role "Monitoring Reader" -Table "businessunit" -Read "Organization"
        
        This command sets the privileges of the table "businessunit" on the security role "Monitoring Reader" in the environment "ContosoEnv".
        The Read privilege is set to the "Organization" access level.
        All other privileges of the table are removed from the role.
        
    .EXAMPLE
        PS C:\> Set-PpacSecurityRoleTable -EnvironmentId "ContosoEnv" -Role "Monitoring Reader" -Table "Sharepoint Document" -Create "User" -Read "Organization" -Write "User" -Append "User" -AppendTo "User"
        
        This command sets the privileges of the table "Sharepoint Document" on the security role "Monitoring Reader" in the environment "ContosoEnv".
        The Read privilege is set to the "Organization" access level.
        The Create, Write, Append and AppendTo privileges are set to the "User" access level.
        The Delete, Assign and Share privileges are removed from the role.
        
    .EXAMPLE
        PS C:\> Set-PpacSecurityRoleTable -EnvironmentId "ContosoEnv" -Role "Monitoring Reader" -Table "businessunit"
        
        This command removes all privileges of the table "businessunit" from the security role "Monitoring Reader" in the environment "ContosoEnv".
        
    .NOTES
        Author: Trygve Bechsgaard
#>
function Set-PpacSecurityRoleTable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [Alias('RoleName')]
        [string] $Role,

        [Parameter (Mandatory = $true)]
        [Alias('TableName')]
        [string] $Table,

        [ValidateSet('None', 'User', 'BusinessUnit', 'ParentChildBusinessUnit', 'Organization')]
        [string] $Create = 'None',

        [ValidateSet('None', 'User', 'BusinessUnit', 'ParentChildBusinessUnit', 'Organization')]
        [string] $Read = 'None',

        [ValidateSet('None', 'User', 'BusinessUnit', 'ParentChildBusinessUnit', 'Organization')]
        [string] $Write = 'None',

        [ValidateSet('None', 'User', 'BusinessUnit', 'ParentChildBusinessUnit', 'Organization')]
        [string] $Delete = 'None',

        [ValidateSet('None', 'User', 'BusinessUnit', 'ParentChildBusinessUnit', 'Organization')]
        [string] $Append = 'None',

        [ValidateSet('None', 'User', 'BusinessUnit', 'ParentChildBusinessUnit', 'Organization')]
        [string] $AppendTo = 'None',

        [ValidateSet('None', 'User', 'BusinessUnit', 'ParentChildBusinessUnit', 'Organization')]
        [string] $Assign = 'None',

        [ValidateSet('None', 'User', 'BusinessUnit', 'ParentChildBusinessUnit', 'Organization')]
        [string] $Share = 'None'
    )

    begin {
        # Translate the Power Platform admin center access level naming to the
        # Dataverse privilege depth naming - only the depth naming is accepted by the Web API.
        # The translated values must be stored in a separate hashtable - the ValidateSet attribute
        # stays bound to the parameter variables, so assigning a depth value back into them throws.
        $depthTranslation = Get-PSFConfigValue -FullName "d365bap.tools.ppac.security.accesslevels"

        $requestedAccessLevels = [ordered]@{
            "Create"   = $Create
            "Read"     = $Read
            "Write"    = $Write
            "Delete"   = $Delete
            "Append"   = $Append
            "AppendTo" = $AppendTo
            "Assign"   = $Assign
            "Share"    = $Share
        }

        foreach ($privilegeType in @($requestedAccessLevels.Keys)) {
            if ($depthTranslation.ContainsKey($requestedAccessLevels[$privilegeType])) {
                $requestedAccessLevels[$privilegeType] = $depthTranslation[$requestedAccessLevels[$privilegeType]]
            }
        }

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

        $colRoleMatches = @(Get-PpacSecurityRole `
                -EnvironmentId $envObj.PpacEnvId `
                -Name $Role `
                -IncludeAll)

        # Dataverse creates an inherited copy of the role in every business unit. Only the root
        # record - the one without a parent role - can be modified.
        $roleObj = $colRoleMatches | `
            Where-Object { $null -eq $_._parentroleid_value } | `
            Select-Object -First 1

        if ($null -eq $roleObj) {
            $messageString = "The supplied Role: <c='em'>$Role</c> is not a valid Security Role in the Power Platform environment. Please verify that the role exists in the environment - try running the <c='em'>Get-PpacSecurityRole</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because security role was NOT found based on the name." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $colTablesRaw = Invoke-RestMethod `
            -Method Get `
            -Uri $($baseUri + '/api/data/v9.2/EntityDefinitions?$select=LogicalName,SchemaName,DisplayName,Privileges') `
            -Headers $headersWebApi 4> $null | `
            Select-Object -ExpandProperty value

        $tableObj = $colTablesRaw | `
            Where-Object {
            $_.LogicalName -eq $Table `
                -or $_.SchemaName -eq $Table `
                -or $_.DisplayName.UserLocalizedLabel.Label -eq $Table
        } | `
            Select-Object -First 1

        if ($null -eq $tableObj) {
            $messageString = "The supplied Table: <c='em'>$Table</c> is not a valid table in the Power Platform environment. Please verify that the table exists in the environment - try running the <c='em'>Get-PpacTable</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because table was NOT found based on the name." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        if ($tableObj.Privileges.Count -eq 0) {
            $messageString = "The supplied Table: <c='em'>$Table</c> doesn't have any privileges and cannot be assigned to a Security Role. Please verify that the table is available for privilege assignment - via the Power Platform admin center - <c='em'>https://aka.ms/ppac</c>"
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because table doesn't support privilege assignment." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $desiredPrivileges = @()

        foreach ($privilegeType in $requestedAccessLevels.Keys) {
            $accessLevel = $requestedAccessLevels[$privilegeType]

            if ($accessLevel -eq 'None') { continue }

            $privilegeObj = $tableObj.Privileges | `
                Where-Object PrivilegeType -eq $privilegeType | `
                Select-Object -First 1

            if ($null -eq $privilegeObj) {
                $messageString = "The privilege type: <c='em'>$privilegeType</c> isn't available for the Table: <c='em'>$Table</c> in the Power Platform environment. The privilege will be skipped."
                Write-PSFMessage -Level Important -Message $messageString
                continue
            }

            $desiredPrivileges += [PsCustomObject][ordered]@{
                PrivilegeId = $privilegeObj.PrivilegeId
                Depth       = $accessLevel
            }
        }

        $colRolePrivileges = Invoke-RestMethod `
            -Method Get `
            -Uri $($baseUri + "/api/data/v9.2/RetrieveRolePrivilegesRole(RoleId=@roleId)?@roleId=$($roleObj.PpacRoleId)") `
            -Headers $headersWebApi 4> $null | `
            Select-Object -ExpandProperty RolePrivileges

        $tablePrivilegeIds = @($tableObj.Privileges | ForEach-Object { "$($_.PrivilegeId)" })

        $currentTablePrivileges = @($colRolePrivileges | Where-Object { "$($_.PrivilegeId)" -in $tablePrivilegeIds })

        if ($currentTablePrivileges.Count -eq 0 -and $desiredPrivileges.Count -eq 0) {
            $messageString = "The Table: <c='em'>$Table</c> doesn't have any privileges assigned to the Security Role: <c='em'>$($roleObj.Name)</c> and no access levels were supplied. Nothing to change."
            Write-PSFMessage -Level Important -Message $messageString
            return
        }

        if ($currentTablePrivileges.Count -eq 0) {
            # The table has no privileges on the role yet - the desired privileges can simply be added.
            $payload = [PsCustomObject][ordered]@{
                Privileges = $desiredPrivileges
            }

            $localUri = $baseUri + "/api/data/v9.2/roles($($roleObj.PpacRoleId))/Microsoft.Dynamics.CRM.AddPrivilegesRole"
        }
        else {
            # The table already has privileges on the role - the complete privilege set of the role is replaced,
            # keeping the privileges of all other tables and applying the desired privileges for this table.
            $keptPrivileges = @($colRolePrivileges | `
                    Where-Object { "$($_.PrivilegeId)" -notin $tablePrivilegeIds } | `
                    ForEach-Object {
                    [PsCustomObject][ordered]@{
                        PrivilegeId = $_.PrivilegeId
                        Depth       = $_.Depth
                    }
                })

            $payload = [PsCustomObject][ordered]@{
                Privileges = @($keptPrivileges) + @($desiredPrivileges)
            }

            $localUri = $baseUri + "/api/data/v9.2/roles($($roleObj.PpacRoleId))/Microsoft.Dynamics.CRM.ReplacePrivilegesRole"
        }

        Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersWebApi `
            -ContentType "application/json" `
            -Body $($payload | ConvertTo-Json -Depth 10) `
            -StatusCodeVariable statusPrivileges > $null 4> $null

        if (-not ($statusPrivileges -like "2*")) {
            $messageString = "Failed to set the privileges of the Table: <c='em'>$Table</c> on the Security Role: <c='em'>$($roleObj.Name)</c> in the Power Platform environment. Please try setting the privileges manually via the Power Platform admin center - <c='em'>https://aka.ms/ppac</c>"
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because setting the privileges on the Security Role failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        Get-PpacSecurityRoleTable `
            -EnvironmentId $envObj.PpacEnvId `
            -Role "$($roleObj.PpacRoleId)" `
            -Name $tableObj.LogicalName
    }

    end {

    }
}