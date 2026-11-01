<#
.SYNOPSIS
    Tests the formatted URL lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that URL string manipulation uses the
    format operator. Interpolation and concatenation are reported; format
    strings, literal URLs, here-strings, and non-URL strings stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1FormattedUrlDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('formatted-url-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-FormattedUrl {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1FormattedUrlDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-FormattedUrl 'Interpolated absolute URL' @'
function Get-Fixture {
    $uri = "https://api.powerplatform.com/environments?api-version=$apiVersion"
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1 @('PSUseFormattedUrl', 'not string interpolation')

Assert-FormattedUrl 'Interpolated relative URL' @'
function Get-Fixture {
    $uri = "$base/environments?api-version=$apiVersion"
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1

Assert-FormattedUrl 'Interpolated host' @'
function Get-Fixture {
    $uri = "https://$host/environments"
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1

Assert-FormattedUrl 'Format operator on the same line' @'
function Get-Fixture {
    $uri = 'https://api.powerplatform.com/environments?api-version={0}' -f $apiVersion
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1 @('PSUseFormattedUrl', 'Put -f on its own continuation line')

Assert-FormattedUrl 'Format operator on a continuation line' @'
function Get-Fixture {
    $uri = 'https://api.powerplatform.com/environments?api-version={0}' `
        -f $apiVersion
    Invoke-RestMethod -Uri $uri
}
'@

Assert-FormattedUrl 'Ordered placeholders on one line' @'
function Get-Fixture {
    $uri = 'https://{0}.example/{1}' -f $Tenant, $Region
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1 @('PSUseFormattedUrl', 'Put -f on its own continuation line')

Assert-FormattedUrl 'Ordered placeholders with each input on its own line' @'
function Get-Fixture {
    $uri = 'https://{0}.example/{1}' `
        -f $Tenant,
        $Region
    Invoke-RestMethod -Uri $uri
}
'@

Assert-FormattedUrl 'Three inputs on one line' @'
function Get-Fixture {
    $uri = 'https://{0}.example/{1}/{2}' -f $Tenant, $Region, $EnvironmentId
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1

Assert-FormattedUrl 'Three inputs with one per line' @'
function Get-Fixture {
    $uri = 'https://{0}.example/{1}/{2}' `
        -f $Tenant,
        $Region,
        $EnvironmentId
    Invoke-RestMethod -Uri $uri
}
'@

Assert-FormattedUrl 'Format operator inline with split inputs' @'
function Get-Fixture {
    $uri = 'https://{0}.example/{1}' -f $Tenant,
        $Region
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1

Assert-FormattedUrl 'Format operator on a new line with crowded inputs' @'
function Get-Fixture {
    $uri = 'https://{0}.example/{1}' `
        -f $Tenant, $Region
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1

Assert-FormattedUrl 'Swapped placeholders' @'
function Get-Fixture {
    $uri = 'https://{1}.example/{0}' `
        -f $Region,
        $Tenant
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1 @('left-to-right order')

Assert-FormattedUrl 'Placeholder list starts at two' @'
function Get-Fixture {
    $uri = 'https://{2}.example' `
        -f $Tenant
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1 @('Start URL format placeholders at {0}')

Assert-FormattedUrl 'Repeated placeholder with one input' @'
function Get-Fixture {
    $uri = 'https://{0}.example/{0}' `
        -f $Tenant
    Invoke-RestMethod -Uri $uri
}
'@

Assert-FormattedUrl 'Non-URL format order' @'
function Get-Fixture {
    $message = 'Hello {1} {0}' -f $Name, $Greeting
    $message
}
'@

Assert-FormattedUrl 'Literal URL' @'
function Get-Fixture {
    $uri = 'https://api.powerplatform.com/environments'
    Invoke-RestMethod -Uri $uri
}
'@

Assert-FormattedUrl 'URL concatenation' @'
function Get-Fixture {
    $uri = 'https://api.powerplatform.com/environments' + $EnvironmentId
    Invoke-RestMethod -Uri $uri
}
'@ -Expected 1 @('not string concatenation')

Assert-FormattedUrl 'Non-URL concatenation' @'
function Get-Fixture {
    $text = '/environments' + $EnvironmentId
    $text
}
'@

Assert-FormattedUrl 'Non-URL interpolation' @'
function Get-Fixture {
    $message = "Hello $Name"
    $message
}
'@

Assert-FormattedUrl 'Documented URL in a here-string' @'
function Get-Fixture {
    $example = @"
    GET https://api.powerplatform.com/environments?api-version=$apiVersion
"@
    $example
}
'@

Assert-FormattedUrl 'Build scripts are exempt' @'
function Get-Fixture {
    $uri = "https://api.powerplatform.com/environments?api-version=$apiVersion"
    $uri
}
'@ -Directory 'build'

Assert-FormattedUrl 'Tepp fixtures are exempt' @'
function Get-Fixture {
    $uri = "https://api.powerplatform.com/environments?api-version=$apiVersion"
    $uri
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-FormattedUrl 'Test files are exempt' @'
function Get-Fixture {
    $uri = "https://api.powerplatform.com/environments?api-version=$apiVersion"
    $uri
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Formatted URL rule checks passed: $script:caseCount cases."
