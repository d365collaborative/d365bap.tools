
<#
    .SYNOPSIS
        Get information about Finance and Operations security roles in a given environment.
        
    .DESCRIPTION
        This cmdlet retrieves information about Finance and Operations security roles in a given environment. It allows filtering by role name or ID, and exporting the results to Excel.
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve security roles from.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Name
        The name or ID of the security role to retrieve.
        
        Can be either the role name or the role ID.
        
        Supports wildcard characters for flexible matching.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the retrieved security role information to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-FscmSecurityRole -EnvironmentId "ContosoEnv" -Name "System Administrator"
        
        This command retrieves the Finance and Operations security role with the name "System Administrator" from the environment "ContosoEnv" and displays its information in the console.
        
    .EXAMPLE
        PS C:\> Get-FscmSecurityRole -EnvironmentId "ContosoEnv" -Name "*sys*admin*"
        
        This command retrieves all Finance and Operations security roles with names matching "*sys*admin*" from the environment "ContosoEnv" and displays their information in the console.
        
    .EXAMPLE
        PS C:\> Get-FscmSecurityRole -EnvironmentId "ContosoEnv" -AsExcelOutput
        
        This command retrieves all Finance and Operations security roles from the environment "ContosoEnv".
        It will export the information to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmSecurityRole {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Alias("Role")]
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

        $baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersFnO = @{
            "Authorization" = "Bearer $($tokenFnoOdataValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $localUri = $baseUri + '/data/SecurityRoles'
        $colRolesRaw = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersFnO | Select-Object -ExpandProperty value

        $colRoles = $colRolesRaw | Where-Object {
            ($_.SecurityRoleIdentifier -like $Name -or $_.SecurityRoleIdentifier -eq $Name) `
                -or ($_.SecurityRoleName -like $Name -or $_.SecurityRoleName -eq $Name)
        } | Sort-Object -Property 'SecurityRoleIdentifier'
            
        $resCol = @(
            $colRoles | Select-PSFObject -TypeName "D365Bap.Tools.FscmRole" `
                -ExcludeProperty "@odata.etag" `
                -Property "SecurityRoleIdentifier as FscmRoleId",
            "SecurityRoleName as Name",
            "UserLicenseType as License",
            *
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-FscmSecurityRole"
            return
        }

        $resCol
    }
    
    end {
        
    }
}