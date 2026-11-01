
<#
    .SYNOPSIS
        Gets a security group from Azure AD / Entra ID.

    .DESCRIPTION
        Looks up one Entra ID security entry by ObjectId or display name. The Graph filter
        matches the start of the display name when the value is not an ObjectId.

    .PARAMETER Group
        ObjectId or display name of the Entra ID security group.

    .EXAMPLE
        PS C:\> Get-GraphGroup -Group "env-123"

        Retrieves the entry matching that object id or display name.
        It uses -Group to select the entry.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-GraphGroup {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[Alias('EntraGroup')]
		[string] $Group
	)

	end {
		$secureTokenGraph = Get-BapAccessToken -Graph
		$tokenGraphValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenGraph

		$headersGraphApi = @{
			"Authorization" = "Bearer $($tokenGraphValue)"
			"Content-Type"  = "application/json"
		}

		if (Test-Guid -InputObject $Group) {
			# Validate that the Security Group exists in Azure AD / Entra ID
			$uriGraph = "https://graph.microsoft.com/v1.0/groups?`$filter=id eq '$Group'"
		}
		else {
			$uriGraph = "https://graph.microsoft.com/v1.0/groups?`$filter=startswith(displayName, '$Group')"
		}

		$colGroups = Invoke-RestMethod -Method Get `
			-Uri $uriGraph `
			-Headers $headersGraphApi 4> $null | `
			Select-Object -ExpandProperty Value

		if ($colGroups.Count -eq 0) {
			$messageString = "The supplied ObjectId / Entra Group: <c='em'>$Group</c> didn't return any matching Security Group in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADGroup</c> cmdlet."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because Security Group was NOT found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
		}

		if ($colGroups.Count -gt 1) {
			$messageString = "The supplied ObjectId / Entra Group: <c='em'>$Group</c> returned multiple matching Security Groups in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADGroup</c> cmdlet."
			Write-PSFMessage -Level Important -Message $messageString
			Stop-PSFFunction -Message "Stopping because multiple Security Groups were found based on the ObjectId." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
		}

		$colGroups[0]
	}
}
