
<#
    .SYNOPSIS
        Get team details from Power Platform environment.
        
    .DESCRIPTION
        Enables the user to get details about teams in a Power Platform environment.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER Name
        The name of the team you want to get details for.
        
        Support wildcards (*) to filter the team names.
        
    .PARAMETER AsExcelOutput
        Instructs the function to export the results to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-PpacTeam -EnvironmentId "env-123" -Name "*Team*"
        
        This will retrieve the team with the name "*Team*" in the environment with the id "env-123".
        
    .EXAMPLE
        PS C:\> Get-PpacTeam -EnvironmentId "env-123" -Name "*Team*" -AsExcelOutput
        
        This will retrieve the team with the name "*Team*" in the environment with the id "env-123".
        It will export the results to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacTeam {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

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

        $resTeams = Invoke-RestMethod `
            -Method Get `
            -Uri $($baseUri + '/api/data/v9.2/teams?$expand=teamroles_association($select=name)') `
            -Headers $headersWebApi 4> $null

        [System.Collections.Generic.List[System.Object]] $resCol = @()
        
        foreach ($teamObj in  $($resTeams.value | Sort-Object -Property name -Descending)) {
            if ((-not ($teamObj.TeamId -like $Name -or $teamObj.TeamId -eq $Name)) `
                    -and (-not ($teamObj.name -like $Name -or $teamObj.name -eq $Name)) `
            ) { continue }

            $tmp = $teamObj | Select-PSFObject -TypeName "D365Bap.Tools.PpacTeam" `
                -ExcludeProperty "@odata.etag", "TeamType", "TeamId", "modifiedon", "membershiptype" `
                -Property "teamId as PpacTeamId",
            "name as TeamName",
            "'teamtype@OData.Community.Display.V1.FormattedValue' As TeamType",
            "'_administratorid_value@OData.Community.Display.V1.FormattedValue' As Administrator",
            "azureactivedirectoryobjectid as EntraObjectId",
            "'membershiptype@OData.Community.Display.V1.FormattedValue' As MembershipType",
            "'_businessunitid_value@OData.Community.Display.V1.FormattedValue' As BusinessUnit",
            "modifiedon as ModifiedOn",
            *

            $resCol.Add($tmp)
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacTeam"
            return
        }

        $resCol
    }

    end {
        
    }
    
}