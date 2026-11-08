<#
	Intelligent UDE package model completion.

	Registered as a native argument completer so completion keeps working
	independent of the TEPP TabExpansion2 hook state in the host session.

	Offers model names from the selected local release under
	%LOCALAPPDATA%\Microsoft\Dynamics365 where PackagesLocalDirectory
	exists. The selection follows -Version, including its
	"AppVersion (PackagesVersion)" label form. When -Version is omitted,
	models come from the highest known 10.0.X release. Each model is
	offered once, sorted ascending. Already typed -Model values are
	excluded so the same model is never offered twice. Quoting mirrors
	the word being completed.
#>

$udePackageModelCompleter = {
	param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

	$null = $commandName, $parameterName, $commandAst

	try {
		$rawWord = "$wordToComplete"
		$filterWord = $rawWord.Trim("'", '"')

		$quoteChar = ''
		if ($rawWord.StartsWith("'")) { $quoteChar = "'" }
		elseif ($rawWord.StartsWith('"')) { $quoteChar = '"' }

		if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { return }

		$packagesRoot = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Dynamics365'

		if (-not (Test-Path -LiteralPath $packagesRoot)) { return }

		$versionSelection = $null

		if ($null -ne $fakeBoundParameters -and $fakeBoundParameters.ContainsKey('Version')) {
			$versionSelection = "$($fakeBoundParameters['Version'])"
		}

		$filterVersion = $versionSelection

		if (-not [string]::IsNullOrWhiteSpace($filterVersion) -and $filterVersion -match '\(([^()]+)\)\s*$') {
			$filterVersion = $Matches[1].Trim()
		}

		$colVersionDirs = @()

		if ([string]::IsNullOrWhiteSpace($filterVersion)) {
			$colVersionDirs = @(
				Get-ChildItem -LiteralPath $packagesRoot -Directory -ErrorAction SilentlyContinue |
				Where-Object {
					($_.Name -match '^10\.0\.\d+(\.\d+)*$') `
						-and (Test-Path -LiteralPath (Join-Path -Path $_.FullName -ChildPath 'PackagesLocalDirectory'))
				} | Sort-Object { [version]$_.Name } | Select-Object -Last 1
			)
		}
		else {
			$colVersionDirs = @(
				Get-ChildItem -LiteralPath $packagesRoot -Directory -ErrorAction SilentlyContinue |
				Where-Object {
					($_.Name -like $filterVersion) `
						-and (Test-Path -LiteralPath (Join-Path -Path $_.FullName -ChildPath 'PackagesLocalDirectory'))
				}
			)
		}

		if ($colVersionDirs.Count -eq 0) { return }

		$hashSeen = @{}

		foreach ($versionDir in $colVersionDirs) {
			$pathPackagesLocal = Join-Path -Path $versionDir.FullName -ChildPath 'PackagesLocalDirectory'

			$colPackages = @(Get-ChildItem -LiteralPath $pathPackagesLocal -Directory -ErrorAction SilentlyContinue)

			foreach ($packageDir in $colPackages) {
				$descriptorDir = Join-Path -Path $packageDir.FullName -ChildPath 'Descriptor'

				if (-not (Test-Path -LiteralPath $descriptorDir)) { continue }

				$colDescriptors = @(Get-ChildItem -LiteralPath $descriptorDir -File -Filter '*.xml' -ErrorAction SilentlyContinue | Where-Object Name -ne 'FileLocations.xml')

				foreach ($descriptorFile in $colDescriptors) {
					$modelName = [System.IO.Path]::GetFileNameWithoutExtension($descriptorFile.Name)

					if ([string]::IsNullOrWhiteSpace($modelName)) { continue }
					if ($hashSeen.ContainsKey($modelName)) { continue }

					$hashSeen[$modelName] = $versionDir.Name
				}
			}
		}

		$colAlready = @()

		if ($null -ne $fakeBoundParameters -and $fakeBoundParameters.ContainsKey('Model')) {
			$colAlready = @($fakeBoundParameters['Model'] | ForEach-Object { "$_" })
		}

		$found = @(
			$hashSeen.Keys |
			Where-Object { $_ -like "$filterWord*" } |
			Where-Object {
				$candidate = $_
				@($colAlready | Where-Object { "$_" -ieq $candidate }).Count -eq 0
			} |
			Sort-Object -Unique
		)

		foreach ($modelName in $found) {
			$completionText = $modelName

			if ($quoteChar -ne '') {
				$completionText = "$quoteChar$completionText$quoteChar"
			}
			elseif ($completionText -match '\s') {
				$completionText = "'$completionText'"
			}

			$toolTip = "Model $modelName in $($hashSeen[$modelName])"

			[System.Management.Automation.CompletionResult]::new($completionText, $modelName, 'ParameterValue', $toolTip)
		}
	}
	catch { $null = $_.Exception.Message }
}

Register-ArgumentCompleter -CommandName Get-UdePackageModel -ParameterName Model -ScriptBlock $udePackageModelCompleter
