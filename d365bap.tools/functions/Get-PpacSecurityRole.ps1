
<#
    .SYNOPSIS
        Get information about Power Platform security roles in a given environment.
        
    .DESCRIPTION
        This cmdlet retrieves information about Power Platform security roles in a given environment. It allows filtering by role name or ID, including all roles, and exporting the results to Excel.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve security roles from.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Name
        The name or ID of the security role to filter the roles by.
        
        Can be either the role name or role ID.
        
        Supports wildcard characters for flexible matching.
        
    .PARAMETER IncludeAll
        Instructs the cmdlet to include all security roles in the results, including both environment-level and business unit-level roles.
        
        By default, only environment-level roles are included.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved security role information to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-PpacSecurityRole -EnvironmentId "ContosoEnv"
        
        This command retrieves all Power Platform security roles from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-PpacSecurityRole -EnvironmentId "ContosoEnv" -Name "System Customizer"
        
        This command retrieves the Power Platform security role with the name "System Customizer" from the environment "ContosoEnv" and displays its information in the console.
        
    .EXAMPLE
        PS C:\> Get-PpacSecurityRole -EnvironmentId "ContosoEnv" -Name "*system*"
        
        This command retrieves all Power Platform security roles with names matching "*system*" from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-PpacSecurityRole -EnvironmentId "ContosoEnv" -IncludeAll
        
        This command retrieves all Power Platform security roles, including both environment-level and business unit-level roles, from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-PpacSecurityRole -EnvironmentId "ContosoEnv" -AsExcelOutput
        
        This command retrieves all Power Platform security roles from the environment "ContosoEnv".
        It will export the information to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacSecurityRole {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [string] $Name = "*",

        [switch] $IncludeAll,

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

        $colRolesRaw = Invoke-RestMethod `
            -Method Get `
            -Uri $($baseUri + '/api/data/v9.2/roles?$expand=businessunitid($select=businessunitid,_parentbusinessunitid_value)') `
            -Headers $headersWebApi 4> $null | `
            Select-Object -ExpandProperty value

        $colRoles = $colRolesRaw | Where-Object {
            ($_.name -like $Name -or $_.name -eq $Name) `
                -or ($_.roleid -like $Name -or $_.roleid -eq $Name)
        } | Sort-Object -Property name

        $resCol = @(
            $colRoles | Select-PSFObject -TypeName "D365Bap.Tools.PpacRole" `
                -ExcludeProperty "@odata.etag" `
                -Property "roleid as PpacRoleId", *,
            @{Name = "PpacRoleType"; Expression = {
                    if ($null -eq $_.businessunitid._parentbusinessunitid_value) {
                        "Environment"
                    }
                    else {
                        "BusinessUnit"
                    }
                }
            }
        )

        if (-not $IncludeAll) {
            $resCol = $resCol | Where-Object PpacRoleType -eq "Environment"
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacSecurityRole"
            return
        }

        $resCol
    }
    
    end {
        
    }
}