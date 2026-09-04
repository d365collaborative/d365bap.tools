<#
.SYNOPSIS
    Merges per-view *.Format.ps1xml files into the two loadable format files.

.DESCRIPTION
    Reads every view under xml/formats/table and xml/formats/list and writes:

      xml/d365bap.tools.Table.Format.ps1xml
      xml/d365bap.tools.List.Format.ps1xml

    Those two files are what the module loads (table first, then list). Do not
    edit them by hand. Create and maintain views in the per-type files under
    xml/formats.

    Shared <Controls> / <SelectionSets> from a source file are copied into the
    matching consolidated file once.

.PARAMETER XmlRoot
    The module xml folder. Defaults to ..\d365bap.tools\xml relative to this script.

.EXAMPLE
    .\Merge-FormatPs1Xml.ps1

    Rebuilds the two consolidated format files from xml/formats.
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
    @{ Kind = 'List';  SourceDir = Join-Path $formatsRoot 'list';  OutFile = Join-Path $XmlRoot 'd365bap.tools.List.Format.ps1xml' }
)

function New-ConfigDoc {
    $d = New-Object System.Xml.XmlDocument
    $d.PreserveWhitespace = $false
    [void]$d.AppendChild($d.CreateXmlDeclaration('1.0', 'utf-8', $null))
    [void]$d.AppendChild($d.CreateElement('Configuration'))
    return $d
}

function Save-PrettyXml {
    param([System.Xml.XmlDocument]$Doc, [string]$FilePath)

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.IndentChars = '  '
    $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
    $settings.OmitXmlDeclaration = $false

    $writer = [System.Xml.XmlWriter]::Create($FilePath, $settings)
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

    $files = @(Get-ChildItem -Path $SourceDir -Filter '*.ps1xml' -File | Sort-Object Name)
    if ($files.Count -eq 0) {
        throw "No .ps1xml files in $SourceDir"
    }

    $doc = New-ConfigDoc
    $viewDefs = $doc.CreateElement('ViewDefinitions')
    [void]$doc.DocumentElement.AppendChild($viewDefs)

    $sharedCopied = @{}
    $viewCount = 0

    foreach ($file in $files) {
        $src = New-Object System.Xml.XmlDocument
        $src.Load($file.FullName)

        if ($src.DocumentElement.Name -ne 'Configuration') {
            throw "Root element in $($file.Name) is <$($src.DocumentElement.Name)>, expected <Configuration>."
        }

        foreach ($section in 'Controls', 'SelectionSets') {
            $node = $src.DocumentElement.SelectSingleNode($section)
            if ($node -and -not $sharedCopied.ContainsKey($section)) {
                [void]$doc.DocumentElement.InsertBefore(
                    $doc.ImportNode($node, $true),
                    $viewDefs
                )
                $sharedCopied[$section] = $true
            }
        }

        $views = $src.DocumentElement.SelectNodes('ViewDefinitions/View')
        if ($views.Count -eq 0) {
            Write-Warning "No <View> in $($file.Name); skipped."
            continue
        }

        foreach ($view in $views) {
            [void]$viewDefs.AppendChild($doc.ImportNode($view, $true))
            $viewCount++
        }

        Write-Host ("  {0,-6} {1}" -f $Kind, $file.Name)
    }

    Save-PrettyXml -Doc $doc -FilePath $OutFile
    Write-Host ("Wrote {0} ({1} view(s) from {2} file(s))" -f $OutFile, $viewCount, $files.Count) -ForegroundColor Green
}

foreach ($job in $jobs) {
    Merge-Kind -Kind $job.Kind -SourceDir $job.SourceDir -OutFile $job.OutFile
}
