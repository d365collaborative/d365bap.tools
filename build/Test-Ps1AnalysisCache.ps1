# Regression checks for the local analysis result cache. A fixture module
# proves reuse on an unchanged file, invalidation by a file edit, a settings
# change, a pinned version change, another function's parameter change, and
# another function's output type change, a hit for a body-only edit elsewhere,
# the CI and off switches, the damaged-entry fallback, and that the lint hook
# keeps the same output when the cache is warm.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) ('ps1-analysis-cache-' + [guid]::NewGuid().ToString('N'))
$cacheRoot = Join-Path $root 'cache'
$settingsCopy = Join-Path $root 'Ps1AnalyzerSettings.psd1'
$realSettings = Join-Path $PSScriptRoot 'ps1-lint/internal/Ps1AnalyzerSettings.psd1'
$runner = Join-Path $PSScriptRoot 'ps1-lint/lint/Run.ps1'
$pwsh = (Get-Process -Id $PID).Path
$previousCache = $env:PS1_LINT_CACHE
$previousCi = $env:CI

. (Join-Path $PSScriptRoot 'ps1-lint/internal/Invoke-Ps1Analysis.ps1')

function Assert-True([bool] $Condition, [string] $Message) {
	if (-not $Condition) { throw $Message }
}

function Write-Fixture([string] $RelativePath, [string] $Content) {
	$path = Join-Path $root $RelativePath
	$parent = Split-Path $path -Parent
	if (-not (Test-Path -LiteralPath $parent)) {
		New-Item -ItemType Directory -Path $parent -Force > $null
	}

	[IO.File]::WriteAllText($path, $Content.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($true))
	$path
}

function Get-Signature($Result) {
	@($Result.Diagnostics | ForEach-Object { "$($_.RuleName)|$($_.Severity)|$($_.ScriptName)|$($_.Line)|$($_.Column)|$($_.Message)" } | Sort-Object)
}

function Invoke-Analysis {
	# One local run: a fresh analyzer (new analysis worker, so the repository
	# index sees edits) and a fresh cache session.
	param(
		[string] $Path,
		[string] $SettingsPath = $realSettings,
		[object] $Version
	)

	$analyzer = New-Ps1Analyzer -SettingsPath $SettingsPath
	if ($null -ne $Version) { $analyzer.Version = $Version }

	$session = New-Ps1AnalysisCacheSession -Analyzer $analyzer -RepositoryRoot $root
	$result = Invoke-Ps1Analysis -Path $Path -Analyzer $analyzer -AnalysisCache $session
	[pscustomobject]@{
		Result = $result
		Hits   = [int] $session.Hits
		Misses = [int] $session.Misses
	}
}

function Get-CacheEntryCount {
	@(Get-ChildItem -LiteralPath $cacheRoot -Recurse -File -Filter '*.json' |
		Where-Object Name -ne 'state.json').Count
}

try {
	New-Item -ItemType Directory -Path $cacheRoot -Force > $null
	$env:PS1_LINT_CACHE = $cacheRoot
	$env:CI = ''

	$onePath = Write-Fixture 'd365bap.tools/functions/Get-FixtureOne.ps1' @'
function Get-FixtureOne {
	[OutputType([PSCustomObject])]
	param()

	$objItem = Get-FixtureTwo -Env 'demo'
	$objItem
}
'@
	$twoPath = Write-Fixture 'd365bap.tools/functions/Get-FixtureTwo.ps1' @'
function Get-FixtureTwo {
	[OutputType([PSCustomObject])]
	param(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId
	)

	[pscustomobject][ordered]@{
		EnvironmentId = $EnvironmentId
	}
}
'@

	# 1. A cold run computes both entries and reports what it stored.
	$cold = Invoke-Analysis -Path $onePath
	$baseline = Get-Signature $cold.Result
	Assert-True ($cold.Misses -eq 2 -and $cold.Hits -eq 0) "A cold run must compute both entries, got $($cold.Hits) hit(s) and $($cold.Misses) miss(es)."
	Assert-True ($baseline.Count -gt 0) 'The fixture must report at least one diagnostic.'
	Assert-True (@($cold.Result.Diagnostics | Where-Object RuleName -eq 'PSAvoidParameterAliases').Count -eq 1) "The abbreviated parameter must be reported: $($baseline -join '; ')"
	Assert-True ((Get-CacheEntryCount) -eq 2) "A cold run must write two entries, found $(Get-CacheEntryCount)."
	Write-Output 'PASS: cold run stores built-in and custom entries'

	# 2. An unchanged file reuses both entries and reproduces the result.
	$warm = Invoke-Analysis -Path $onePath
	Assert-True ($warm.Hits -eq 2 -and $warm.Misses -eq 0) "An unchanged file must reuse both entries, got $($warm.Hits) hit(s) and $($warm.Misses) miss(es)."
	Assert-True ((Get-Signature $warm.Result) -ceq $baseline) 'A warm run must report the same diagnostics.'
	Write-Output 'PASS: unchanged file reuses the cached result'

	# 3. A file edit invalidates both entries.
	$onePath = Write-Fixture 'd365bap.tools/functions/Get-FixtureOne.ps1' @'
function Get-FixtureOne {
	[OutputType([PSCustomObject])]
	param()

	$objItem = Get-FixtureTwo -Env 'demo-two'
	$objItem
}
'@
	$edited = Invoke-Analysis -Path $onePath
	Assert-True ($edited.Misses -eq 2) "A file edit must invalidate both entries, got $($edited.Misses) miss(es)."
	Assert-True ((Get-Signature $edited.Result) -ceq $baseline) 'The edited file must report the same diagnostics.'
	Write-Output 'PASS: a file edit invalidates the entries'

	# 4. Another file's body-only edit keeps the custom entry a hit, because
	# the repository metadata that the rules read did not change.
	$twoPath = Write-Fixture 'd365bap.tools/functions/Get-FixtureTwo.ps1' @'
function Get-FixtureTwo {
	[OutputType([PSCustomObject])]
	param(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId
	)

	[pscustomobject][ordered]@{
		EnvironmentId = $EnvironmentId
		DisplayName   = $EnvironmentId.ToUpperInvariant()
	}
}
'@
	$bodyEdit = Invoke-Analysis -Path $onePath
	Assert-True ($bodyEdit.Hits -eq 2 -and $bodyEdit.Misses -eq 0) "A body-only edit elsewhere must stay a hit, got $($bodyEdit.Hits) hit(s) and $($bodyEdit.Misses) miss(es)."
	Assert-True ((Get-Signature $bodyEdit.Result) -ceq $baseline) 'A body-only edit elsewhere must not change the result.'
	Write-Output 'PASS: a body-only edit elsewhere stays a hit'

	# 5. Another function's parameter change invalidates the custom entry, and
	# the call site stops matching an abbreviation.
	$twoPath = Write-Fixture 'd365bap.tools/functions/Get-FixtureTwo.ps1' @'
function Get-FixtureTwo {
	[OutputType([PSCustomObject])]
	param(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $TargetId
	)

	[pscustomobject][ordered]@{
		TargetId = $TargetId
	}
}
'@
	$parameterEdit = Invoke-Analysis -Path $onePath
	Assert-True ($parameterEdit.Misses -eq 1 -and $parameterEdit.Hits -eq 1) "A parameter change elsewhere must invalidate only the custom entry, got $($parameterEdit.Hits) hit(s) and $($parameterEdit.Misses) miss(es)."
	Assert-True (@($parameterEdit.Result.Diagnostics | Where-Object RuleName -eq 'PSAvoidParameterAliases').Count -eq 0) 'The renamed parameter must stop reporting the -Env abbreviation.'
	Write-Output 'PASS: another function''s parameter change invalidates the custom entry'

	# 6. Another function's output type change invalidates the custom entry and
	# changes the variable-naming requirement.
	$twoPath = Write-Fixture 'd365bap.tools/functions/Get-FixtureTwo.ps1' @'
function Get-FixtureTwo {
	[OutputType('System.Object[]')]
	param(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $TargetId
	)

	[pscustomobject][ordered]@{
		TargetId = $TargetId
	}
}
'@
	$outputEdit = Invoke-Analysis -Path $onePath
	$outputSignature = Get-Signature $outputEdit.Result
	Assert-True ($outputEdit.Misses -eq 1 -and $outputEdit.Hits -eq 1) "An output type change elsewhere must invalidate only the custom entry, got $($outputEdit.Hits) hit(s) and $($outputEdit.Misses) miss(es)."
	$namingDiagnostic = @($outputEdit.Result.Diagnostics | Where-Object RuleName -eq 'PSUseVariableNamingConvention')
	Assert-True ($namingDiagnostic.Count -eq 1 -and $namingDiagnostic[0].Message -match 'collection') "The collection output type must require the col prefix: $(@($namingDiagnostic.Message) -join '; ')"
	Write-Output 'PASS: another function''s output type change invalidates the custom entry'

	# 7. A settings change invalidates every entry.
	$settingsText = [IO.File]::ReadAllText($realSettings)
	$settingsText = $settingsText -replace '(?m)^\s*ExcludeRule\s*=\s*@\(', "ExcludeRule = @(`n`t`t'PSUseSingularNouns'"
	[IO.File]::WriteAllText($settingsCopy, $settingsText, [Text.UTF8Encoding]::new($false))
	$settingsRun = Invoke-Analysis -Path $onePath -SettingsPath $settingsCopy
	Assert-True ($settingsRun.Misses -eq 2) "A settings change must invalidate every entry, got $($settingsRun.Misses) miss(es)."
	Assert-True ((Get-Signature $settingsRun.Result) -ceq $outputSignature) 'The extra excluded rule must not change these fixtures.'
	Write-Output 'PASS: a settings change invalidates the entries'

	# 8. A pinned analyzer version change invalidates every entry.
	$versionRun = Invoke-Analysis -Path $onePath -Version ([version]'99.0.0')
	Assert-True ($versionRun.Misses -eq 2) "A pinned version change must invalidate every entry, got $($versionRun.Misses) miss(es)."
	Assert-True ((Get-Signature $versionRun.Result) -ceq $outputSignature) 'The version change must not change the result of the same analyzer.'
	$versionWarm = Invoke-Analysis -Path $onePath -Version ([version]'99.0.0')
	Assert-True ($versionWarm.Hits -eq 2) 'The new version must cache its own entries.'
	Write-Output 'PASS: a pinned version change invalidates the entries'

	# 9. A damaged entry falls back to the uncached path instead of reporting
	# a partial or wrong result. Its own folder keeps the damage away from the
	# entries the later hook runs use.
	$damageRoot = Join-Path $root 'damaged-cache'
	$env:PS1_LINT_CACHE = $damageRoot
	$null = Invoke-Analysis -Path $onePath
	$damagedEntries = @(Get-ChildItem -LiteralPath $damageRoot -Recurse -File -Filter '*.json' |
		Where-Object Name -ne 'state.json')
	Assert-True ($damagedEntries.Count -eq 2) "The damaged scenario must write two entries, found $($damagedEntries.Count)."
	foreach ($itemEntry in $damagedEntries) {
		Set-Content -LiteralPath $itemEntry.FullName -Value '{ not json' -Encoding utf8
	}
	$damaged = Invoke-Analysis -Path $onePath
	Assert-True ($damaged.Result.Diagnostics.Count -gt 0) 'A damaged entry must still produce a result.'
	Assert-True ((Get-Signature $damaged.Result) -ceq $outputSignature) 'A damaged entry must not change the result.'
	$env:PS1_LINT_CACHE = $cacheRoot
	Remove-Item -LiteralPath $damageRoot -Recurse -Force
	Write-Output 'PASS: a damaged entry falls back to the uncached path'

	# 10. The cache stays off in CI and when the switch says off.
	$env:PS1_LINT_CACHE = $null
	$env:CI = 'true'
	try {
		$ciAnalyzer = New-Ps1Analyzer -SettingsPath $realSettings
		$ciSession = New-Ps1AnalysisCacheSession -Analyzer $ciAnalyzer -RepositoryRoot $root
	}
	finally {
		$env:CI = ''
	}
	Assert-True ($null -eq $ciSession) 'CI must keep the uncached path.'
	$env:PS1_LINT_CACHE = 'off'
	$offAnalyzer = New-Ps1Analyzer -SettingsPath $realSettings
	$offSession = New-Ps1AnalysisCacheSession -Analyzer $offAnalyzer -RepositoryRoot $root
	Assert-True ($null -eq $offSession) 'PS1_LINT_CACHE=off must keep the uncached path.'
	$env:PS1_LINT_CACHE = $cacheRoot
	Write-Output 'PASS: CI and the off switch keep the uncached path'

	# 11. The default folder sits at the repository root that owns this file,
	# without an environment override.
	$env:PS1_LINT_CACHE = $null
	$defaultRoot = Get-Ps1AnalysisCacheRoot -RepositoryRoot ''
	$expectedRoot = Join-Path (Split-Path $PSScriptRoot -Parent) '.ps1-lint-cache'
	Assert-True ($defaultRoot -eq $expectedRoot) "The default folder must be the repository cache, got '$defaultRoot' instead of '$expectedRoot'."
	$env:PS1_LINT_CACHE = $cacheRoot
	Write-Output 'PASS: the default folder sits at the repository root'

	# 12. The lint hook produces the same output with a warm cache and reports
	# the reuse, so the local behavior is visible without changing the result.
	$hookFiles = @($onePath, $twoPath)
	$coldHook = @(& $pwsh -NoProfile -NonInteractive -File $runner -CheckOnly @hookFiles 2>&1 | ForEach-Object { "$_" })
	$coldExit = $LASTEXITCODE
	$warmHook = @(& $pwsh -NoProfile -NonInteractive -File $runner -CheckOnly @hookFiles 2>&1 | ForEach-Object { "$_" })
	$warmExit = $LASTEXITCODE
	Assert-True ($coldExit -eq $warmExit) "A warm cache must keep the hook exit code, got $coldExit and $warmExit."
	Assert-True (@($warmHook | Where-Object { $_ -match 'analysis cache: reused (\d+) of \1 result\(s\) \(100%\)' }).Count -eq 1) "A warm hook run must report full reuse: $($warmHook -join ' | ')"
	$coldBody = @($coldHook | Where-Object { $_ -notmatch 'analysis cache:' })
	$warmBody = @($warmHook | Where-Object { $_ -notmatch 'analysis cache:' })
	Assert-True (($coldBody -join "`n") -ceq ($warmBody -join "`n")) 'A warm hook run must print the same diagnostics.'
	Write-Output 'PASS: the lint hook reuses the cache without changing output'

	# 12. A parse failure is stored and reproduced as the parse-only result.
	$brokenPath = Write-Fixture 'd365bap.tools/functions/Get-FixtureBroken.ps1' @'
function Get-FixtureBroken {
	param(
}
'@
	$brokenCold = Invoke-Analysis -Path $brokenPath
	Assert-True ($brokenCold.Misses -eq 2) "A parse failure must compute both entries, got $($brokenCold.Misses) miss(es)."
	Assert-True ($brokenCold.Result.Failed) 'A parse failure must fail the file.'
	$brokenSignature = Get-Signature $brokenCold.Result
	Assert-True (@($brokenSignature | Where-Object { $_ -match '^PSParseError\|' }).Count -gt 0) "A parse failure must report PSParseError: $($brokenSignature -join '; ')"
	$brokenWarm = Invoke-Analysis -Path $brokenPath
	Assert-True ($brokenWarm.Hits -eq 2) "A cached parse failure must be reused, got $($brokenWarm.Hits) hit(s) and $($brokenWarm.Misses) miss(es)."
	Assert-True ($brokenWarm.Result.Failed) 'A cached parse failure must still fail the file.'
	Assert-True ((Get-Signature $brokenWarm.Result) -ceq $brokenSignature) 'A cached parse failure must report the same diagnostics only.'
	Remove-Item -LiteralPath $brokenPath -Force
	Write-Output 'PASS: a parse failure is cached and reproduced'

	# 13. The folder resets once the recorded write count passes the budget
	# instead of growing without bound.
	$budgetRoot = Join-Path $root 'budget-cache'
	$env:PS1_LINT_CACHE = $budgetRoot
	$budgetAnalyzer = New-Ps1Analyzer -SettingsPath $realSettings
	$budgetSession = New-Ps1AnalysisCacheSession -Analyzer $budgetAnalyzer -WriteBudget 1
	$null = Invoke-Ps1Analysis -Path $onePath -Analyzer $budgetAnalyzer -AnalysisCache $budgetSession
	Complete-Ps1AnalysisCacheSession -Session $budgetSession > $null
	$budgetSession = New-Ps1AnalysisCacheSession -Analyzer $budgetAnalyzer -WriteBudget 1
	Assert-True ($budgetSession.ResetCount) 'A passed write budget must reset the cache folder.'
	$remaining = @(Get-ChildItem -LiteralPath $budgetRoot -Recurse -File -Filter '*.json' |
		Where-Object Name -ne 'state.json').Count
	Assert-True ($remaining -eq 0) "A reset must remove the entries, found $remaining."
	$env:PS1_LINT_CACHE = $cacheRoot
	Remove-Item -LiteralPath $budgetRoot -Recurse -Force
	Write-Output 'PASS: the write budget resets the cache folder'

	# 14. The key covers every input that can change a result.
	$keyAnalyzer = New-Ps1Analyzer -SettingsPath $realSettings
	$keySession = New-Ps1AnalysisCacheSession -Analyzer $keyAnalyzer -RepositoryRoot $root
	$baseKey = Get-Ps1AnalysisCacheKey -Session $keySession `
		-Kind builtin `
		-Path $onePath `
		-TextHash 'aaa'
	$otherKeys = @(
		(Get-Ps1AnalysisCacheKey -Session $keySession -Kind builtin -Path $onePath -TextHash 'bbb')
		(Get-Ps1AnalysisCacheKey -Session $keySession -Kind builtin -Path $twoPath -TextHash 'aaa')
		(Get-Ps1AnalysisCacheKey -Session $keySession -Kind custom -Path $onePath -TextHash 'aaa')
		(Get-Ps1AnalysisCacheKey -Session $keySession -Kind custom -Path $onePath -TextHash 'aaa' -Fingerprint 'other')
	)
	foreach ($itemKey in $otherKeys) {
		Assert-True ($itemKey -ne $baseKey) 'Every key input must change the key.'
	}
	$sameKey = Get-Ps1AnalysisCacheKey -Session $keySession `
		-Kind builtin `
		-Path $onePath `
		-TextHash 'aaa'
	Assert-True ($sameKey -ceq $baseKey) 'The same inputs must produce the same key.'
	Write-Output 'PASS: the key covers text, path, kind, and fingerprint'

	# 15. Cache artifacts stay out of git.
	$gitIgnore = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../.gitignore') -Raw
	Assert-True ($gitIgnore -match '\.ps1-lint-cache/') '.gitignore must keep the cache folder out of git.'
	Write-Output 'PASS: the cache folder stays out of git'

	Write-Output 'Analysis cache regression checks passed.'
}
finally {
	$env:PS1_LINT_CACHE = $previousCache
	$env:CI = $previousCi
	if (Test-Path -LiteralPath $root) {
		$resolved = (Resolve-Path -LiteralPath $root).Path
		$tempParent = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
		if (-not $resolved.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase) -or
			[IO.Path]::GetFileName($resolved) -notmatch '^ps1-analysis-cache-[0-9a-f]{32}$') {
			throw 'Unexpected fixture cleanup path.'
		}
		Remove-Item -LiteralPath $resolved -Recurse -Force
	}
}
