
<#
    .SYNOPSIS
        Gets a user from Azure AD / Entra ID.

    .DESCRIPTION
        Looks up one Entra ID account by ObjectId, display name, principal name or mail.
        The Graph startswith filter matches the start of the display name, principal name
        or mail when the value is not an ObjectId.

    .PARAMETER User
        ObjectId, display name, principal name or mail of the Entra ID account.

    .EXAMPLE
        PS C:\> Get-GraphUser -User "john@contoso.com"

        Retrieves the account matching that object id, name, principal name or mail.
        It uses -User to select the account.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-GraphUser {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[Alias('EntraUser')]
		[string] $User
	)

	end {
		$secureTokenGraph = Get-BapAccessToken -Graph
		$tokenGraphValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenGraph

		$headersGraphApi = @{
			"Authorization" = "Bearer $($tokenGraphValue)"
			"Content-Type"  = "application/json"
		}

		if (Test-Guid -InputObject $User) {
			# Validate that the user exists in Azure AD / Entra ID
			$uriGraph = "https://graph.microsoft.com/v1.0/users?`$filter=id eq '$User'"
		}
		else {
			$uriGraph = "https://graph.microsoft.com/v1.0/users?`$filter=startswith(displayName, '$User') or startswith(userPrincipalName, '$User') or startswith(mail, '$User')"
		}

		$colUsers = @(Invoke-RestMethod -Method Get `
				-Uri $uriGraph `
				-Headers $headersGraphApi 4> $null | `
				Select-Object -ExpandProperty Value)

		if ($colUsers.Count -eq 0) {
			$messageString = "The supplied ObjectId / Entra User: <c='em'>$User</c> didn't return any matching User in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADUser</c> cmdlet."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because User was NOT found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
		}

		if ($colUsers.Count -gt 1) {
			$messageString = "The supplied ObjectId / Entra User: <c='em'>$User</c> returned multiple matching Users in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADUser</c> cmdlet."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because multiple Users were found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
		}

		$colUsers[0]
	}
}
