
<#
    .SYNOPSIS
        Get security roles in a Finance and Operations environment.
        
    .DESCRIPTION
        Enables the user to get security roles in a Finance and Operations environment.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER Name
        Name or RoleId of the security role to filter on.
        
        Wildcards are supported.
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-FnOEnvironmentSecurityRole -EnvironmentId *uat*
        
        This will list all Security Roles from the Finance and Operations environment, by the EnvironmentId (Name/Wildcard).
        
    .EXAMPLE
        PS C:\> Get-FnOEnvironmentSecurityRole -EnvironmentId *uat* -Name "*Administrator*"
        
        This will list all Security Roles, which matches the "*Administrator*" pattern, from the Finance and Operations environment.
        
    .EXAMPLE
        PS C:\> Get-FnOEnvironmentSecurityRole -EnvironmentId *uat* -Name "-SYSADMIN-"
        
        This will list the Security Role with the RoleId "-SYSADMIN-" from the Finance and Operations environment.
        
    .EXAMPLE
        PS C:\> Get-FnOEnvironmentSecurityRole -EnvironmentId *uat* -AsExcelOutput
        
        This will list all Security Roles from the Finance and Operations environment, by the EnvironmentId (Name/Wildcard).
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FnOEnvironmentSecurityRole {
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
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

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
        $resRoles = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersFnO | Select-Object -ExpandProperty value

        $resCol = @(
            $resRoles | `
                Sort-Object -Property 'SecurityRoleIdentifier' | `
                Select-PSFObject -TypeName "D365Bap.Tools.FnORole" `
                -ExcludeProperty "@odata.etag" `
                -Property "SecurityRoleIdentifier as FnORoleId",
            "SecurityRoleName as Name",
            "UserLicenseType as License",
            *
        )

        $resCol = $resCol | Where-Object {
            $_.FnORoleId -like $Name `
                -or $_.Name -like $Name }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-FnOEnvironmentSecurityRole"
            return
        }

        $resCol
    }
    
    end {
        
    }
}