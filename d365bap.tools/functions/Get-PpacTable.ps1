
<#
    .SYNOPSIS
        Get the tables (entities) from a given environment.
        
    .DESCRIPTION
        This cmdlet retrieves all tables (entities) from a given Power Platform environment.
        
        It mimics the "Tables" view in the Power Apps maker portal, showing the table display name, logical name, type, managed state and customizability.
        
        It is not specific to any security role - use the Get-PpacSecurityRoleTable cmdlet to see the tables assigned to a security role.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve the tables from.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Name
        The name of the table to filter the tables by.
        
        Can be either the table display name or the logical name.
        
        Supports wildcard characters for flexible matching.
        
    .PARAMETER OnlyCustom
        Instructs the cmdlet to only include custom tables in the results.
        
        This matches the "Custom" filter in the Power Apps maker portal.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved table information to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-PpacTable -EnvironmentId "ContosoEnv"
        
        This command retrieves all tables from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-PpacTable -EnvironmentId "ContosoEnv" -Name "*account*"
        
        This command retrieves all tables with display names or logical names matching "*account*" from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-PpacTable -EnvironmentId "ContosoEnv" -OnlyCustom
        
        This command retrieves only the custom tables from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-PpacTable -EnvironmentId "ContosoEnv" -AsExcelOutput
        
        This command retrieves all tables from the environment "ContosoEnv".
        It will export the information to an Excel file.
        
    .NOTES
        Author: Trygve Bechsgaard
#>
function Get-PpacTable {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Alias("Table")]
        [string] $Name = "*",

        [switch] $OnlyCustom,

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

        $colTablesRaw = Invoke-RestMethod `
            -Method Get `
            -Uri $($baseUri + '/api/data/v9.2/EntityDefinitions?$select=LogicalName,SchemaName,DisplayName,OwnershipType,TableType,IsManaged,IsCustomEntity,IsCustomizable') `
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
                if ($OnlyCustom -and -not $tableObj.IsCustomEntity) { continue }

                $tableName = $tableObj.DisplayName.UserLocalizedLabel.Label

                if ([string]::IsNullOrEmpty($tableName)) { $tableName = $tableObj.SchemaName }

                if (-not ($tableName -like $Name -or $tableObj.LogicalName -like $Name)) { continue }

                $ownership = $ownershipNames["$($tableObj.OwnershipType)"]

                if ([string]::IsNullOrEmpty($ownership)) { $ownership = "$($tableObj.OwnershipType)" }

                [PsCustomObject][ordered]@{
                    TableName       = $tableName
                    Name            = $tableObj.LogicalName
                    SchemaName      = $tableObj.SchemaName
                    Type            = $tableObj.TableType
                    Managed         = $tableObj.IsManaged
                    CustomEntity    = $tableObj.IsCustomEntity
                    Customizable    = $tableObj.IsCustomizable.Value
                    RecordOwnership = $ownership
                }
            })

        $resCol = @(
            $resCol | Sort-Object -Property TableName | `
                Select-PSFObject -TypeName "D365Bap.Tools.PpacTable" -Property *
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacTable"
            return
        }

        $resCol
    }

    end {

    }
}