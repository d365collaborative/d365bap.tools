
<#
    .SYNOPSIS
        Gets a service principal from Azure AD / Entra ID.

    .DESCRIPTION
        Looks up one Entra ID service principal by ObjectId, appId or display name. The
        Graph filter matches the exact ObjectId and appId, otherwise the start of the
        display name.

    .PARAMETER SpId
        ObjectId, appId or display name of the service principal.

    .EXAMPLE
        PS C:\> Get-GraphServicePrincipal -SpId "00000000-0000-0000-0000-000000000000"

        Retrieves the entry matching that object id or appId.
        It uses -SpId to select the entry.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-GraphServicePrincipal {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[Alias('ServicePrincipal')]
		[string] $SpId
	)

	end {
		$secureTokenGraph = Get-BapAccessToken -Graph
		$tokenGraphValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenGraph

		$headersGraphApi = @{
			"Authorization" = "Bearer $($tokenGraphValue)"
		}

		if (Test-Guid -InputObject $SpId) {
			# Validate that the Service Principal exists in Azure AD / Entra ID
			$uriGraph = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=id eq '$SpId' or appId eq '$SpId'"
		}
		else {
			$uriGraph = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=startswith(displayName, '$SpId')"
		}

		$colSpns = Invoke-RestMethod -Method Get `
			-Uri $uriGraph `
			-Headers $headersGraphApi 4> $null | `
			Select-Object -ExpandProperty Value

		if ($colSpns.Count -eq 0) {
			$messageString = "The supplied ObjectId / Service Principal: <c='em'>$SpId</c> didn't return any matching Service Principal in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADServicePrincipal</c> cmdlet."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because Service Principal was NOT found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
		}

		if ($colSpns.Count -gt 1) {
			$messageString = "The supplied ObjectId / Service Principal: <c='em'>$SpId</c> returned multiple matching Service Principals in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADServicePrincipal</c> cmdlet."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because multiple Service Principals were found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
		}

		$colSpns[0]
	}
}
