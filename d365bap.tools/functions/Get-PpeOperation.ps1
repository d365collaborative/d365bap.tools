<#
    .SYNOPSIS
        Retrieves a Dataverse operation by ID.

    .DESCRIPTION
        Returns the current state, status, timestamps, and any message from the operation.

    .PARAMETER EnvironmentId
        The environment name or ID accepted by Get-BapEnvironment.

    .PARAMETER OperationId
        The Dataverse operation ID, such as the ID returned by Import-PpeSolution.

    .EXAMPLE
        PS C:\> Get-PpeOperation -EnvironmentId 'Contoso Demo' -OperationId 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'

        It uses -EnvironmentId to select Contoso Demo.
        It uses -OperationId to look up the operation.
#>
function Get-PpeOperation {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[Parameter(Mandatory = $true)]
		[guid] $OperationId
	)

	if ($OperationId -eq [guid]::Empty) { throw 'Specify a nonempty Dataverse operation ID.' }

	$envObj = Get-Environment -EnvironmentId $EnvironmentId `
		-ErrorAction Stop

	if ((@($envObj).Count -ne 1) `
			-or (-not $envObj.PpacEnvUri)) {
		throw "Expected exactly one Dataverse environment for '$EnvironmentId'."
	}

	Get-PpeOperationRecord -OrganizationUrl $envObj.PpacEnvUri `
		-OperationId $OperationId
}
