<#
.SYNOPSIS
    Tests the collection table format lint rule.

.DESCRIPTION
    Parses fixture cmdlets and checks that collection output with a PSTypeName
    requires a matching table format view.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1TableFormatDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('table-format-rule-' + [guid]::NewGuid().ToString('N'))
$tableDirectory = Join-Path $fixtureRoot 'd365bap.tools/xml/formats/table'
$null = New-Item -ItemType Directory -Path $tableDirectory -Force
$script:caseCount = 0

function Write-TableFormat {
	param([string[]] $TypeName)
	Remove-Item -Path (Join-Path $tableDirectory '*.ps1xml') -Force -ErrorAction Ignore
	$index = 0
	foreach ($name in $TypeName) {
		$index++
		$document = @"
<?xml version="1.0" encoding="utf-8"?>
<Configuration><ViewDefinitions><View><Name>$name</Name><ViewSelectedBy><TypeName>$name</TypeName></ViewSelectedBy><ListControl><ListEntries><ListEntry><ListItems><ListItem><PropertyName>Name</PropertyName></ListItem></ListItems></ListEntry></ListEntries></ListControl></View></ViewDefinitions></Configuration>
"@
		[IO.File]::WriteAllText((Join-Path $tableDirectory "Type$index.Table.Format.ps1xml"), $document)
	}
	$script:Ps1TableFormatTypes = $null
}

function Assert-Table {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder 'Get-Fixture.ps1'
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$diagnostics = @(Get-Ps1TableFormatDiagnostic -Analysis $analysis)
	if ($diagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($diagnostics.Count): $($diagnostics.Message -join ' ')"
	}
	$message = @($diagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($fragment in $ExpectedText) {
		if (-not $message.Contains($fragment)) { throw "${Label}: missing '$fragment' in '$message'" }
	}
	$script:caseCount++
}

$collection = @'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param ()

    $res | Select-PSFObject -TypeName 'D365Bap.Tools.Known' -Property *
}
'@

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Table 'Known table view passes' $collection

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Table 'Only the file-named function is checked' @'
function Get-Helper {
    [OutputType('System.Object[]')]
    param ()

    $res | Select-PSFObject -TypeName 'D365Bap.Tools.Unknown' -Property *
}

function Get-Fixture {
    [OutputType('System.Object[]')]
    param ()

    $res | Select-PSFObject -TypeName 'D365Bap.Tools.Known' -Property *
}
'@

Write-TableFormat @()
Assert-Table 'Missing table view' $collection -Expected 1 @('PSUseTableFormatView', 'D365Bap.Tools.Known')

Write-TableFormat @()
Assert-Table 'List view only still requires a table view' $collection -Expected 1

Write-TableFormat @()
Assert-Table 'Single object output' ($collection.Replace("[OutputType('System.Object[]')]", "[OutputType('System.Object')]"))

Write-TableFormat @()
Assert-Table 'Empty output type' ($collection.Replace("[OutputType('System.Object[]')]", '[OutputType()]'))

Write-TableFormat @()
Assert-Table 'String array output is exempt' ($collection.Replace("[OutputType('System.Object[]')]", '[OutputType([string[]])]'))

Write-TableFormat @()
Assert-Table 'Qualified string array output is exempt' ($collection.Replace("[OutputType('System.Object[]')]", "[OutputType('System.String[]')]"))

Write-TableFormat @()
Assert-Table 'Integer array output is exempt' ($collection.Replace("[OutputType('System.Object[]')]", '[OutputType([int[]])]'))

Write-TableFormat @()
Assert-Table 'Boolean array output is exempt' ($collection.Replace("[OutputType('System.Object[]')]", '[OutputType([bool[]])]'))

Write-TableFormat @()
Assert-Table 'Guid array output is exempt' ($collection.Replace("[OutputType('System.Object[]')]", '[OutputType([guid[]])]'))

Write-TableFormat @()
Assert-Table 'Decimal array output is exempt' ($collection.Replace("[OutputType('System.Object[]')]", "[OutputType('System.Decimal[]')]"))

Write-TableFormat @()
Assert-Table 'Outside the functions folder' $collection -Directory 'build'

Write-TableFormat @()
Assert-Table 'PSTypeName property' @'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param ()

    [PSCustomObject]@{ PSTypeName = 'D365Bap.Tools.Unknown'; Name = 'demo' }
}
'@ -Expected 1 @('D365Bap.Tools.Unknown')

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Table 'One missing type of two' @'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param ()

    $res | Select-PSFObject -TypeName 'D365Bap.Tools.Known' -Property *
    $res | Select-PSFObject -TypeName 'D365Bap.Tools.Unknown' -Property *
}
'@ -Expected 1 @('D365Bap.Tools.Unknown')

Write-TableFormat @()
Assert-Table 'No PSTypeName to check' @'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param ()

    $res = 1
    $res
}
'@

Write-Output "Table format rule checks passed: $script:caseCount cases."
