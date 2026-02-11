
<#
    .SYNOPSIS
        Set or remove Security Group linked to environment
        
    .DESCRIPTION
        Enables the user to set or remove a Security Group linked to the environment in Azure AD / Entra ID.
        
    .PARAMETER EnvironmentId
        Id of the environment that you want to work against.
        
    .PARAMETER SecurityGroup
        The id (objectId) or Display Name of the Security Group in Azure AD / Entra ID that you want to link to the environment.
        
        If you want to remove any existing linked Security Group, simply provide an empty string.
        
    .PARAMETER Force
        Instructs the cmdlet to proceed with removing any existing linked Security Group without additional confirmation.
        
    .EXAMPLE
        PS C:\> Set-PpacSecurityGroup -EnvironmentId *uat* -SecurityGroup 12345678-90ab-cdef-1234-567890abcdef
        
        This will link the Security Group with SecurityGroup "12345678-90ab-cdef-1234-567890abcdef" to the environment with id containing "uat".
        
    .EXAMPLE
        PS C:\> Set-PpacSecurityGroup -EnvironmentId *uat* -SecurityGroup "My Security Group"
        
        This will link the Security Group with Display Name "My Security Group" to the environment with id containing "uat".
        
    .EXAMPLE
        PS C:\> Set-PpacSecurityGroup -EnvironmentId *uat* -SecurityGroup "" -Force
        
        This will remove any existing linked Security Group from the environment with id containing "uat".
        The cmdlet will not prompt for confirmation because of the -Force switch.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-PpacSecurityGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [AllowEmptyString()]
        [Alias('EntraGroup')]
        [string] $SecurityGroup,

        [switch] $Force
    )
    
    begin {
        $SecurityGroupId = $null

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

        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }

        if (-not [System.String]::IsNullOrEmpty($SecurityGroup)) {
            $SecurityGroupId = Get-GraphGroup `
                -Group $SecurityGroup | `
                Select-Object -ExpandProperty id

            if (Test-PSFFunctionInterrupt) { return }

        }
        else {
            $SecurityGroupId = [Guid]::Empty.Guid

            if (-not $Force) {
                $messageString = "You are about to <c='em'>REMOVE</c> any existing Security Group linked to the Environment: <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)). If you want to proceed with this, please re-run the command with the <c='em'>-Force</c> switch."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because no SecurityGroup was supplied to remove existing Security Group link." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            }
        }

        if (Test-PSFFunctionInterrupt) { return }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $payLoad = [PsCustomObject][ordered]@{
            properties = [PsCustomObject][ordered]@{
                linkedEnvironmentMetadata = @{
                    securityGroupId = $SecurityGroupId
                }
            }
        } | ConvertTo-Json -Depth 10

        $localUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$($envObj.PpacEnvId)`?api-version=2021-04-01"

        Invoke-RestMethod -Method Patch `
            -Uri $localUri `
            -Headers $headersBapApi `
            -Body $payLoad `
            -ContentType "application/json" > $null
    }
    
    end {
        
    }
}