<#
    .SYNOPSIS
        Waits for a Dataverse operation to succeed.

    .DESCRIPTION
        Checks the operation until it succeeds, fails, is canceled, or runs out of time.

    .PARAMETER OrganizationUrl
        The Dataverse organization URL.

    .PARAMETER OperationId
        The Dataverse operation ID.

    .PARAMETER Activity
        The action to display in status messages.

    .PARAMETER Deadline
        The UTC time at which the wait expires.

    .PARAMETER PollIntervalSeconds
        Seconds between status checks.

    .PARAMETER Silent
        Suppresses status messages.

    .EXAMPLE
        PS C:\> Wait-PpeAsyncOperation -OrganizationUrl 'https://contoso.crm.dynamics.com' -OperationId 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' -Activity 'Import Contoso Demo' -Deadline ([datetime]::UtcNow.AddMinutes(10)) -PollIntervalSeconds 15 -Silent

        It uses -OrganizationUrl to select the Contoso organization.
        It uses -OperationId to select the operation.
        It uses -Activity to describe the action.
        It uses -Deadline to wait up to ten minutes.
        It uses -PollIntervalSeconds to check every 15 seconds.
        It uses -Silent to suppress status messages.
#>
function Wait-PpeAsyncOperation {
	[CmdletBinding()]
	[OutputType([void])]
	param (
		[string] $OrganizationUrl,

		[guid] $OperationId,

		[string] $Activity,

		[datetime] $Deadline,

		[int] $PollIntervalSeconds,

		[switch] $Silent
	)

	if ($OperationId -eq [guid]::Empty) {
		throw "$Activity did not return a Dataverse job ID."
	}

	do {
		$tmpJob = Get-PpeOperationRecord -OrganizationUrl $OrganizationUrl `
			-OperationId $OperationId

		if (-not $Silent) {
			Write-PSFMessage -Level Important `
				-Message "$Activity - $($tmpJob.Status) (job $OperationId)."
		}

		if ($tmpJob.statecode -eq 3) {
			if ($tmpJob.statuscode -ne 30) {
				throw "$Activity failed or was cancelled (job '$OperationId', status $($tmpJob.statuscode)). $($tmpJob.message)"
			}
			return
		}

		$tmpRemainingSeconds = ($Deadline - [datetime]::UtcNow).TotalSeconds
		if ($tmpRemainingSeconds -le 0) {
			throw "Timed out waiting for $Activity (job '$OperationId', status $($tmpJob.statuscode))."
		}
		Start-Sleep -Seconds ([Math]::Min($PollIntervalSeconds, $tmpRemainingSeconds))
	} while ($true)
}
