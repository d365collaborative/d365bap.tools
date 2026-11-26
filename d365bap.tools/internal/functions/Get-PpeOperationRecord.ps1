<#
    .SYNOPSIS
        Reads a Dataverse system job.

    .DESCRIPTION
        Retrieves a single operation and includes the status labels returned by Dataverse.

    .PARAMETER OrganizationUrl
        The Dataverse organization URL.

    .PARAMETER OperationId
        The Dataverse operation ID.

    .EXAMPLE
        PS C:\> Get-PpeOperationRecord -OrganizationUrl 'https://contoso.crm.dynamics.com' -OperationId 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'

        It uses -OrganizationUrl to select the Contoso organization.
        It uses -OperationId to look up the operation.
#>
function Get-PpeOperationRecord {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $OrganizationUrl,

		[Parameter(Mandatory = $true)]
		[guid] $OperationId
	)

	$orgUrl = $OrganizationUrl.TrimEnd('/')
	$uri = "$orgUrl/api/data/v9.2/asyncoperations($OperationId)?" + '$select=name,statecode,statuscode,createdon,startedon,completedon,message'
	$hashHeaders = @{ Prefer = 'odata.include-annotations="OData.Community.Display.V1.FormattedValue"' }
	$objToken = Get-BapAccessToken -ResourceUrl $orgUrl
	$job = Invoke-RestMethod -Uri $uri `
		-Authentication Bearer `
		-Token $objToken `
		-Headers $hashHeaders `
		-ErrorAction Stop

	[PSCustomObject][ordered]@{
		OperationId = $OperationId
		Name        = $job.name
		State       = $job.'statecode@OData.Community.Display.V1.FormattedValue' ?? "State $($job.statecode)"
		Status      = $job.'statuscode@OData.Community.Display.V1.FormattedValue' ?? "Status $($job.statuscode)"
		StateCode   = $job.statecode
		StatusCode  = $job.statuscode
		CreatedOn   = $job.createdon
		StartedOn   = $job.startedon
		CompletedOn = $job.completedon
		Message     = $job.message
	}
}
