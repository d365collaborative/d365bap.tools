
<#
    .SYNOPSIS
        Add a registered Entra (AAD) application to a Finance and Operations environment.

    .DESCRIPTION
        Registers an Entra (Azure AD) application in the Finance and Operations environment by creating a record in the SysAADClients OData entity.

        Before creating the record, the cmdlet validates that:
        - The MappedUser exists as a user in the Finance and Operations environment.
        - The ClientId is not already registered in the environment.

    .PARAMETER EnvironmentId
        The ID of the environment to register the Entra application in.

        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

    .PARAMETER ClientId
        The AAD Client ID (application ID GUID) of the Entra application to register.

        Must not already be registered in the environment.

    .PARAMETER Name
        The display name to assign to the registered Entra application.

        If empty, the Name will be the same as the ClientId.

    .PARAMETER MappedUser
        The Finance and Operations user to map the Entra application to.

        Can be either the user name, user ID or user principal name (UPN).

        Must exist as a user in the Finance and Operations environment.

    .EXAMPLE
        PS C:\> Add-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "00000000-0000-0000-0000-000000000001" -MappedUser "svc-integration"

        This command registers the Entra application with client ID "00000000-0000-0000-0000-000000000001", mapped to the user "svc-integration", in the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Add-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "00000000-0000-0000-0000-000000000001" -MappedUser "svc-integration@contoso.com"

        This command registers the Entra application with client ID "00000000-0000-0000-0000-000000000001", mapped to the user with UPN "svc-integration@contoso.com", in the environment "ContosoEnv".

    .EXAMPLE
        PS C:\> Add-FscmEntraApplication -EnvironmentId "ContosoEnv" -ClientId "00000000-0000-0000-0000-000000000001" -Name "Contoso Integration App" -MappedUser "svc-integration"

        This command registers the Entra application with client ID "00000000-0000-0000-0000-000000000001" and display name "Contoso Integration App", mapped to the user "svc-integration", in the environment "ContosoEnv".

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Add-FscmEntraApplication {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [string] $ClientId,

        [string] $Name,

        [Parameter (Mandatory = $true)]
        [Alias('RoleName')]
        [string] $MappedUser
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
            "Content-Type"  = "application/json;charset=utf-8"
        }

        $userObj = Get-FscmUser `
            -EnvironmentId $envObj.PpacEnvId `
            -User $MappedUser | `
            Select-Object -First 1

        if (Test-PSFFunctionInterrupt) { return }

        if ($null -eq $userObj) {
            $messageString = "The supplied MappedUser: <c='em'>$MappedUser</c> is not a user in the Finance and Operations environment. Please verify that the user exists - try running the <c='em'>Get-FscmUser</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because user was NOT found based on the supplied value." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $existingApp = Get-FscmEntraApplication `
            -EnvironmentId $envObj.PpacEnvId `
            -ClientId $ClientId | `
            Select-Object -First 1

        if (Test-PSFFunctionInterrupt) { return }

        if ($null -ne $existingApp) {
            $messageString = "The supplied ClientId: <c='em'>$ClientId</c> is already registered in the Finance and Operations environment. Please verify that the ClientId is correct - try running the <c='em'>Get-FscmEntraApplication</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Entra application already exists." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        if ([string]::IsNullOrEmpty($Name)) {
            $Name = $ClientId
        }
        
        $payload = [PsCustomObject][ordered]@{
            "AADClientId" = $ClientId
            "UserId"      = $userObj.FscmUserId
            "Name"        = $Name
        } | ConvertTo-Json

        Invoke-RestMethod -Method Post `
            -Uri ($baseUri + '/data/SysAADClients') `
            -Headers $headersFnO `
            -Body $payload `
            -ContentType $headersFnO.'Content-Type' `
            -StatusCodeVariable statusAddApp > $null 4> $null

        if (-not $statusAddApp -like "2*") {
            $messageString = "Something went wrong when registering the Entra application: <c='em'>$ClientId</c> mapped to user: <c='em'>$($userObj.FscmUserId)</c>. HTTP Status Code: <c='em'>$statusAddApp</c>. Please investigate."
            Write-PSFMessage -Level Warning -Message $messageString
        }

        Get-FscmEntraApplication `
            -EnvironmentId $envObj.PpacEnvId `
            -ClientId $ClientId
    }

    end {

    }
}
