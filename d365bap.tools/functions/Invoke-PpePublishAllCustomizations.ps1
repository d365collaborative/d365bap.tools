<#
    .SYNOPSIS
        Publishes all customizations in a Dataverse environment.

    .DESCRIPTION
        Waits for publishing to finish. With progress enabled, it reports the publish job ID and status.

    .PARAMETER EnvironmentId
        The environment name or ID accepted by Get-BapEnvironment.

    .PARAMETER ShowProgress
        Shows the job ID and polls its status every 15 seconds for up to 60 minutes.

    .EXAMPLE
        PS C:\> Invoke-PpePublishAllCustomizations -EnvironmentId 'Contoso Demo' -ShowProgress

        It uses -EnvironmentId to select Contoso Demo.
        It uses -ShowProgress to display the job status while publishing.
#>
function Invoke-PpePublishAllCustomizations {
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
	[CmdletBinding(SupportsShouldProcess)]
	[OutputType([void])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[switch] $ShowProgress
	)

	$envObj = Get-Environment -EnvironmentId $EnvironmentId |
	Select-Object -First 1
	if (-not $envObj.PpacEnvUri) { throw "Expected a Dataverse environment for '$EnvironmentId'." }

	$shouldAffected = $envObj.PpacEnvName
	$shouldLabel = 'Publish all customizations'

	if (-not $PSCmdlet.ShouldProcess($shouldAffected, $shouldLabel)) { return }

	$orgUrl = $envObj.PpacEnvUri.TrimEnd('/')
	if ($ShowProgress) {
		$deadline = [datetime]::UtcNow.AddMinutes(60)
		$operationId = Start-PpePublishOperation -OrganizationUrl $orgUrl
		Wait-PpeAsyncOperation -OperationId $operationId `
			-OrganizationUrl $orgUrl `
			-Activity "Publishing all customizations in $($envObj.PpacEnvName)" `
			-Deadline $deadline `
			-PollIntervalSeconds 15 `
			-ShowProgress

		return
	}

	$objToken = Get-BapAccessToken -ResourceUrl $orgUrl
	Invoke-RestMethod -Method Post `
		-Uri "$orgUrl/api/data/v9.0/PublishAllXml" `
		-Authentication Bearer `
		-Token $objToken `
		-ContentType 'application/json' `
		-ErrorAction Stop > $null
}
