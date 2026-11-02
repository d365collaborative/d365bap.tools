<#
.SYNOPSIS
    Tests the direct parameter check lint rule.

.DESCRIPTION
    Parses fixture functions and checks that parameter-set branching and
    bound-parameter key checks are replaced with direct parameter checks where
    possible. Parameters whose default is also a valid explicit value are
    allowed.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($script in @('Get-Ps1CommentGroup', 'Get-Ps1HelpSection', 'Get-Ps1Analysis', 'Get-Ps1DirectParameterCheckDiagnostic')) {
	. "$PSScriptRoot/ps1-lint/internal/$script.ps1"
}
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('direct-parameter-rule-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot -Force
$script:caseCount = 0

function Assert-DirectParameter {
	param([string] $Label, [string] $Source, [int] $Expected = 0, [string[]] $ExpectedText = @(), [string] $Directory = 'd365bap.tools/functions', [string] $FileName = 'Get-Fixture.ps1')
	$folder = Join-Path $fixtureRoot $Directory
	$null = New-Item -ItemType Directory -Path $folder -Force
	$path = Join-Path $folder $FileName
	[IO.File]::WriteAllText($path, $Source.Replace("`r`n", "`n"))
	$analysis = Get-Ps1Analysis -Path $path
	$colDiagnostics = @(Get-Ps1DirectParameterCheckDiagnostic -Analysis $analysis)
	if ($colDiagnostics.Count -ne $Expected) {
		throw "${Label}: expected $Expected diagnostics, got $($colDiagnostics.Count): $($colDiagnostics.Message -join ' ')"
	}
	$message = @($colDiagnostics | ForEach-Object { "$($_.RuleName) $($_.Message)" }) -join ' '
	foreach ($itemFragment in $ExpectedText) {
		if (-not $message.Contains($itemFragment)) { throw "${Label}: missing '$itemFragment' in '$message'" }
	}
	$script:caseCount++
}

Assert-DirectParameter 'Parameter set branch' @'
function Get-Fixture {
    [CmdletBinding(DefaultParameterSetName = 'Environment')]
    param (
        [Parameter(ParameterSetName = 'Environment', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $EnvironmentId,

        [Parameter(ParameterSetName = 'EnvironmentGroup', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $EnvironmentGroupId
    )

    if ($PSCmdlet.ParameterSetName -eq 'EnvironmentGroup') {
        $EnvironmentGroupId
    }
    else {
        $EnvironmentId
    }
}
'@ -Expected 1 @('PSUseDirectParameterCheck', '-EnvironmentGroupId', 'if ($EnvironmentGroupId)')

Assert-DirectParameter 'Parameter set switch' @'
function Get-Fixture {
    [CmdletBinding(DefaultParameterSetName = 'Active')]
    param (
        [string[]] $OutputPath,

        [Parameter(ParameterSetName = 'Pipeline')]
        [string[]] $PackagesLocalDirectory
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Active' {
            $PackagesLocalDirectory = 'default'
        }
    }
}
'@ -Expected 1 @('if (-not $PackagesLocalDirectory)')

Assert-DirectParameter 'Parameter set assignment' @'
function Get-Fixture {
    [CmdletBinding(DefaultParameterSetName = 'ByBuild')]
    param (
        [Parameter(ParameterSetName = 'ByEnvironment', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $EnvironmentId
    )

    $isByEnvironment = $PSCmdlet.ParameterSetName -eq 'ByEnvironment'
    $isByEnvironment
}
'@ -Expected 1 @('$isByEnvironment = [bool] $EnvironmentId')

Assert-DirectParameter 'Redundant key check in an assignment' @'
function Get-Fixture {
    param (
        [string] $Build
    )

    $buildGiven = $PSBoundParameters.ContainsKey('Build') -and -not [string]::IsNullOrWhiteSpace($Build)
    $buildGiven
}
'@ -Expected 1 @('redundant')

Assert-DirectParameter 'Redundant key check in a condition' @'
function Get-Fixture {
    param (
        [string] $OutputPath
    )

    if ($PSBoundParameters.ContainsKey('OutputPath') -and -not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath
    }
}
'@ -Expected 1 @('redundant')

Assert-DirectParameter 'Key check for an optional string' @'
function Get-Fixture {
    param (
        [string] $Description
    )

    if ($PSBoundParameters.ContainsKey('Description')) {
        $Description
    }
}
'@ -Expected 1 @('Trust the parameter')

Assert-DirectParameter 'Key check for a version default' @'
function Get-Fixture {
    param (
        [string] $Version
    )

    $effectiveVersion = if ($PSBoundParameters.ContainsKey('Version')) { $Version } else { '1.0.0.0' }
    $effectiveVersion
}
'@ -Expected 1 @('IsNullOrWhiteSpace')

Assert-DirectParameter 'Wildcard default is allowed' @'
function Get-Fixture {
    param (
        [ValidateSet('*', 'A', 'B')]
        [SupportsWildcards()]
        [string[]] $Asset = '*'
    )

    $assetExplicit = $PSBoundParameters.ContainsKey('Asset')
    $assetExplicit
}
'@

Assert-DirectParameter 'Non-empty default is allowed' @'
function Get-Fixture {
    param (
        [string] $Language = 'en-US'
    )

    if ($PSBoundParameters.ContainsKey('Language')) {
        $Language
    }
}
'@

Assert-DirectParameter 'Bound parameter splat is allowed' @'
function Get-Fixture {
    param (
        [string] $Name
    )

    Get-Thing -BoundParameters $PSBoundParameters
}
'@

Assert-DirectParameter 'Dynamic key is allowed' @'
function Get-Fixture {
    param (
        [string] $Name
    )

    $key = 'Name'

    if ($PSBoundParameters.ContainsKey($key)) {
        $Name
    }
}
'@

Assert-DirectParameter 'Undeclared key is allowed' @'
function Get-Fixture {
    if ($PSBoundParameters.ContainsKey('Missing')) {
        'x'
    }
}
'@

Assert-DirectParameter 'Mandatory parameter' @'
function Get-Fixture {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    if ($PSBoundParameters.ContainsKey('Name')) {
        $Name
    }
}
'@ -Expected 1 @('mandatory')

Assert-DirectParameter 'Alias key resolves to the parameter' @'
function Get-Fixture {
    param (
        [Alias('DisplayName')]
        [string] $FriendlyName
    )

    if ($PSBoundParameters.ContainsKey('DisplayName')) {
        $FriendlyName
    }
}
'@ -Expected 1 @('$FriendlyName')

Assert-DirectParameter 'Internal module code is checked' @'
function Get-Fixture {
    param (
        [string] $Build
    )

    $buildGiven = $PSBoundParameters.ContainsKey('Build') -and -not [string]::IsNullOrWhiteSpace($Build)
    $buildGiven
}
'@ -Expected 1 -Directory 'd365bap.tools/internal/functions'

Assert-DirectParameter 'Build scripts are exempt' @'
function Get-Fixture {
    param (
        [string] $Build
    )

    $buildGiven = $PSBoundParameters.ContainsKey('Build') -and -not [string]::IsNullOrWhiteSpace($Build)
    $buildGiven
}
'@ -Directory 'build'

Assert-DirectParameter 'Tepp fixtures are exempt' @'
function Get-Fixture {
    param (
        [string] $Build
    )

    $buildGiven = $PSBoundParameters.ContainsKey('Build') -and -not [string]::IsNullOrWhiteSpace($Build)
    $buildGiven
}
'@ -Directory 'd365bap.tools/internal/tepp'

Assert-DirectParameter 'Test files are exempt' @'
function Get-Fixture {
    param (
        [string] $Build
    )

    $buildGiven = $PSBoundParameters.ContainsKey('Build') -and -not [string]::IsNullOrWhiteSpace($Build)
    $buildGiven
}
'@ -FileName 'Get-Fixture.Tests.ps1'

Write-Output "Direct parameter check rule checks passed: $script:caseCount cases."
