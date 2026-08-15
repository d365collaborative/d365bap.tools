<#
    .SYNOPSIS
        Retrieves Power Platform environment groups.

    .DESCRIPTION
        Retrieves environment groups from the Power Platform API.

    .PARAMETER EnvironmentGroup
        Filters environment groups by ID, display name, or description.

        Supports wildcard characters.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the output to an Excel file.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroup

        Retrieves all environment groups available to the current tenant.

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroup -EnvironmentGroup "*Production*"

        Retrieves environment groups whose ID, display name, or description contains "Production".

    .EXAMPLE
        PS C:\> Get-PpacEnvironmentGroup -AsExcelOutput

        Retrieves all environment groups and exports them to an Excel file.

    .NOTES
        Author: Florian Hopfner (@FH-Inway)
#>
function Get-PpacEnvironmentGroup {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Alias('GroupId', 'GroupName', 'GroupDescription')]
        [string] $EnvironmentGroup = "*",

        [switch] $AsExcelOutput
    )

    begin {
        $secureToken = (Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/" -AsSecureString -ErrorAction Stop).Token
        $tokenValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headers = @{
            Authorization = "Bearer $tokenValue"
        }

        $uri = "https://api.powerplatform.com/environmentmanagement/environmentGroups?api-version=2024-10-01"
        $environmentGroups = @()
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        while (-not [string]::IsNullOrWhiteSpace($uri)) {
            $result = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers

            $environmentGroups += $result.value
            $uri = $result.'@odata.nextLink'
        }

        $resCol = @(
            $environmentGroups | Where-Object {
                $_.id -like $EnvironmentGroup `
                -or $_.displayName -like $EnvironmentGroup `
                -or $_.description -like $EnvironmentGroup
            } | Select-PSFObject -TypeName "D365Bap.Tools.PpacEnvironmentGroup" `
                -Property "id as Id",
            "displayName as DisplayName",
            "description as Description",
            "createdBy.id as CreatedBy",
            "createdTime as CreatedTime",
            "lastModifiedBy.id as LastModifiedBy",
            "lastModifiedTime as LastModifiedTime"
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacEnvironmentGroup" `
                -WarningAction SilentlyContinue
            return
        }

        $resCol
    }
}