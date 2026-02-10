<#
.SYNOPSIS
Add application user to Power Platform environment.

.DESCRIPTION
Enables the user to add an application user to the environment and assign a security role to it.

.PARAMETER EnvironmentId
The id of the environment that you want to work against.

.PARAMETER ObjectId
The ObjectId of the Service Principal in Azure AD / Entra ID that you want to add as an application user to the Power Platform environment.

.PARAMETER Role
The security role that you want to assign to the application user.

.EXAMPLE
PS C:\> Add-PpacApplicationUser -EnvironmentId "env-123" -ObjectId "00000000-0000-0000-0000-000000000000" -Role "System Administrator"

This will add an application user to the Power Platform environment.
It will use the Service Principal with the ObjectId "00000000-0000-0000-0000-000000000000" from Azure AD / Entra ID
It will then assign the "System Administrator" security role to it in the Power Platform environment.

.NOTES
Author: Mötz Jensen (@Splaxi)
#>
function Add-PpacApplicationUser {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [string] $ServicePrincipal,

        [Parameter (Mandatory = $true)]
        [Alias('RoleName')]
        [string] $Role
    )
    
    begin {
        $spnObj = $null

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

        $spnObj = Get-GraphServicePrincipal `
            -SpId $ServicePrincipal

        if (Test-PSFFunctionInterrupt) { return }

        $colSecurityRoles = Get-BapEnvironmentSecurityRole `
            -EnvironmentId $envObj.PpacEnvId `
            -Name $Role

        if ($colSecurityRoles.Count -eq 0) {
            $messageString = "The supplied Role Name / Id: <c='em'>$Role</c> didn't return any matching Security Role in the Power Platform environment. Please verify that the Role Name / Id is correct - try running the <c='em'>Get-BapEnvironmentSecurityRole</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Security Role was NOT found based on the Role Name / Id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if ($colSecurityRoles.Count -gt 1) {
            $messageString = "The supplied Role Name / Id: <c='em'>$Role</c> returned multiple matching Security Roles in the Power Platform environment. Please verify that the Role Name / Id is correct - try running the <c='em'>Get-BapEnvironmentSecurityRole</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because multiple Security Roles were found based on the Role Name / Id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $colUsers = Get-PpacApplicationUser `
            -EnvironmentId $envObj.PpacEnvId

        # Check if the Service Principal is already added as an application user in the Power Platform environment
        $crmUser = $colUsers | `
            Where-Object PpacAppId -eq $spnObj.appId | `
            Select-Object -First 1

        if ($null -eq $crmUser) {
            # We need to add the Service Principal as an application user to the Power Platform environment
            
            #First we need to get the default Business Unit
            $colBunits = Get-CrmBusinessUnit -BaseUri $baseUri
            $businessObj = $colBunits | `
                Where-Object IsRoot -eq $true | `
                Select-Object -First 1

            # Then we can add the Service Principal as an application user to the environment using the Web API
            $localUri = $baseUri + "/api/data/v9.2/systemusers"
            $payLoad = [PsCustomObject][ordered]@{
                "applicationid"             = $spnObj.appId
                "accessmode"                = 4 # Application User
                "isdisabled"                = $false
                "businessunitid@odata.bind" = "/businessunits($($businessObj.Id))"
            } | ConvertTo-Json -Depth 10

            $localHeaders = @{
                "Authorization" = "Bearer $($tokenWebApiValue)"
                "Content-Type"  = "application/json"
            }
        
            Invoke-RestMethod -Method Post `
                -Uri $localUri `
                -Headers $localHeaders `
                -ContentType $localHeaders."Content-Type" `
                -Body $payLoad `
                -StatusCodeVariable statusAppUser > $null

            if (-not ($statusAppUser -like "2*")) {
                $messageString = "Failed to add the Service Principal: <c='em'>$($spnObj.displayName) - $($spnObj.appId)</c> as an application user to the Power Platform environment. Please verify that the Service Principal exists in Azure AD / Entra ID and that the Role Name / Id is correct."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because adding the application user failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }

            # We need to assign $crmUser for the next steps
            $colUsers = Get-PpacApplicationUser `
                -EnvironmentId $envObj.PpacEnvId

            $crmUser = $colUsers | `
                Where-Object PpacAppId -eq $spnObj.appId | `
                Select-Object -First 1
        }

        # Now we need to assign the Security Role to the application user in the Power Platform environment using the Web API
        $payLoad = [PsCustomObject][ordered]@{
            "@odata.id" = $baseUri + "/api/data/v9.2/roles($($colSecurityRoles[0].PpacRoleId))"
        } | ConvertTo-Json -Depth 10

        $localUri = $baseUri + "/api/data/v9.2/systemusers($($crmUser.PpacSystemUserId))/systemuserroles_association/`$ref"
           
        Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersWebApi `
            -ContentType "application/json" `
            -Body $payLoad `
            -StatusCodeVariable statusRole > $null

        if (-not ($statusRole -like "2*")) {
            $messageString = "Failed to assign the Security Role: <c='em'>$($colSecurityRoles[0].Name)</c> to the application user in the Power Platform environment. Please try assigning the role manually via the Power Platform admin center - <c='em'>https://aka.ms/ppac</c>"
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because assigning the Security Role to the application user failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        Get-PpacApplicationUser `
            -EnvironmentId $envObj.PpacEnvId `

    }
    
    end {
        
    }
}