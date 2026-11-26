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

	$uri = "$OrganizationUrl/api/data/v9.2/asyncoperations($OperationId)?" + '$select=statecode,statuscode,message'
	$hashHeaders = @{ Prefer = 'odata.include-annotations="OData.Community.Display.V1.FormattedValue"' }

	do {
		$tmpToken = Get-BapAccessToken -ResourceUrl $OrganizationUrl
		$tmpJob = Invoke-RestMethod -Uri $uri `
			-Authentication Bearer `
			-Token $tmpToken `
			-Headers $hashHeaders `
			-ErrorAction Stop

		$tmpStatus = $tmpJob.'statuscode@OData.Community.Display.V1.FormattedValue' ?? "Status $($tmpJob.statuscode)"
		if (-not $Silent) {
			Write-PSFMessage -Level Important `
				-Message "$Activity - $tmpStatus (job $OperationId)."
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
