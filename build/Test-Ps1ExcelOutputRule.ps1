<#
.SYNOPSIS
    Tests the collection Excel output lint rule.

.DESCRIPTION
    Parses fixture cmdlets and checks that array output declares a switch
    AsExcelOutput parameter.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1ExcelOutputDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('excel-output-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-Excel {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder 'Get-Fixture.ps1'
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$diagnostics = @(Get-Ps1ExcelOutputDiagnostic -Analysis $analysis)
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
    param (
        [switch] $AsExcelOutput
    )

    process {
        $resCol = @()
        $resCol
    }
}
'@
Assert-Excel 'Collection with AsExcelOutput' $collection

Assert-Excel 'Only the file-named function is checked' @'
function Get-Helper {
    [OutputType('System.Object[]')]
    param ()
}

function Get-Fixture {
    [OutputType('System.Object[]')]
    param (
        [switch] $AsExcelOutput
    )
}
'@

Assert-Excel 'Collection without AsExcelOutput' (@'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param ()

    process {
        $resCol = @()
        $resCol
    }
}
'@) -Expected 1 @('PSUseAsExcelOutput', 'Get-Fixture')

Assert-Excel 'String array without AsExcelOutput is exempt' ($collection.Replace("[OutputType('System.Object[]')]", '[OutputType([string[]])]').Replace("[switch] `$AsExcelOutput", ''))

Assert-Excel 'Integer array without AsExcelOutput is exempt' ($collection.Replace("[OutputType('System.Object[]')]", '[OutputType([int[]])]').Replace("[switch] `$AsExcelOutput", ''))

Assert-Excel 'Boolean array without AsExcelOutput is exempt' ($collection.Replace("[OutputType('System.Object[]')]", '[OutputType([bool[]])]').Replace("[switch] `$AsExcelOutput", ''))

Assert-Excel 'Qualified string array without AsExcelOutput is exempt' ($collection.Replace("[OutputType('System.Object[]')]", "[OutputType('System.String[]')]").Replace("[switch] `$AsExcelOutput", ''))

Assert-Excel 'Single object without AsExcelOutput' ($collection.Replace("[OutputType('System.Object[]')]", "[OutputType('System.Object')]").Replace("[switch] `$AsExcelOutput", ''))

Assert-Excel 'Empty output type without AsExcelOutput' ($collection.Replace("[OutputType('System.Object[]')]", '[OutputType()]').Replace("[switch] `$AsExcelOutput", ''))

Assert-Excel 'AsExcelOutput must be a switch' ($collection.Replace('[switch] $AsExcelOutput', '[string] $AsExcelOutput')) -Expected 1

Assert-Excel 'Outside the functions folder' (@'
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param ()

    process {
        $resCol = @()
        $resCol
    }
}
'@) -Directory 'build'

Write-Output "Excel output rule checks passed: $script:caseCount cases."
