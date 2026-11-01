<#
.SYNOPSIS
    Merges format views into the two loadable format files.

.DESCRIPTION
    Reads every view under xml/formats/table and xml/formats/list and writes the two loadable format files. Maintain views in the per-type files, not in the merged output.

    Shared Controls and SelectionSets are copied into the matching file once.

.PARAMETER XmlRoot
    The module xml folder.

    Default: ..\d365bap.tools\xml relative to this script.

.EXAMPLE
    .\Merge-FormatPs1Xml.ps1

    It rebuilds the two consolidated format files using the default -XmlRoot path.
#>
[CmdletBinding()]
param(
	[string] $XmlRoot = (Join-Path $PSScriptRoot '..\d365bap.tools\xml')
)

$ErrorActionPreference = 'Stop'

$XmlRoot = (Resolve-Path $XmlRoot).ProviderPath
$formatsRoot = Join-Path $XmlRoot 'formats'

$jobs = @(
	@{ Kind = 'Table'; SourceDir = Join-Path $formatsRoot 'table'; OutFile = Join-Path $XmlRoot 'd365bap.tools.Table.Format.ps1xml' }
	@{ Kind = 'List'; SourceDir = Join-Path $formatsRoot 'list'; OutFile = Join-Path $XmlRoot 'd365bap.tools.List.Format.ps1xml' }
)

function New-ConfigDoc {
	$objDocument = New-Object System.Xml.XmlDocument
	$objDocument.PreserveWhitespace = $false
	[void]$objDocument.AppendChild($objDocument.CreateXmlDeclaration('1.0', 'utf-8', $null))
	[void]$objDocument.AppendChild($objDocument.CreateElement('Configuration'))
	return $objDocument
}

function Save-PrettyXml {
	param([System.Xml.XmlDocument]$Doc, [string]$FilePath)

	$objSettings = New-Object System.Xml.XmlWriterSettings
	$objSettings.Indent = $true
	$objSettings.IndentChars = '  '
	$objSettings.Encoding = [System.Text.UTF8Encoding]::new($false)
	$objSettings.OmitXmlDeclaration = $false

	$writer = [System.Xml.XmlWriter]::Create($FilePath, $objSettings)
	try { $Doc.Save($writer) } finally { $writer.Dispose() }
}

function Merge-Kind {
	param(
		[string] $Kind,
		[string] $SourceDir,
		[string] $OutFile
	)

	if (-not (Test-Path $SourceDir -PathType Container)) {
		throw "Source directory not found: $SourceDir"
	}

	$colFiles = @(Get-ChildItem -Path $SourceDir -Filter '*.ps1xml' -File | Sort-Object Name)
	if ($colFiles.Count -eq 0) {
		throw "No .ps1xml files in $SourceDir"
	}

	$doc = New-ConfigDoc
	$viewDefs = $doc.CreateElement('ViewDefinitions')
	[void]$doc.DocumentElement.AppendChild($viewDefs)

	$hashSharedCopied = @{}
	$viewCount = 0

	foreach ($itemFile in $colFiles) {
		$tmpSource = New-Object System.Xml.XmlDocument
		$tmpSource.Load($itemFile.FullName)

		if ($tmpSource.DocumentElement.Name -ne 'Configuration') {
			throw "Root element in $($itemFile.Name) is <$($tmpSource.DocumentElement.Name)>, expected <Configuration>."
		}

		foreach ($itemSection in 'Controls', 'SelectionSets') {
			$node = $tmpSource.DocumentElement.SelectSingleNode($itemSection)
			if ($node -and -not $hashSharedCopied.ContainsKey($itemSection)) {
				[void]$doc.DocumentElement.InsertBefore(
					$doc.ImportNode($node, $true),
					$viewDefs
				)
				$hashSharedCopied[$itemSection] = $true
			}
		}

		$tmpViews = $tmpSource.DocumentElement.SelectNodes('ViewDefinitions/View')
		if ($tmpViews.Count -eq 0) {
			Write-Warning "No <View> in $($itemFile.Name); skipped."
			continue
		}

		foreach ($itemView in $tmpViews) {
			[void]$viewDefs.AppendChild($doc.ImportNode($itemView, $true))
			$viewCount++
		}

		Write-Host ("  {0,-6} {1}" -f $Kind, $itemFile.Name)
	}

	Save-PrettyXml -Doc $doc -FilePath $OutFile
	Write-Host ("Wrote {0} ({1} view(s) from {2} file(s))" -f $OutFile, $viewCount, $colFiles.Count) -ForegroundColor Green
}

foreach ($job in $jobs) {
	Merge-Kind -Kind $job.Kind -SourceDir $job.SourceDir -OutFile $job.OutFile
}
