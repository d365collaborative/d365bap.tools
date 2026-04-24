
<#
    .SYNOPSIS
        Get Entra (AAD) registered applications from a Finance and Operations environment.

    .DESCRIPTION
        Retrieves the registered Entra (Azure AD) client applications from the SysAADClients OData entity in a Finance and Operations environment.

        Supports wildcard and exact matching against the ClientId (AadClientId), Name, and UserId fields.

    .PARAMETER EnvironmentId
        The ID of the environment to retrieve Entra applications from.

        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

    .PARAMETER ClientId
        The value to filter the results by.

        Filters across the ClientId (AadClientId), Name, and UserId fields — any match on any of the three will include the record.

        Supports wildcard characters for flexible matching.

        Default value is "*", which returns all registered applications.

    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved application information to an Excel file.

    .EXAMPLE
        PS C:\> Get-FscmEntraApplication -EnvironmentId "ContosoEnv"

        This command retrieves all Entra registered applications from the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "00000000-0000-0000-0000-000000000001"

        This command retrieves the Entra application with the exact client ID "00000000-0000-0000-0000-000000000001" from the environment "ContosoEnv".

        The filter is matched against the ClientId (AadClientId), Name, and UserId fields.

    .EXAMPLE
        PS C:\> Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "*1234*"

        This command retrieves all Entra applications where the ClientId (AadClientId), Name, or UserId contains "1234" from the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "IntegrationApp"

        This command retrieves the Entra application with the exact Name "IntegrationApp" from the environment "ContosoEnv".

        The filter is matched against the ClientId (AadClientId), Name, and UserId fields.

    .EXAMPLE
        PS C:\> Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "*Integration*"

        This command retrieves all Entra applications where the ClientId (AadClientId), Name, or UserId contains "Integration" from the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "Admin"

        This command retrieves the Entra application associated with the UserId "Admin" from the environment "ContosoEnv".

        The filter is matched against the ClientId (AadClientId), Name, and UserId fields.

    .EXAMPLE
        PS C:\> Get-FscmEntraApplication -EnvironmentId "ContosoEnv" -AsExcelOutput

        This command retrieves all Entra registered applications from the environment "ContosoEnv" and exports the results to an Excel file.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmEntraApplication {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [string] $ClientId = "*",

        [switch] $AsExcelOutput
    )

    begin {
        if (Test-PSFFunctionInterrupt) { return }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $colRaw = Get-FscmOdata -EnvironmentId $EnvironmentId -Entity "SysAADClients"

        $resCol = @(
            $colRaw | Where-Object {
                ($_.AadClientId -like $ClientId -or $_.AadClientId -eq $ClientId) `
                    -or ($_.Name -like $ClientId -or $_.Name -eq $ClientId) `
                    -or ($_.UserId -like $ClientId -or $_.UserId -eq $ClientId)
            } | Select-PSFObject -TypeName "D365Bap.Tools.FscmEntraApplication" `
                -ExcludeProperty "@odata.etag" `
                -Property "AadClientId as ClientId",
                *
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-FscmEntraApplication"
            return
        }

        $resCol
    }

    end {

    }
}
