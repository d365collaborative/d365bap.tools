<#
    .SYNOPSIS
        Tab completion for FinOps assets and kinds.

    .DESCRIPTION
        Static value lists with tooltips. Tables stay in the blocks since completers run in caller scope.
#>
[CmdletBinding()]
param()

$scbFinOpsAsset = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	try {
		$kinds = [ordered]@{
			"CompilerPackage"  = "NuGet: X++ compiler tools"
			"Platform"         = "NuGet: platform build reference"
			"ApplicationSuite" = "NuGet: ApplicationSuite build reference"
			"Application1"     = "NuGet: Application 1 build reference"
			"Application2"     = "NuGet: Application 2 build reference"
			"SystemMetadata"   = "Developer file: PackagesLocalDirectory.zip, the UDE metadata"
			"FinOpsVsix22"     = "Developer file: Visual Studio 2022 extension (UDE)"
			"TraceParser"      = "Developer file: TraceParser.msi (UDE)"
			"CrossReference"   = "Developer file: cross-reference database backup (UDE)"
			"Vhd"              = "VHD image parts, multi-file download (tens of GB)"
		}

		$filterWord = "$wordToComplete" -replace '^[''"]', ''

		foreach ($entry in $kinds.GetEnumerator()) {
			if ($entry.Key -like "$filterWord*") {
				New-PSFTeppCompletionResult -CompletionText $entry.Key -ToolTip $entry.Value
			}
		}
	}
	catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.finops.assets" -ScriptBlock $scbFinOpsAsset -Mode Full

$scbFinOpsKind = {
	param (
		$commandName,
		$parameterName,
		$wordToComplete,
		$commandAst,
		$fakeBoundParameter
	)

	try {
		$kinds = [ordered]@{
			"NuGet"         = "The 5 NuGet packages: compiler, platform and application references"
			"DeveloperFile" = "The 4 UDE developer files: metadata, VSIX, TraceParser, cross-reference"
			"Vhd"           = "The VHD image parts (only with -Asset Vhd)"
		}

		$filterWord = "$wordToComplete" -replace '^[''"]', ''

		foreach ($entry in $kinds.GetEnumerator()) {
			if ($entry.Key -like "$filterWord*") {
				New-PSFTeppCompletionResult -CompletionText $entry.Key -ToolTip $entry.Value
			}
		}
	}
	catch { }
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.finops.kinds" -ScriptBlock $scbFinOpsKind -Mode Full

Register-PSFTeppArgumentCompleter -Command Get-PpacFinOpsAsset -Parameter Asset -Name "d365bap.tools.tepp.finops.assets"
Register-PSFTeppArgumentCompleter -Command Get-PpacFinOpsAsset -Parameter Kind -Name "d365bap.tools.tepp.finops.kinds"
