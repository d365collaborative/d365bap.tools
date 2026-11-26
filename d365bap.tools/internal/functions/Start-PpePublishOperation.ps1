<#
    .SYNOPSIS
        Starts a Dataverse publish job.

    .DESCRIPTION
        Submits a request to publish all customizations and returns the job ID.

    .PARAMETER OrganizationUrl
        The Dataverse organization URL.

    .EXAMPLE
        PS C:\> Start-PpePublishOperation -OrganizationUrl 'https://contoso.crm.dynamics.com'

        It uses -OrganizationUrl to submit the publish request to Contoso.
#>
function Start-PpePublishOperation {
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification = "The public import and publish commands perform ShouldProcess before calling this helper.")]
	[CmdletBinding()]
	[OutputType([guid])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $OrganizationUrl
	)

	$orgUrl = $OrganizationUrl.TrimEnd('/')
	$objToken = Get-BapAccessToken -ResourceUrl $orgUrl
	$response = Invoke-RestMethod -Method Post `
		-Uri "$orgUrl/api/data/v9.2/PublishAllXmlAsync" `
		-Authentication Bearer `
		-Token $objToken `
		-ContentType 'application/json' `
		-Body '{}' `
		-ErrorAction Stop

	$operationId = [guid]::Empty
	if ((-not [guid]::TryParse($response.AsyncOperationId, [ref] $operationId)) `
			-or ($operationId -eq [guid]::Empty)) {
		throw 'Dataverse did not return a valid publish job ID.'
	}

	$operationId
}
