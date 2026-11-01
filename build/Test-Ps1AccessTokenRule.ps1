<#
.SYNOPSIS
    Tests the BapAccessToken endpoint switch lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that known audiences are requested through
    their endpoint switch instead of a literal resource URL. Also checks that the
    rule map matches the runtime endpoint map.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1AccessTokenDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('access-token-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-AccessToken {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $FileName = 'Get-Fixture.ps1', [string] $Directory = 'd365bap.tools/functions')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$diagnostics = @(Get-Ps1AccessTokenDiagnostic -Analysis $analysis)
	if ($diagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($diagnostics.Count): $($diagnostics.Message -join ' ')"
	}
	$message = @($diagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($fragment in $ExpectedText) {
		if (-not $message.Contains($fragment)) { throw "${Label}: missing '$fragment' in '$message'" }
	}
	$script:caseCount++
}

$graph = @'
function Get-Fixture {
    $secure = Get-BapAccessToken -ResourceUrl "https://graph.microsoft.com/"
}
'@
Assert-AccessToken 'Graph literal' $graph 1 @('PSUseBapAccessTokenEndpointSwitch', '-Graph', 'Microsoft Graph')

Assert-AccessToken 'Bap literal' ($graph.Replace('https://graph.microsoft.com/', 'https://service.powerapps.com/')) 1 @('-Bap')
Assert-AccessToken 'PowerPlatform literal' ($graph.Replace('https://graph.microsoft.com/', 'https://api.powerplatform.com')) 1 @('-PowerPlatform', 'Power Platform API')
Assert-AccessToken 'PowerPlatformAdmin literal' ($graph.Replace('https://graph.microsoft.com/', '065d9450-1e87-434e-ac2f-69af271549ed')) 1 @('-PowerPlatformAdmin', 'Power Platform admin API')

Assert-AccessToken 'Trailing slash is ignored' ($graph.Replace('https://graph.microsoft.com/', 'https://graph.microsoft.com')) 1
Assert-AccessToken 'Leading and trailing whitespace is ignored' ($graph.Replace('https://graph.microsoft.com/', '  https://graph.microsoft.com/  ')) 1
Assert-AccessToken 'Case is ignored' ($graph.Replace('https://graph.microsoft.com/', 'HTTPS://GRAPH.MICROSOFT.COM/')) 1
Assert-AccessToken 'Single quotes' ($graph.Replace('"https://graph.microsoft.com/"', "'https://graph.microsoft.com/'")) 1
Assert-AccessToken 'Colon binding' ($graph.Replace('-ResourceUrl "https://graph.microsoft.com/"', '-ResourceUrl:"https://graph.microsoft.com/"')) 1
Assert-AccessToken 'Parameter abbreviation' ($graph.Replace('-ResourceUrl', '-Resource')) 1
Assert-AccessToken 'Positional argument' ($graph.Replace('-ResourceUrl "https://graph.microsoft.com/"', '"https://graph.microsoft.com/"')) 1
Assert-AccessToken 'Module qualified command' ($graph.Replace('Get-BapAccessToken', 'd365bap.tools\Get-BapAccessToken')) 1
Assert-AccessToken 'Mixed case command name' ($graph.Replace('Get-BapAccessToken', 'get-bapaccesstoken')) 1

Assert-AccessToken 'Switch usage' ($graph.Replace('-ResourceUrl "https://graph.microsoft.com/"', '-Graph'))
Assert-AccessToken 'Dataverse audience' ($graph.Replace('https://graph.microsoft.com/', 'https://contoso.crm4.dynamics.com/'))
Assert-AccessToken 'Audience with a path is not a known endpoint' ($graph.Replace('https://graph.microsoft.com/', 'https://graph.microsoft.com/v1.0/users'))
Assert-AccessToken 'Variable argument' ($graph.Replace('"https://graph.microsoft.com/"', '$baseUri'))
Assert-AccessToken 'Splat argument' ($graph.Replace('-ResourceUrl "https://graph.microsoft.com/"', '@params'))
Assert-AccessToken 'Empty literal' ($graph.Replace('"https://graph.microsoft.com/"', '""'))
Assert-AccessToken 'No arguments' ($graph.Replace(' -ResourceUrl "https://graph.microsoft.com/"', ''))

Assert-AccessToken 'Other commands are ignored' @'
function Get-Fixture {
    $secure = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com/"
}
'@

Assert-AccessToken 'Outside the module' $graph -Directory 'build'
Assert-AccessToken 'Internal functions are checked' $graph -Directory 'd365bap.tools/internal' -Expected 1
Assert-AccessToken 'Test files are never checked' $graph -FileName 'Get-Ps1AccessTokenRule.Tests.ps1'

Assert-AccessToken 'Two violations in one file' @'
function Get-Fixture {
    $graph = Get-BapAccessToken -ResourceUrl "https://graph.microsoft.com/"
    $bap = Get-BapAccessToken -ResourceUrl "https://service.powerapps.com/"
}
'@ -Expected 2

$runtimePath = Join-Path $PSScriptRoot '../d365bap.tools/internal/functions/Get-BapAccessToken.ps1'
$runtimeAnalysis = Get-Ps1Analysis -Path (Resolve-Path -LiteralPath $runtimePath).Path
$assignment = @($runtimeAnalysis.Ast.FindAll({
			param($node)
			$node -is [Management.Automation.Language.AssignmentStatementAst] -and
			$node.Left.Extent.Text -eq '$script:BapAccessTokenEndpoints'
		}, $true))
if ($assignment.Count -ne 1) { throw "Expected one runtime endpoint map, found $($assignment.Count)." }
$runtimeMap = @($assignment[0].Right.Expression.Child.KeyValuePairs)
if ($runtimeMap.Count -eq 0) { throw 'Runtime endpoint map is empty.' }

foreach ($pair in $runtimeMap) {
	$name = $pair.Item1.Value
	$value = $pair.Item2.SafeGetValue()
	$key = ConvertTo-Ps1BapAccessTokenResourceKey $value
	if (-not $script:Ps1BapAccessTokenEndpoints.Contains($key)) {
		throw "Lint map is missing the runtime endpoint ${name}: $value"
	}
	$ruleEndpoint = $script:Ps1BapAccessTokenEndpoints[$key]
	if ($ruleEndpoint.Switch -ne $name) { throw "Lint map points $name at -$($ruleEndpoint.Switch)." }
}

if ($script:Ps1BapAccessTokenEndpoints.Count -ne $runtimeMap.Count) {
	throw "Lint map has $($script:Ps1BapAccessTokenEndpoints.Count) entries, runtime map has $($runtimeMap.Count)."
}

$script:caseCount++
Write-Output "Access token rule checks passed: $script:caseCount cases."
