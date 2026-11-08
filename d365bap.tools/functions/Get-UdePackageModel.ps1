<#
    .SYNOPSIS
        Gets local UDE package models

    .DESCRIPTION
        Lists entries from local package folders with their descriptor references.

    .PARAMETER Version
        Exact release name. Label form allowed. Highest known release when omitted.

    .PARAMETER Model
        Model inside a package. Supports wildcards. Allows multiple.

        Default: '*'.

    .PARAMETER DependencyOrdered
        Sorts results by reliance levels. DepLevel always shown.

    .PARAMETER AsExcelOutput
        Exports results to an Excel workbook.

    .EXAMPLE
        PS C:\> Get-UdePackageModel

        Lists entries from the highest local release.
        It uses the default -Version highest match for selection.
        It uses the default -Model '*' for all entries.

    .EXAMPLE
        PS C:\> Get-UdePackageModel -Version '10.0.2527.250'

        Lists entries from a specific local release.
        It uses -Version '10.0.2527.250' for release selection.
        It uses the default -Model '*' for all entries.

    .EXAMPLE
        PS C:\> Get-UdePackageModel -Model 'Foundation'

        Lists a single entry from the highest local release.
        It uses the default -Version highest match for selection.
        It uses -Model 'Foundation' for entry selection.

    .EXAMPLE
        PS C:\> Get-UdePackageModel -DependencyOrdered

        Lists entries sorted by reliance levels.
        It uses -DependencyOrdered for DepLevel ordering.
        It uses the default -Version highest match for selection.
        It uses the default -Model '*' for all entries.

    .EXAMPLE
        PS C:\> Get-UdePackageModel -AsExcelOutput

        Lists entries into an Excel workbook.
        It uses -AsExcelOutput for workbook output.
        It uses the default -Version highest match for selection.
        It uses the default -Model '*' for all entries.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdePackageModel {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.UdePackageModel[]')]
	param (
		[string] $Version,

		[SupportsWildcards()]
		[string[]] $Model = '*',

		[switch] $DependencyOrdered,

		[switch] $AsExcelOutput
	)

	begin {
		$pathPackagesRoot = Join-Path -Path $env:LOCALAPPDATA `
			-ChildPath 'Microsoft\Dynamics365'

	}

	process {
		$filterVersion = $Version

		if ($filterVersion -match '\(([^()]+)\)\s*$') {
			$filterVersion = $Matches[1].Trim()
		}

		$versionOmitted = -not $PSBoundParameters.ContainsKey('Version')

		if (-not (Test-Path -LiteralPath $pathPackagesRoot)) {
			$messageString = "Could not find local Dynamics 365 folder."

			Write-PSFMessage -Level Important `
				-Message $messageString

			Stop-PSFFunction -Message "Stopping because the local folder was NOT found." `
				-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

			return
		}

		$colVersionDirs = @()

		if ($versionOmitted) {
			$colKnown = @(
				Get-ChildItem -LiteralPath $pathPackagesRoot `
					-Directory |
				Where-Object {
					($_.Name -match '^10\.0\.\d+(\.\d+)*$') `
						-and (Test-Path -LiteralPath (Join-Path -Path $_.FullName `
								-ChildPath 'PackagesLocalDirectory'))
				} | Sort-Object { [version]$_.Name }
			)

			if ($colKnown.Count -eq 0) {
				$messageString = "No known releases were found locally."

				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because no known release was found." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}

			$colVersionDirs = @(
				$colKnown |
				Select-Object -Last 1
			)

		}
		else {
			$colFiltered = @(
				Get-ChildItem -LiteralPath $pathPackagesRoot `
					-Directory |
				Where-Object {
					($_.Name -eq $filterVersion) `
						-and (Test-Path -LiteralPath (Join-Path -Path $_.FullName `
								-ChildPath 'PackagesLocalDirectory'))
				} | Sort-Object { $_.Name }
			)

			if ($colFiltered.Count -eq 0) {
				$messageString = "No local release matched the name."

				Write-PSFMessage -Level Important `
					-Message $messageString

				Stop-PSFFunction -Message "Stopping because no local release matched." `
					-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))

				return
			}

			$colVersionDirs = @($colFiltered)

		}

		$colAll = @(
			foreach ($itemVersionDir in $colVersionDirs) {
				$tmpBuild = $itemVersionDir.Name

				$tmpAppVersion = ''

				$tmpVersionInfo = Resolve-FinOpsVersionFromCache -Build $tmpBuild `
					-IgnoreStamp

				if (-not ($null -eq $tmpVersionInfo)) {
					if (-not [string]::IsNullOrWhiteSpace($tmpVersionInfo.AppVersion)) {
						$tmpAppVersion = "$($tmpVersionInfo.AppVersion)"
					}
				}

				$tmpPathPackagesLocal = Join-Path -Path $itemVersionDir.FullName `
					-ChildPath 'PackagesLocalDirectory'

				$tmpHashRefs = @{}

				$tmpHashInfo = @{}

				$tmpColPackages = @(
					Get-ChildItem -LiteralPath $tmpPathPackagesLocal `
						-Directory
				)

				foreach ($itemPackageDir in $tmpColPackages) {
					$tmpDescriptorDir = Join-Path -Path $itemPackageDir.FullName `
						-ChildPath 'Descriptor'

					if (-not (Test-Path -LiteralPath $tmpDescriptorDir)) { continue }

					$tmpColDescriptors = @(
						Get-ChildItem -LiteralPath $tmpDescriptorDir `
							-File `
							-Filter '*.xml' |
						Where-Object Name -ne 'FileLocations.xml'
					)

					foreach ($itemDescriptorFile in $tmpColDescriptors) {
						$tmpModelName = [System.IO.Path]::GetFileNameWithoutExtension($itemDescriptorFile.Name)

						if ([string]::IsNullOrWhiteSpace($tmpModelName)) { continue }

						if ($tmpHashInfo.ContainsKey($tmpModelName)) { continue }

						$tmpColRefs = @()

						$tmpDisplayName = ''

						$tmpPublisher = ''

						try {
							[xml]$tmpDescriptorXml = Get-Content -LiteralPath $itemDescriptorFile.FullName `
								-Raw `
								-Encoding UTF8 `
								-ErrorAction Stop

							$tmpColRefs = @(
								$tmpDescriptorXml.AxModelInfo.ModuleReferences.string |
								Where-Object { -not [System.String]::IsNullOrWhiteSpace($_) }
							)

							if (-not ($null -eq $tmpDescriptorXml.AxModelInfo.DisplayName)) {
								$tmpDisplayName = "$($tmpDescriptorXml.AxModelInfo.DisplayName)"
							}

							if (-not ($null -eq $tmpDescriptorXml.AxModelInfo.Publisher)) {
								$tmpPublisher = "$($tmpDescriptorXml.AxModelInfo.Publisher)"
							}

							if ((-not ($null -eq $tmpDescriptorXml.AxModelInfo.Name)) `
									-and (-not [string]::IsNullOrWhiteSpace($tmpDescriptorXml.AxModelInfo.Name))) {
								$tmpModelName = "$($tmpDescriptorXml.AxModelInfo.Name)"
							}
						}
						catch {
							Write-PSFMessage -Level Verbose `
								-Message "Skipping unreadable descriptor."

							continue
						}

						if ($tmpHashInfo.ContainsKey($tmpModelName)) { continue }

						$tmpHashRefs[$tmpModelName] = @($tmpColRefs)

						$tmpModelDirPath = Join-Path -Path $itemPackageDir.FullName `
							-ChildPath $tmpModelName

						if (-not (Test-Path -LiteralPath $tmpModelDirPath)) {
							$tmpModelDirPath = ''
						}

						$tmpHashInfo[$tmpModelName] = [pscustomobject][ordered]@{
							Build          = $tmpBuild
							AppVersion     = $tmpAppVersion
							Package        = $itemPackageDir.Name
							Model          = $tmpModelName
							DisplayName    = $tmpDisplayName
							Publisher      = $tmpPublisher
							Dependencies   = @($tmpColRefs)
							DescriptorPath = $itemDescriptorFile.FullName
							ModelPath      = $tmpModelDirPath
						}
					}
				}

				$tmpColMatchedNames = @(
					$tmpHashInfo.Keys |
					Where-Object {
						$tmpCurrentName = $_

						$tmpMatched = $false

						foreach ($itemModelPattern in $Model) {
							if ($tmpCurrentName -like $itemModelPattern) {
								$tmpMatched = $true

								break
							}
						}

						$tmpMatched
					} | Sort-Object -Unique
				)

				$tmpHashLevel = Get-UdePackageModelLevel -ReferencesByModel $tmpHashRefs

				foreach ($itemMatchedName in $tmpColMatchedNames) {
					$tmpInfoObj = $tmpHashInfo[$itemMatchedName]

					$tmpLevelValue = 0

					if ($tmpHashLevel.ContainsKey($itemMatchedName)) {
						$tmpLevelValue = [int]$tmpHashLevel[$itemMatchedName]
					}

					[pscustomobject][ordered]@{
						Build          = $tmpInfoObj.Build
						AppVersion     = $tmpInfoObj.AppVersion
						Package        = $tmpInfoObj.Package
						Model          = $tmpInfoObj.Model
						DisplayName    = $tmpInfoObj.DisplayName
						Publisher      = $tmpInfoObj.Publisher
						DepLevel       = $tmpLevelValue
						Dependencies   = @($tmpInfoObj.Dependencies)
						DependsOn      = @($tmpInfoObj.Dependencies).Count
						DescriptorPath = $tmpInfoObj.DescriptorPath
						ModelPath      = $tmpInfoObj.ModelPath
					}
				}

			}
		)

		if ($DependencyOrdered) {
			$colAll = @(
				$colAll |
				Sort-Object -Property `
				@{
					Expression = 'DepLevel'
					Descending = $false
				}, `
				@{
					Expression = 'Model'
					Descending = $false
				}
			)

		}
		else {
			$colAll = @(
				$colAll |
				Sort-Object -Property `
				@{
					Expression = 'Model'
					Descending = $false
				}
			)

		}

		$colOutput = @(
			$colAll |
			Select-PSFObject `
				-TypeName 'D365Bap.Tools.UdePackageModel' `
				-Property *
		)

		if ($AsExcelOutput) {
			$colOutput |
			Export-Excel `
				-WorksheetName "Get-UdePackageModel"

			return
		}

		$colOutput
	}

	end {
	}
}

function Get-UdePackageModelLevel {
	[CmdletBinding()]
	[OutputType([hashtable])]
	param (
		[Parameter(Mandatory = $true)]
		[hashtable] $ReferencesByModel
	)

	$hashLevel = @{}

	$colVisiting = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

	$getLevel = $null

	$getLevel = {
		param ([string] $Name)

		if ($hashLevel.ContainsKey($Name)) {
			$hashLevel[$Name]

			return
		}

		if (-not $ReferencesByModel.ContainsKey($Name)) {
			$hashLevel[$Name] = 0

			0

			return
		}

		if (-not $colVisiting.Add($Name)) {
			0

			return
		}

		try {
			$colDeps = @(
				$ReferencesByModel[$Name] |
				Where-Object { $ReferencesByModel.ContainsKey($_) }
			)

			if ($colDeps.Count -eq 0) {
				$hashLevel[$Name] = 0

				0

				return
			}

			$tmpMaxDep = -1

			foreach ($itemDepName in $colDeps) {
				$tmpDepLevel = & $getLevel $itemDepName

				if ($tmpDepLevel -gt $tmpMaxDep) {
					$tmpMaxDep = $tmpDepLevel
				}
			}

			$hashLevel[$Name] = $tmpMaxDep + 1

			$tmpMaxDep + 1

			return
		}
		finally {
			$colVisiting.Remove($Name) > $null
		}
	}

	foreach ($itemModelName in $ReferencesByModel.Keys) {
		& $getLevel $itemModelName > $null
	}

	$hashLevel
}
