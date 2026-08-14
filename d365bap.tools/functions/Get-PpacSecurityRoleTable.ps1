
<#
    .SYNOPSIS
        Get the tables assigned to a security role in a given environment.
        
    .DESCRIPTION
        This cmdlet retrieves the tables (entities) that have privileges assigned to a security role in a given Power Platform environment.
        
        For each table it outputs the access level for each of the privilege types: Create, Read, Write, Delete, Append, AppendTo, Assign and Share.
        
        The access levels are displayed with the Power Platform admin center naming: None, User, Business Unit, Parent: Child Business Unit, Organization.
        
        It mimics the "Tables" view of the security role editor in the Power Platform admin center, with the "Show only assigned tables" filter applied.
        
        Use the Get-PpacTable cmdlet to see all tables available in the environment.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve the security role tables from.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Role
        The security role that you want to work against.
        
        Can be either the role name or the role ID.
        
    .PARAMETER Name
        The name of the table to filter the tables by.
        
        Can be either the table display name or the logical name.
        
        Supports wildcard characters for flexible matching.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved table information to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-PpacSecurityRoleTable -EnvironmentId "ContosoEnv" -Role "Monitoring Reader"
        
        This command retrieves the tables that have privileges assigned to the security role "Monitoring Reader" in the environment "ContosoEnv".
        It will show the access level for each privilege type on each table.
        
    .EXAMPLE
        PS C:\> Get-PpacSecurityRoleTable -EnvironmentId "ContosoEnv" -Role "Monitoring Reader" -Name "*business*"
        
        This command retrieves the tables with display names or logical names matching "*business*", that have privileges assigned to the security role "Monitoring Reader" in the environment "ContosoEnv".
        
    .EXAMPLE
        PS C:\> Get-PpacSecurityRoleTable -EnvironmentId "ContosoEnv" -Role "Monitoring Reader" -AsExcelOutput
        
        This command retrieves the tables that have privileges assigned to the security role "Monitoring Reader" in the environment "ContosoEnv".
        It will export the information to an Excel file.
        
    .NOTES
        Author: Trygve Bechsgaard
#>
function Get-PpacSecurityRoleTable {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [Alias('RoleName')]
        [string] $Role,

        [string] $Name = "*",

        [switch] $AsExcelOutput
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
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $colRoleMatches = @(Get-PpacSecurityRole `
                -EnvironmentId $envObj.PpacEnvId `
                -Name $Role `
                -IncludeAll)

        # Dataverse creates an inherited copy of the role in every business unit. The root
        # record - the one without a parent role - holds the privileges.
        $roleObj = $colRoleMatches | `
            Where-Object { $null -eq $_._parentroleid_value } | `
            Select-Object -First 1

        if ($null -eq $roleObj) {
            $messageString = "The supplied Role: <c='em'>$Role</c> is not a valid Security Role in the Power Platform environment. Please verify that the role exists in the environment - try running the <c='em'>Get-PpacSecurityRole</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because security role was NOT found based on the name." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $colRolePrivileges = Invoke-RestMethod `
            -Method Get `
            -Uri $($baseUri + "/api/data/v9.2/RetrieveRolePrivilegesRole(RoleId=@roleId)?@roleId=$($roleObj.PpacRoleId)") `
            -Headers $headersWebApi 4> $null | `
            Select-Object -ExpandProperty RolePrivileges

        # Translate the Dataverse privilege depth values to the Power Platform admin center access level naming.
        $depthNames = Get-PSFConfigValue -FullName "d365bap.tools.ppac.security.depths"

        $assignedPrivileges = @{}

        foreach ($rolePrivilege in $colRolePrivileges) {
            $depthValue = "$($rolePrivilege.Depth)"

            if ($depthNames.ContainsKey($depthValue)) {
                $depthValue = $depthNames[$depthValue]
            }

            $assignedPrivileges["$($rolePrivilege.PrivilegeId)"] = $depthValue
        }

        $colTablesRaw = Invoke-RestMethod `
            -Method Get `
            -Uri $($baseUri + '/api/data/v9.2/EntityDefinitions?$select=LogicalName,SchemaName,DisplayName,OwnershipType,Privileges') `
            -Headers $headersWebApi 4> $null | `
            Select-Object -ExpandProperty value

        $ownershipNames = @{
            "UserOwned"         = "User or Team"
            "TeamOwned"         = "User or Team"
            "OrganizationOwned" = "Organization"
            "BusinessOwned"     = "Business Unit"
            "BusinessParented"  = "Business Unit"
        }

        $resCol = @(foreach ($tableObj in $colTablesRaw) {
                # Tables without privileges cannot be assigned to a security role.
                if ($tableObj.Privileges.Count -eq 0) { continue }

                $tableName = $tableObj.DisplayName.UserLocalizedLabel.Label

                if ([string]::IsNullOrEmpty($tableName)) { $tableName = $tableObj.SchemaName }

                if (-not ($tableName -like $Name -or $tableObj.LogicalName -like $Name)) { continue }

                $ownership = $ownershipNames["$($tableObj.OwnershipType)"]

                if ([string]::IsNullOrEmpty($ownership)) { $ownership = "$($tableObj.OwnershipType)" }

                $props = [ordered]@{
                    TableName       = $tableName
                    Name            = $tableObj.LogicalName
                    SchemaName      = $tableObj.SchemaName
                    RecordOwnership = $ownership
                }

                $isAssigned = $false

                foreach ($privilegeType in @("Create", "Read", "Write", "Delete", "Append", "AppendTo", "Assign", "Share")) {
                    $privilegeObj = $tableObj.Privileges | `
                        Where-Object PrivilegeType -eq $privilegeType | `
                        Select-Object -First 1

                    # An empty access level indicates that the privilege type isn't applicable for the table.
                    $accessLevel = ""

                    if ($null -ne $privilegeObj) {
                        $accessLevel = $assignedPrivileges["$($privilegeObj.PrivilegeId)"]

                        if ([string]::IsNullOrEmpty($accessLevel)) {
                            $accessLevel = "None"
                        }
                        else {
                            $isAssigned = $true
                        }
                    }

                    $props.$privilegeType = $accessLevel
                }

                if (-not $isAssigned) { continue }

                [PsCustomObject]$props
            })

        $resCol = @(
            $resCol | Sort-Object -Property TableName | `
                Select-PSFObject -TypeName "D365Bap.Tools.PpacRoleTable" -Property *
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacSecurityRoleTable"
            return
        }

        $resCol
    }

    end {

    }
}