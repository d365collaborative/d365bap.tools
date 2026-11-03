<#
    .SYNOPSIS
        Get members of a Security Group from Azure AD / Entra ID.

    .DESCRIPTION
        Retrieves the members from Azure AD / Entra ID. An object ID is matched exactly; a display name is matched as a prefix and the first result is used.

    .PARAMETER Group
        The ObjectId of the Security Group in Azure AD / Entra ID.

    .EXAMPLE
        PS C:\> Get-GraphGroupMember -Group "12345678-90ab-cdef-1234-567890abcdef"

        Retrieves the members of a security group by object ID.
        It uses -Group with the object ID of the security group.

    .EXAMPLE
        PS C:\> Get-GraphGroupMember -Group "FO-PPE-ENV-ADMINS"

        Retrieves the members of a security group by display name.
        It uses -Group with the display name of the security group.
        It will take the first match returned by the Graph API.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-GraphGroupMember {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[Parameter (Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Group
	)

	end {
		$objTokenGraph = Get-BapAccessToken -Graph
		$tokenGraphValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objTokenGraph

		$hashHeadersGraphApi = @{
			"Authorization" = "Bearer $($tokenGraphValue)"
			"Content-Type"  = "application/json"
		}

		if (Test-Guid -InputObject $Group) {
			$uriGraph = 'https://graph.microsoft.com/v1.0/groups?$filter=id eq ''{0}''' `
				-f $Group
		}
		else {
			$uriGraph = 'https://graph.microsoft.com/v1.0/groups?$filter=startswith(displayName, ''{0}'')' `
				-f $Group
		}

		$objGroup = Invoke-RestMethod -Method Get `
			-Uri $uriGraph `
			-Headers $hashHeadersGraphApi 4> $null |
		Select-Object -ExpandProperty Value |
		Select-Object -First 1

		if ($null -eq $objGroup) {
			$messageString = "The supplied Group: <c='em'>$Group</c> didn't return any matching Security Group in Azure AD / Entra ID. Please verify that the ObjectId is correct - try running the <c='em'>Get-AzADGroup</c> cmdlet."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because Security Group was NOT found." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) `
				-StepsUpward 1

			return
		}

		$uriGraph = 'https://graph.microsoft.com/v1.0/groups/{0}/transitiveMembers?$select=id,displayName,mail,userPrincipalName' `
			-f $objGroup.id

		$colMembers = Invoke-RestMethod -Method Get `
			-Uri $uriGraph `
			-Headers $hashHeadersGraphApi 4> $null |
		Select-Object -ExpandProperty Value

		if ($colMembers.Count -eq 0) {
			$messageString = "The Security Group: <c='em'>$($objGroup.id) | $($objGroup.displayName)</c> doesn't contain any members. Please verify that the Security Group has members."
			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because the Security Group has no members." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) `
				-StepsUpward 1
		}

		$colMembers |
		Where-Object {
			$_.'@odata.type' -eq "#microsoft.graph.user"
		}
	}
}
