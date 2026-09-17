<#
    .SYNOPSIS
        Add a user to a Power Platform environment.

    .DESCRIPTION
        Creates the Dataverse systemuser for a Microsoft Entra ID user when it does not exist yet, enables the user when Dataverse created it disabled, and optionally assigns one or more security roles.

        Add-PpacSecurityRoleMember requires the systemuser to already exist and be enabled, and Entra users without a mail value need the UPN as e-mail fallback.

        Only depends on exported cmdlets (Get-BapEnvironment, Get-PpacUser, Add-PpacSecurityRoleMember) and the internal Get-GraphUser helper. Business Unit lookup is done inline via REST so this file can also be tested standalone.

    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.

        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

    .PARAMETER User
        The user that you want to add to the Power Platform environment.

        Can be either the User Principal Name (UPN), mail address, display name or Entra object id.

    .PARAMETER Role
        One or more security roles to assign to the user after creation.

        The name of the security role, as accepted by Add-PpacSecurityRoleMember. When omitted no role is assigned.

    .EXAMPLE
        PS C:\> Add-PpacUser -EnvironmentId "ContosoEnv" -User "megan.bowen@contoso.com" -Role "System Administrator"

        Creates (or enables) the systemuser for megan.bowen@contoso.com and assigns the System Administrator role.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Add-PpacUser {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [string] $User,

        [Alias('RoleName')]
        [string[]] $Role
    )

    begin {
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
            "Content-Type"  = "application/json"
        }

        $entraUser = Get-GraphUser `
            -User $User

        if ($null -eq $entraUser) {
            $messageString = "The supplied User: <c='em'>$User</c> didn't return any matching user details in Azure AD / Entra ID. Please verify that the User is correct - try running the <c='em'>Get-AzADUser</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because user was NOT found based on the UPN." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        # Entra mail is not guaranteed (e.g. some users have mail = null), fall back to UPN.
        $emailAddress = $entraUser.mail
        if ([System.String]::IsNullOrEmpty($emailAddress)) {
            $emailAddress = $entraUser.userPrincipalName
        }

        $crmUser = Get-PpacUser `
            -EnvironmentId $envObj.PpacEnvId `
            -User $emailAddress | `
            Select-Object -First 1

        if ($null -eq $crmUser -and -not [System.String]::IsNullOrEmpty($entraUser.userPrincipalName)) {
            $crmUser = Get-PpacUser `
                -EnvironmentId $envObj.PpacEnvId `
                -User $entraUser.userPrincipalName | `
                Select-Object -First 1
        }

        if ($null -eq $crmUser) {
            $colBuRaw = Invoke-RestMethod -Method Get `
                -Uri ($baseUri + '/api/data/v9.2/businessunits') `
                -Headers $headersWebApi 4> $null | `
                Select-Object -ExpandProperty value

            $businessId = ($colBuRaw | Where-Object { $null -eq $_._parentbusinessunitid_value } | Select-Object -First 1).businessunitid
            if ([System.String]::IsNullOrEmpty($businessId)) {
                $businessId = ($colBuRaw | Select-Object -First 1).businessunitid
            }

            if ([System.String]::IsNullOrEmpty($businessId)) {
                $messageString = "No Business Unit was found in the Power Platform environment. Please verify the environment - <c='em'>https://aka.ms/ppac</c>"
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because no Business Unit was found." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }

            # Split display name into first / last name for the systemuser record.
            $firstName = $entraUser.displayName
            $lastName = ""
            $nameParts = ($entraUser.displayName -split '\s+', 2)
            if ($nameParts.Count -eq 2) {
                $firstName = $nameParts[0]
                $lastName = $nameParts[1]
            }

            $payloadUser = [PsCustomObject][ordered]@{
                "firstname"                    = $firstName
                "lastname"                     = $lastName
                "domainname"                   = $entraUser.userPrincipalName
                "internalemailaddress"         = $emailAddress
                "azureactivedirectoryobjectid" = $entraUser.id
                "businessunitid@odata.bind"    = "/businessunits($businessId)"
            } | ConvertTo-Json -Depth 10

            Invoke-RestMethod -Method Post `
                -Uri ($baseUri + "/api/data/v9.2/systemusers") `
                -Headers $headersWebApi `
                -Body $payloadUser `
                -StatusCodeVariable statusUser > $null 4> $null

            if (-not ($statusUser -like "2*")) {
                $messageString = "Failed to create the user: <c='em'>$emailAddress</c> in the Power Platform environment. HTTP status: <c='em'>$statusUser</c>. Please try creating the user manually via the Power Platform admin center - <c='em'>https://aka.ms/ppac</c>"
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because creating the user failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }

            $crmUser = Get-PpacUser `
                -EnvironmentId $envObj.PpacEnvId `
                -User $emailAddress | `
                Select-Object -First 1
        }

        if ($null -eq $crmUser) {
            $messageString = "The user: <c='em'>$emailAddress</c> was expected to exist in the Power Platform environment after creation, but was not found. Please investigate via the Power Platform admin center - <c='em'>https://aka.ms/ppac</c>"
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because user was NOT found after creation." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        # Dataverse creates users disabled. Role assignment fails on disabled users (0x80048d35), so enable first.
        $userDetails = Invoke-RestMethod -Method Get `
            -Uri ($baseUri + "/api/data/v9.2/systemusers($($crmUser.PpacSystemUserId))?`$select=isdisabled") `
            -Headers $headersWebApi 4> $null

        if ($userDetails.isdisabled -eq $true) {
            $payloadEnable = [PsCustomObject][ordered]@{
                "isdisabled" = $false
            } | ConvertTo-Json -Depth 10

            Invoke-RestMethod -Method Patch `
                -Uri ($baseUri + "/api/data/v9.2/systemusers($($crmUser.PpacSystemUserId))") `
                -Headers $headersWebApi `
                -Body $payloadEnable `
                -StatusCodeVariable statusEnable > $null 4> $null

            if (-not ($statusEnable -like "2*")) {
                $messageString = "The user: <c='em'>$emailAddress</c> is disabled and enabling it failed. HTTP status: <c='em'>$statusEnable</c>. Security roles cannot be assigned to disabled users."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because enabling the user failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
        }

        foreach ($roleName in $Role) {
            Add-PpacSecurityRoleMember `
                -EnvironmentId $envObj.PpacEnvId `
                -User $emailAddress `
                -Role $roleName

            if (Test-PSFFunctionInterrupt) { return }
        }

        Get-PpacUser `
            -EnvironmentId $envObj.PpacEnvId `
            -User $emailAddress
    }

    end {

    }
}
