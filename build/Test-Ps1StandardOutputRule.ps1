<#
.SYNOPSIS
    Tests the collection output lint rule.

.DESCRIPTION
    Parses fixture cmdlets and checks that array output declares a table format
    view and an AsExcelOutput switch, while scalar arrays stay exempt.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1StandardOutputDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('standard-output-rule-' + [guid]::NewGuid().ToString('N'))
$tableDirectory = Join-Path $fixtureRoot 'd365bap.tools/xml/formats/table'
$null = New-Item -ItemType Directory -Path $tableDirectory -Force
$script:caseCount = 0

function Write-TableFormat {
	param([string[]] $TypeName)
	Remove-Item -Path (Join-Path $tableDirectory '*.ps1xml') -Force -ErrorAction Ignore
	$index = 0
	foreach ($itemName in $TypeName) {
		$index++
		$document = @"
<?xml version="1.0" encoding="utf-8"?>
<Configuration><ViewDefinitions><View><Name>$itemName</Name><ViewSelectedBy><TypeName>$itemName</TypeName></ViewSelectedBy><ListControl><ListEntries><ListEntry><ListItems><ListItem><PropertyName>Name</PropertyName></ListItem></ListItems></ListEntry></ListEntries></ListControl></View></ViewDefinitions></Configuration>
"@
		[IO.File]::WriteAllText((Join-Path $tableDirectory "Type$index.Table.Format.ps1xml"), $document)
	}
	$script:Ps1TableFormatTypes = $null
}

function Assert-Output {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [ValidateSet('any', 'table', 'excel')][string] $Kind = 'any', [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder 'Get-Fixture.ps1'
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1StandardOutputDiagnostic -Analysis $analysis)
	if ($Kind -eq 'table') { $colDiagnostics = @($colDiagnostics | Where-Object { $_.Message.StartsWith('Add a table format view') }) }
	if ($Kind -eq 'excel') { $colDiagnostics = @($colDiagnostics | Where-Object { $_.Message.StartsWith('Add [switch]') }) }
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

$standard = @'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [switch] $AsExcelOutput
    )

    $res | Select-PSFObject -TypeName 'D365Bap.Tools.Known' -Property *
}
'@

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Output 'Table view and Excel switch' $standard

Write-TableFormat @()
Assert-Output 'Missing table view' $standard -Kind table -Expected 1 @('PSUseStandardCollectionOutput', 'D365Bap.Tools.Known')

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Output 'Missing Excel switch' ($standard.Replace("[switch] `$AsExcelOutput", '')) -Kind excel -Expected 1 @('PSUseStandardCollectionOutput', 'Get-Fixture')

Write-TableFormat @()
Assert-Output 'Both requirements missing' ($standard.Replace("[switch] `$AsExcelOutput", '')) -Expected 2

Write-TableFormat @()
Assert-Output 'Single object output' ($standard.Replace("[OutputType('System.Object[]')]", "[OutputType('System.Object')]")) -Expected 0

Write-TableFormat @()
Assert-Output 'Empty output type' ($standard.Replace("[OutputType('System.Object[]')]", '[OutputType()]')) -Expected 0

Write-TableFormat @()
Assert-Output 'String array output is exempt' ($standard.Replace("[OutputType('System.Object[]')]", '[OutputType([string[]])]'))

Write-TableFormat @()
Assert-Output 'Qualified string array output is exempt' ($standard.Replace("[OutputType('System.Object[]')]", "[OutputType('System.String[]')]"))

Write-TableFormat @()
Assert-Output 'Integer array output is exempt' ($standard.Replace("[OutputType('System.Object[]')]", '[OutputType([int[]])]'))

Write-TableFormat @()
Assert-Output 'Boolean array output is exempt' ($standard.Replace("[OutputType('System.Object[]')]", '[OutputType([bool[]])]'))

Write-TableFormat @()
Assert-Output 'Guid array output is exempt' ($standard.Replace("[OutputType('System.Object[]')]", '[OutputType([guid[]])]'))

Write-TableFormat @()
Assert-Output 'Decimal array output is exempt' ($standard.Replace("[OutputType('System.Object[]')]", "[OutputType('System.Decimal[]')]"))

Write-TableFormat @()
Assert-Output 'Outside the functions folder' $standard -Directory 'build'

Write-TableFormat @()
Assert-Output 'PSTypeName property needs a view' @'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [switch] $AsExcelOutput
    )

    [PSCustomObject]@{ PSTypeName = 'D365Bap.Tools.Unknown'; Name = 'demo' }
}
'@ -Kind table -Expected 1 @('D365Bap.Tools.Unknown')

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Output 'One missing type of two' @'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [switch] $AsExcelOutput
    )

    $res | Select-PSFObject -TypeName 'D365Bap.Tools.Known' -Property *
    $res | Select-PSFObject -TypeName 'D365Bap.Tools.Unknown' -Property *
}
'@ -Kind table -Expected 1 @('D365Bap.Tools.Unknown')

Write-TableFormat @()
Assert-Output 'No PSTypeName to check' @'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [switch] $AsExcelOutput
    )

    $res = 1
    $res
}
'@

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Output 'AsExcelOutput must be a switch' ($standard.Replace('[switch] $AsExcelOutput', '[string] $AsExcelOutput')) -Kind excel -Expected 1

Write-TableFormat 'D365Bap.Tools.Known'
Assert-Output 'Only the file-named function is checked' @'
function Get-Helper {
    [OutputType('System.Object[]')]
    param ()

    $res | Select-PSFObject -TypeName 'D365Bap.Tools.Unknown' -Property *
}

function Get-Fixture {
    [OutputType('System.Object[]')]
    param (
        [switch] $AsExcelOutput
    )

    $res | Select-PSFObject -TypeName 'D365Bap.Tools.Known' -Property *
}
'@

Write-Output "Collection output rule checks passed: $script:caseCount cases."
