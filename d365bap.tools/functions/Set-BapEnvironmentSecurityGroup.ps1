
<#
    .SYNOPSIS
        Set or remove Security Group linked to environment
        
    .DESCRIPTION
        Enables the user to set or remove a Security Group linked to the environment in Azure AD / Entra ID.
        
    .PARAMETER EnvironmentId
        Id of the environment that you want to work against.
        
    .PARAMETER ObjectId
        The ObjectId or Display Name of the Security Group in Azure AD / Entra ID that you want to link to the environment.
        
        If you want to remove any existing linked Security Group, simply provide an empty string.
        
    .PARAMETER Force
        Instructs the cmdlet to proceed with removing any existing linked Security Group without additional confirmation.
        
    .EXAMPLE
        PS C:\> Set-BapEnvironmentSecurityGroup -EnvironmentId *uat* -ObjectId 12345678-90ab-cdef-1234-567890abcdef
        
        This will link the Security Group with ObjectId "12345678-90ab-cdef-1234-567890abcdef" to the environment with id containing "uat".
        
    .EXAMPLE
        PS C:\> Set-BapEnvironmentSecurityGroup -EnvironmentId *uat* -ObjectId "My Security Group"
        
        This will link the Security Group with Display Name "My Security Group" to the environment with id containing "uat".
        
    .EXAMPLE
        PS C:\> Set-BapEnvironmentSecurityGroup -EnvironmentId *uat* -ObjectId "" -Force
        
        This will remove any existing linked Security Group from the environment with id containing "uat".
        The cmdlet will not prompt for confirmation because of the -Force switch.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-BapEnvironmentSecurityGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [AllowEmptyString()]
        [Alias('EntraGroup')]
        [string] $ObjectId,

        [switch] $Force
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

        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }

        $secureTokenGraph = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/" -AsSecureString).Token
        $tokenGraphValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenGraph

        $headersGraphApi = @{
            "Authorization" = "Bearer $($tokenGraphValue)"
            "Content-Type"  = "application/json"
        }

        if (-not [System.String]::IsNullOrEmpty($ObjectId)) {
            if (Test-Guid -InputObject $ObjectId) {
                # Validate that the Security Group exists in Azure AD / Entra ID
                $uriGraph = "https://graph.microsoft.com/v1.0/groups?`$filter=id eq '$ObjectId'"
            }
            else {
                $uriGraph = "https://graph.microsoft.com/v1.0/groups?`$filter=startswith(displayName, '$ObjectId')"
            }

            $colGroups = Invoke-RestMethod -Method Get `
                -Uri $uriGraph `
                -Headers $headersGraphApi | Select-Object -ExpandProperty Value

            if ($colGroups.Count -eq 0) {
                $messageString = "The supplied ObjectId / Entra Group: <c='em'>$ObjectId</c> didn't return any matching Security Group in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADGroup</c> cmdlet."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because Security Group was NOT found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            }

            if ($colGroups.Count -gt 1) {
                $messageString = "The supplied ObjectId / Entra Group: <c='em'>$ObjectId</c> returned multiple matching Security Groups in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADGroup</c> cmdlet."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because multiple Security Groups were found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            }
        }
        else {
            $colGroups = @([PsCustomObject][ordered]@{id = $([Guid]::Empty.Guid) })

            if (-not $Force) {
                $messageString = "You are about to <c='em'>REMOVE</c> any existing Security Group linked to the Environment: <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)). If you want to proceed with this, please re-run the command with the <c='em'>-Force</c> switch."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because no ObjectId was supplied to remove existing Security Group link." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            }
        }

        if (Test-PSFFunctionInterrupt) { return }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $payLoad = [PsCustomObject][ordered]@{
            properties = [PsCustomObject][ordered]@{
                linkedEnvironmentMetadata = @{
                    securityGroupId = $colGroups[0].id
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