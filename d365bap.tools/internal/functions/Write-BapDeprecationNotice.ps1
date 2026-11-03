<#
    .SYNOPSIS
        Writes a deprecation notice from the central map.

    .DESCRIPTION
        Reads the deprecation map and writes the matching notice once per session.

    .PARAMETER Key
        Map key of the deprecation to announce.

    .EXAMPLE
        PS C:\> Write-BapDeprecationNotice -Key 'Get-UnifiedEnvironment.SkipVersionDetails'

        It will announce the matching deprecation once per session.
        It uses -Key to select the entry.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Write-BapDeprecationNotice {
	[CmdletBinding()]
	[OutputType([void])]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Key
	)

	$pathMisc = Get-PSFConfigValue -FullName "d365bap.tools.internal.misc.path"

	$deprecations = Get-Content `
		-Path "$pathMisc\Deprecations.json" `
		-Raw `
		-ErrorAction SilentlyContinue |
	ConvertFrom-Json -ErrorAction SilentlyContinue

	if ($null -eq $deprecations) { return }

	$entry = $deprecations.PSObject.Properties[$Key].Value

	if ($null -eq $entry) { return }

	$functionName = (Get-PSCallStack)[1].Command

	if ([string]::IsNullOrWhiteSpace($functionName)) {
		$functionName = 'Write-BapDeprecationNotice'
	}

	Write-PSFMessage -Level Warning `
		-Tag 'Deprecated' `
		-FunctionName $functionName `
		-Once "deprecation.$Key" `
		-Message "$($entry.message) It will be removed on $($entry.removedOn). See $($entry.issue)."
}
