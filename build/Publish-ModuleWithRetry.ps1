<#
.SYNOPSIS
    Publishes a module with bounded HTTP retries.

.DESCRIPTION
    Retries the same staged package after transient HTTP upload failures. Permanent
    errors and exhausted retries terminate the release before a GitHub tag is created.

.PARAMETER Path
    Directory containing the module to publish.

.PARAMETER ApiKey
    API key for the target repository.

.PARAMETER Repository
    Registered PowerShell repository receiving the package.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[string] $Path,

	[Parameter(Mandatory)]
	[string] $ApiKey,

	[Parameter(Mandatory)]
	[string] $Repository
)

for ($attempt = 1; $attempt -le 4; $attempt++) {
	try {
		Publish-Module -Path $Path -NuGetApiKey $ApiKey -Force -Repository $Repository -ErrorAction Stop
		return
	}
	catch {
		$status = [regex]::Match($_.Exception.Message, 'Response status code does not indicate success:\s*(\d{3})\b').Groups[1].Value
		$transient = $status -in @('408', '429', '500', '502', '503', '504') -or
		($Repository -eq 'PSGallery' -and $status -eq '404')
		if (-not $transient -or $attempt -eq 4) { throw }

		$delay = 10 * [math]::Pow(2, $attempt - 1)
		Write-Warning "Upload to $Repository failed with HTTP $status (attempt $attempt/4). Retrying the same package in $delay seconds."
		Start-Sleep -Seconds $delay
	}
}
