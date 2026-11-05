<#
    Intelligent Asset and Kind completion for Get-PpacFinOpsAsset.

    Registered as native argument completers (rather than through the
    PSFramework TEPP host) because the completion needs $fakeBoundParameters
    to hide already-selected multi-values and to filter offers by the -Kind
    value on the command line. PowerShell suppresses custom completers on
    parameters with ValidateSet, so -Asset validates through ValidateScript
    with the same value set instead.
#>

$finOpsAssetKindCompleter = {
	param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

	$assetTips = [ordered]@{
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

	$assetKinds = @{
		"CompilerPackage"  = "NuGet"
		"Platform"         = "NuGet"
		"ApplicationSuite" = "NuGet"
		"Application1"     = "NuGet"
		"Application2"     = "NuGet"
		"SystemMetadata"   = "DeveloperFile"
		"FinOpsVsix22"     = "DeveloperFile"
		"TraceParser"      = "DeveloperFile"
		"CrossReference"   = "DeveloperFile"
		"Vhd"              = "Vhd"
	}

	$kindTips = [ordered]@{
		"NuGet"         = "The 5 NuGet packages: compiler, platform and application references"
		"DeveloperFile" = "The 4 UDE developer files: metadata, VSIX, TraceParser, cross-reference"
		"Vhd"           = "The VHD image parts (only with -Asset Vhd)"
	}

	$filterWord = "$wordToComplete".Trim("'", '"')
	$prefixText = ''

	if ("$filterWord" -like '*,*') {
		$rawParts = @("$filterWord" -split ',')
		$filterWord = "$($rawParts[-1])".Trim().Trim("'", '"').Trim()
		$prefixParts = @($rawParts[0..($rawParts.Count - 2)] | ForEach-Object { "$_".Trim().Trim("'", '"').Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

		if ($prefixParts.Count -gt 0) {
			$prefixText = ($prefixParts -join ',') + ','
		}
	}

	$filterWord = "$filterWord".Trim()
	$committedAssets = @()

	try {
		$foundCmds = @()

		if ($commandAst -is [System.Management.Automation.Language.CommandAst]) {
			$foundCmds = @($commandAst)
		}
		elseif ($null -ne $commandAst) {
			$foundCmds = @($commandAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))
		}

		$targetCmd = $null

		foreach ($candidate in $foundCmds) {
			if ($candidate.CommandElements.Count -gt 0 -and "$($candidate.CommandElements[0].ToString())" -eq "$commandName") {
				$targetCmd = $candidate
			}
		}

		if ($null -eq $targetCmd -and $foundCmds.Count -gt 0) {
			$targetCmd = $foundCmds[-1]
		}

		if ($null -ne $targetCmd) {
			for ($elIndex = 0; $elIndex -lt $targetCmd.CommandElements.Count; $elIndex++) {
				$element = $targetCmd.CommandElements[$elIndex]

				if ($element -is [System.Management.Automation.Language.CommandParameterAst] -and "$($element.ParameterName)" -ieq 'Asset') {
					$argTexts = @()

					if ($null -ne $element.Argument) {
						$argTexts += "$($element.Argument.Extent.Text)"
					}

					for ($argIndex = $elIndex + 1; $argIndex -lt $targetCmd.CommandElements.Count; $argIndex++) {
						$argElement = $targetCmd.CommandElements[$argIndex]

						if ($argElement -is [System.Management.Automation.Language.CommandParameterAst]) {
							break
						}

						if ($argElement -is [System.Management.Automation.Language.ArrayLiteralAst]) {
							foreach ($subElement in $argElement.Elements) {
								$argTexts += "$($subElement.Extent.Text)"
							}
						}
						else {
							$argTexts += "$($argElement.Extent.Text)"
						}
					}

					$rawSegments = @(("$argTexts" -join ',') -split ',')

					if ($rawSegments.Count -gt 1) {
						foreach ($rawSegment in $rawSegments[0..($rawSegments.Count - 2)]) {
							$cleanSegment = "$rawSegment".Trim().Trim("'", '"').Trim()

							if (-not [string]::IsNullOrWhiteSpace($cleanSegment)) {
								$committedAssets += $cleanSegment
							}
						}
					}

					break
				}
			}
		}
	}
	catch {
		Write-Verbose "FinOps Asset completion could not parse committed -Asset values: $($_.Exception.Message)"
	}

	foreach ($boundValue in @($fakeBoundParameters['Asset'])) {
		foreach ($boundSegment in @("$boundValue" -split ',')) {
			$cleanBound = "$boundSegment".Trim().Trim("'", '"').Trim()

			if (-not [string]::IsNullOrWhiteSpace($cleanBound) -and "$cleanBound" -ne "$filterWord") {
				$committedAssets += $cleanBound
			}
		}
	}

	if ("$parameterName" -ieq 'Kind') {
		$relevantKinds = @()

		foreach ($assetName in $committedAssets) {
			if ("$assetName" -eq '*') {
				$relevantKinds += @('NuGet', 'DeveloperFile', 'Vhd')
			}
			elseif ($assetKinds.ContainsKey($assetName)) {
				$relevantKinds += $assetKinds[$assetName]
			}
		}

		$relevantKinds = @($relevantKinds | Select-Object -Unique)

		foreach ($entry in $kindTips.GetEnumerator()) {
			if ($relevantKinds.Count -gt 0 -and $relevantKinds -notcontains $entry.Key) {
				continue
			}

			if ($entry.Key -like "$filterWord*") {
				[Management.Automation.CompletionResult]::new($entry.Key, $entry.Key, 'ParameterValue', $entry.Value)
			}
		}
	}
	else {
		$kindFilter = "$($fakeBoundParameters['Kind'])".Trim().Trim("'", '"').Trim()

		foreach ($entry in $assetTips.GetEnumerator()) {
			if ($committedAssets -contains $entry.Key) {
				continue
			}

			if (-not [string]::IsNullOrWhiteSpace($kindFilter) -and "$($assetKinds[$entry.Key])" -notlike $kindFilter) {
				continue
			}

			if ($entry.Key -like "$filterWord*") {
				if ([string]::IsNullOrWhiteSpace($prefixText)) {
					[Management.Automation.CompletionResult]::new($entry.Key, $entry.Key, 'ParameterValue', $entry.Value)
				}
				else {
					[Management.Automation.CompletionResult]::new("$prefixText$($entry.Key)", "$prefixText$($entry.Key)", 'ParameterValue', $entry.Value)
				}
			}
		}

		if ('*' -like "$filterWord*" -and -not ($committedAssets -contains '*')) {
			[Management.Automation.CompletionResult]::new('*', '*', 'ParameterValue', 'All assets, including the VHD image')
		}
	}
}

Register-ArgumentCompleter -CommandName Get-PpacFinOpsAsset -ParameterName Asset -ScriptBlock $finOpsAssetKindCompleter
Register-ArgumentCompleter -CommandName Get-PpacFinOpsAsset -ParameterName Kind -ScriptBlock $finOpsAssetKindCompleter
