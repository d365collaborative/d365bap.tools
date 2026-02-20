
<#
    .SYNOPSIS
        Get team details from Power Platform environment.
        
    .DESCRIPTION
        This cmdlet retrieves team details from a Power Platform environment. It allows filtering by team name or ID, and exporting the results to Excel.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve team details from.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Name
        The name or ID of the team to retrieve details for.
        
        Can be either the team name or the team ID.
        
        Supports wildcard characters for flexible matching.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved team information to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-PpacTeam -EnvironmentId "ContosoEnv" -Name "Contoso Team"
        
        This command retrieves the team with the name "Contoso Team" from the environment "ContosoEnv" and displays its information in the console.
        
    .EXAMPLE
        PS C:\> Get-PpacTeam -EnvironmentId "ContosoEnv" -Name "*contoso*"
        
        This command retrieves all teams with names matching "*contoso*" from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-PpacTeam -EnvironmentId "ContosoEnv" -AsExcelOutput
        
        This command retrieves all teams from the environment "ContosoEnv".
        It will export the information to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacTeam {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Alias('Team')]
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
            "Authorization"    = "Bearer $($tokenWebApiValue)"
            "Accept"           = "application/json;odata.metadata=minimal" # minimal || full
            "OData-MaxVersion" = "4.0"
            "OData-Version"    = "4.0"
            "Prefer"           = "odata.include-annotations=*"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $colTeamsRaw = Invoke-RestMethod `
            -Method Get `
            -Uri $($baseUri + '/api/data/v9.2/teams?$expand=teamroles_association($select=name)') `
            -Headers $headersWebApi 4> $null | `
            Select-Object -ExpandProperty value

        $colTeams = $colTeamsRaw | Where-Object {
            ($_.name -like $Name -or $_.name -eq $Name) `
                -or ($_.teamId -like $Name -or $_.teamId -eq $Name)
        } | Sort-Object -Property name -Descending

        $resCol = @($colTeams | Select-PSFObject -TypeName "D365Bap.Tools.PpacTeam" `
                -ExcludeProperty "@odata.etag", "TeamType", "TeamId", "modifiedon", "membershiptype" `
                -Property "teamId as PpacTeamId",
            "name as TeamName",
            "'teamtype@OData.Community.Display.V1.FormattedValue' As TeamType",
            "'_administratorid_value@OData.Community.Display.V1.FormattedValue' As Administrator",
            "azureactivedirectoryobjectid as EntraObjectId",
            "'membershiptype@OData.Community.Display.V1.FormattedValue' As MembershipType",
            "'_businessunitid_value@OData.Community.Display.V1.FormattedValue' As BusinessUnit",
            "modifiedon as ModifiedOn",
            @{Name = "RolesList"; Expression = { ($_.teamroles_association.name -join ", ") } },
            *
        )
        
        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacTeam"
            return
        }

        $resCol
    }

    end {
        
    }
    
}