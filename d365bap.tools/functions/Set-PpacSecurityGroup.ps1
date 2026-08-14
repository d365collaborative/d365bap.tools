
<#
    .SYNOPSIS
        Set or remove Security Group for a Power Platform environment
        
    .DESCRIPTION
        This cmdlet allows you to set or remove a Security Group for a Power Platform environment. It can be used to configure a Security Group to an environment or remove an existing one.
        
    .PARAMETER EnvironmentId
        The ID of the environment to set or remove the Security Group for.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER SecurityGroup
        The ID (objectId) or Display Name of the Security Group in Azure AD / Entra ID to link to the environment.
        
        If you want to remove any existing linked Security Group, provide an empty string.
        
    .PARAMETER Force
        Instructs the cmdlet to proceed with removing any existing linked Security Group without additional confirmation.
        
    .EXAMPLE
        PS C:\> Set-PpacSecurityGroup -EnvironmentId "ContosoEnv" -SecurityGroup "ContosoAdmins"
        
        This command sets the Security Group for the Power Platform environment "ContosoEnv" to "ContosoAdmins".
        
    .EXAMPLE
        PS C:\> Set-PpacSecurityGroup -EnvironmentId "ContosoEnv" -SecurityGroup "" -Force
        
        This command removes any existing Security Group linked to the Power Platform environment "ContosoEnv" without additional confirmation.
        
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

        $payload = [PsCustomObject][ordered]@{
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
            -Body $payload `
            -ContentType "application/json" > $null
    }
    
    end {
        
    }
}