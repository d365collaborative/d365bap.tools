
<#
    .SYNOPSIS
        Get security role members in a Finance and Operations environment.
        
    .DESCRIPTION
        Enables the user to get security role members in a Finance and Operations environment.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER Role
        Name or RoleId of the security role to filter on.
        
        Supports wildcards.
        
    .PARAMETER UserId
        UserId of the user that you want to filter on.
        
        Supports wildcards.
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-FnOEnvironmentSecurityRoleMember -EnvironmentId *uat* -Role "*Administrator*"
        
        This will list all Security Role Members for the Security Roles matching the "*Administrator*" pattern from the Finance and Operations environment.
        
    .EXAMPLE
        PS C:\> Get-FnOEnvironmentSecurityRoleMember -EnvironmentId *uat* -Role "-SYSADMIN-" -UserId "john.doe"
        
        This will list the Security Role Member with the RoleId "-SYSADMIN-" and UserId "john.doe" from the Finance and Operations environment.
        
    .EXAMPLE
        PS C:\> Get-FnOEnvironmentSecurityRoleMember -EnvironmentId *uat* -Role "-SYSADMIN-" -AsExcelOutput
        
        This will list all Security Role Members for the Security Role with the RoleId "-SYSADMIN-" from the Finance and Operations environment.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FnOEnvironmentSecurityRoleMember {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [Alias("Name")]
        [Alias("SecurityRoleId")]
        [string] $Role,

        [string] $UserId = "*",

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

        $secRoleObj = Get-FnOEnvironmentSecurityRole -EnvironmentId $EnvironmentId `
            -Name $Role | `
            Select-Object -First 1

        if ($null -eq $secRoleObj) {
            $messageString = "The supplied: <c='em'>$Role</c> didn't return any matching security details from the Environment. Please verify that the EnvironmentId & Role is correct - try running the <c='em'>Get-BapEnvironment</c> or <c='em'>Get-FnOEnvironmentSecurityRole</c> cmdlets."
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

        $localUri = $baseUri + "/data/SecurityUserRoles?`$filter=SecurityRoleIdentifier eq '$($secRoleObj.FnORoleId)'"
        $resRoles = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersFnO | Select-Object -ExpandProperty value
            
        $resCol = @(
            $resRoles | `
                Sort-Object -Property 'UserId' | `
                Select-PSFObject -TypeName "D365Bap.Tools.FnOSecurityRoleMember" `
                -ExcludeProperty "@odata.etag", `
                -Property "UserId as FnOUserId",
            "SecurityRoleIdentifier as FnORoleId",
            "AssignmentStatus as Status",
            "AssignmentMode as Assignment",
            "SecurityRoleName as Name",
            "UserLicenseType as License",
            *
        )

        $resCol = $resCol | Where-Object {
            $_.FnOUserId -like $UserId
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-FnOEnvironmentSecurityRoleMember"
            return
        }

        $resCol
    }
    
    end {
        
    }
}