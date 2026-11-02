<#
.SYNOPSIS
    Tests the redundant identity projection lint rule.

.DESCRIPTION
    Parses fixture scripts and checks that a Select-PSFObject identity mapping
    over an inline [pscustomobject] hashtable is reported. Case normalisation,
    subsets, non-literal input, and other projections stay clean.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1RedundantIdentityProjectionDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('redundant-identity-projection-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-IdentityProjection {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1RedundantIdentityProjectionDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-IdentityProjection 'Full identity mapping' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Id   = 1
        Name = 'fixture'
    } | Select-PSFObject -TypeName 'D365Bap.Tools.Fixture' -Property 'Id as Id', 'Name as Name'

    $objResult
}
'@ -Expected 1 @('PSAvoidRedundantIdentityProjection', 'Drop -Property')

Assert-IdentityProjection 'Single identity element' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Id = 1
    } | Select-PSFObject -Property 'Id as Id'
    $objResult
}
'@ -Expected 1

Assert-IdentityProjection 'Property before TypeName' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Id   = 1
        Name = 'fixture'
    } | Select-PSFObject -Property 'Id as Id', 'Name as Name' -TypeName 'D365Bap.Tools.Fixture'

    $objResult
}
'@ -Expected 1

Assert-IdentityProjection 'Underscore and digit names' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        app_id_1 = 1
    } | Select-PSFObject -Property 'app_id_1 as app_id_1'
    $objResult
}
'@ -Expected 1

Assert-IdentityProjection 'Case normalisation is not identity' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        appId = 1
    } | Select-PSFObject -Property 'appId as AppId'
    $objResult
}
'@

Assert-IdentityProjection 'Subset of the properties' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Id   = 1
        Name = 'fixture'
    } | Select-PSFObject -Property 'Name as Name'
    $objResult
}
'@

Assert-IdentityProjection 'Non-identity mapping' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Id = 1
    } | Select-PSFObject -Property 'Id as Identifier'
    $objResult
}
'@

Assert-IdentityProjection 'Mixed identity and rename' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Id   = 1
        Name = 'fixture'
    } | Select-PSFObject -Property 'Id as Id', 'Name as DisplayName'
    $objResult
}
'@

Assert-IdentityProjection 'Non-literal input' @'
function Get-Fixture {
    $objResult = $colSource | Select-PSFObject -Property 'Id as Id', 'Name as Name'
    $objResult
}
'@

Assert-IdentityProjection 'Ordered input is not a pscustomobject literal' @'
function Get-Fixture {
    $objResult = [ordered]@{
        Id = 1
    } | Select-PSFObject -Property 'Id as Id'
    $objResult
}
'@

Assert-IdentityProjection 'Case-sensitive key comparison' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Id = 1
    } | Select-PSFObject -Property 'id as id'
    $objResult
}
'@

Assert-IdentityProjection 'Non-string key is ignored' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        1 = 'one'
    } | Select-PSFObject -Property 'Id as Id'
    $objResult
}
'@

Assert-IdentityProjection 'Calculated property argument is ignored' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Id = 1
    } | Select-PSFObject -Property @{ Name = 'Id'; Expression = { $_.Id } }
    $objResult
}
'@

Assert-IdentityProjection 'Two-step select on the same variable' @'
function Get-Fixture {
    $resColRaw = $colSource | Select-PSFObject -Property 'id as appId'
    $resCol = $resColRaw | Select-PSFObject -TypeName 'D365Bap.Tools.Fixture' -Property 'appId as AppId'
    $resCol
}
'@ -Expected 1 @('already selected')

Assert-IdentityProjection 'Two-step select with continuation and excludes' @'
function Get-Fixture {
    $resColRaw = $resAdminApps | Select-PSFObject `
        -ExcludeProperty "@odata.etag", "applicationId" `
        -Property "applicationId as appId"

    $resCol = $resColRaw | Select-PSFObject -TypeName "D365Bap.Tools.PpacAdminManagementApplication" `
        -ExcludeProperty "@odata.etag", "appId" `
        -Property "id as ServicePrincipalId",
    "displayName as ServicePrincipalName",
    "appId as AppId",
    *
    $resCol
}
'@ -Expected 1 @('already selected')

Assert-IdentityProjection 'Self-projecting select' @'
function Get-Fixture {
    $resCol = @(Get-Thing)
    $resCol = @($resCol | Select-PSFObject -TypeName 'D365Bap.Tools.Fixture' -Property 'Id as Id')
    $resCol
}
'@ -Expected 1 @('already selected')

Assert-IdentityProjection 'Independent selects on different variables' @'
function Get-Fixture {
    $resColRaw = $colSource | Select-PSFObject -Property 'id as appId'
    $resCol = $otherSource | Select-PSFObject -TypeName 'D365Bap.Tools.Fixture'
    $resCol
}
'@

Assert-IdentityProjection 'Internal module code is checked' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Id = 1
    } | Select-PSFObject -Property 'Id as Id'
    $objResult
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-IdentityProjection 'Build scripts are exempt' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Id = 1
    } | Select-PSFObject -Property 'Id as Id'
    $objResult
}
'@ -Directory 'build'

Assert-IdentityProjection 'Tepp fixtures are exempt' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Id = 1
    } | Select-PSFObject -Property 'Id as Id'
    $objResult
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-IdentityProjection 'Test files are exempt' @'
function Get-Fixture {
    $objResult = [pscustomobject]@{
        Id = 1
    } | Select-PSFObject -Property 'Id as Id'
    $objResult
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Redundant identity projection rule checks passed: $script:caseCount cases."
