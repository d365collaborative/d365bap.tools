[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) ('ps1-lint-batch-' + [guid]::NewGuid().ToString('N'))
$runner = Join-Path $PSScriptRoot 'ps1-lint/lint/Run.ps1'
$formatSettings = Join-Path $PSScriptRoot 'ps1-lint/internal/Ps1FormatSettings.psd1'
$pwsh = (Get-Process -Id $PID).Path
# The analysis result cache is a local-run optimization. Point it at the
# fixture folder so this suite never writes into the repository checkout.
$previousCache = $env:PS1_LINT_CACHE
$env:PS1_LINT_CACHE = Join-Path $root 'analysis-cache'

function Assert-True([bool] $Condition, [string] $Message) {
	if (-not $Condition) { throw $Message }
}

function Write-Fixture {
	param(
		[string] $RelativePath,
		[string] $Content,
		[switch] $Bom
	)

	$path = Join-Path $root $RelativePath
	$parent = Split-Path $path -Parent
	if (-not (Test-Path -LiteralPath $parent)) {
		New-Item -ItemType Directory -Path $parent -Force > $null
	}

	[IO.File]::WriteAllText($path, $Content.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new([bool] $Bom))
	$path
}

function Get-FixtureHash([string] $Path) {
	(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Invoke-LintRunner {
	param(
		[string[]] $Path,
		[switch] $CheckOnly,
		[int] $BatchSize = 0
	)

	$colArguments = @('-NoProfile', '-NonInteractive', '-File', $runner)
	if ($CheckOnly) { $colArguments += '-CheckOnly' }
	if ($BatchSize -gt 0) { $colArguments += @('-BatchSize', "$BatchSize") }
	$colArguments += @($Path)

	$output = @(& $pwsh @colArguments 2>&1 | ForEach-Object { "$_" }) -join "`n"
	[pscustomobject]@{
		ExitCode = $LASTEXITCODE
		Output   = $output
	}
}

try {
	New-Item -ItemType Directory -Path $root -Force > $null

	# Write mode reformats, then a second run is a no-op. One process does both
	# the write and the analysis.
	$unformattedSource = @'
$objValue=1
Write-Output $objValue
'@
	$unformatted = Write-Fixture 'build/Run-Unformatted.ps1' $unformattedSource
	$run = Invoke-LintRunner -Path $unformatted
	Assert-True ($run.ExitCode -eq 1) "An unformatted file must fail the lint hook: $($run.Output)"
	Assert-True ($run.Output -match 'formatted:') 'The hook must report the rewritten file.'
	$formattedText = Get-Content -LiteralPath $unformatted -Raw
	Assert-True ($formattedText -match '\$objValue = 1') 'The hook must apply the formatter settings.'
	$bytes = [IO.File]::ReadAllBytes($unformatted)
	Assert-True ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) 'The hook must add the UTF-8 BOM.'
	$firstHash = Get-FixtureHash $unformatted

	$run = Invoke-LintRunner -Path $unformatted
	Assert-True ($run.ExitCode -eq 0) "Formatting must be idempotent: $($run.Output)"
	Assert-True ((Get-FixtureHash $unformatted) -eq $firstHash) 'A second run must not change the formatted file.'

	# Check-only reports the same drift without writing. It stays report-only
	# on every run, and the environmental switch selects the same mode.
	$checkSource = @'
$objValue=2
Write-Output $objValue
'@
	$checkFile = Write-Fixture 'build/Run-CheckOnly.ps1' $checkSource
	$checkHash = Get-FixtureHash $checkFile
	$run = Invoke-LintRunner -Path $checkFile -CheckOnly
	Assert-True ($run.ExitCode -eq 1) "Check-only must fail on formatting drift: $($run.Output)"
	Assert-True ($run.Output -match 'need formatting') 'Check-only must explain that a file was not written.'
	Assert-True ((Get-FixtureHash $checkFile) -eq $checkHash) 'Check-only must leave the file unchanged.'
	Assert-True ((Get-Content -LiteralPath $checkFile -Raw) -match '\$objValue=2') 'Check-only must keep the original text.'

	$run = Invoke-LintRunner -Path $checkFile -CheckOnly
	Assert-True ($run.ExitCode -eq 1) 'Check-only must keep failing until the file is formatted.'
	Assert-True ((Get-FixtureHash $checkFile) -eq $checkHash) 'Check-only must be idempotent.'

	$envFile = Write-Fixture 'build/Run-EnvCheckOnly.ps1' $checkSource
	$envHash = Get-FixtureHash $envFile
	$previousCheckOnly = $env:PS1_LINT_CHECK_ONLY
	try {
		$env:PS1_LINT_CHECK_ONLY = '1'
		$run = Invoke-LintRunner -Path $envFile
	}
	finally {
		$env:PS1_LINT_CHECK_ONLY = $previousCheckOnly
	}
	Assert-True ($run.ExitCode -eq 1) 'PS1_LINT_CHECK_ONLY must select check-only mode.'
	Assert-True ((Get-FixtureHash $envFile) -eq $envHash) 'The environment switch must never write.'

	# An analysis-only failure keeps the old analyzer contract.
	$analysisSource = @'
$objValue = 1
Out-Null -InputObject $objValue
'@
	$analysisFile = Write-Fixture 'build/ps1-lint/probe/Run-Analysis.ps1' $analysisSource -Bom
	$analysisHash = Get-FixtureHash $analysisFile
	$run = Invoke-LintRunner -Path $analysisFile
	Assert-True ($run.ExitCode -eq 1) "A fatal diagnostic must fail the lint hook: $($run.Output)"
	Assert-True ($run.Output -match 'PSAvoidOutNull') 'The hook must report the analysis diagnostic.'
	Assert-True ((Get-FixtureHash $analysisFile) -eq $analysisHash) 'A formatted file must not be rewritten.'

	# A read-only file fails formatting, but the rest of the batch still runs.
	$readOnly = Write-Fixture 'build/Run-ReadOnly.ps1' $unformattedSource
	$readOnlyHash = Get-FixtureHash $readOnly
	(Get-Item -LiteralPath $readOnly).IsReadOnly = $true
	try {
		$fatalFile = Write-Fixture 'build/ps1-lint/probe/Run-Fatal.ps1' $analysisSource -Bom
		$cleanFile = Write-Fixture 'build/Run-Clean.ps1' "Write-Output 'clean'`n" -Bom
		$run = Invoke-LintRunner -Path @($readOnly, $fatalFile, $cleanFile)
	}
	finally {
		(Get-Item -LiteralPath $readOnly).IsReadOnly = $false
	}
	Assert-True ($run.ExitCode -eq 1) 'A formatting failure must fail the run.'
	Assert-True ($run.Output -match 'formatting failed') 'The hook must report the formatting failure.'
	Assert-True ($run.Output -match 'PSAvoidOutNull') 'A formatting failure must not stop later files from being analyzed.'
	Assert-True ((Get-FixtureHash $readOnly) -eq $readOnlyHash) 'A failed write must leave the read-only file unchanged.'

	# Small chunks still visit every file, so -BatchSize bounds memory without
	# dropping work.
	$colMany = @(
		Write-Fixture 'build/Run-Many1.ps1' "Write-Output 'one'`n" -Bom
		Write-Fixture 'build/Run-Many2.ps1' "Write-Output 'two'`n" -Bom
		Write-Fixture 'build/ps1-lint/probe/Run-Many3.ps1' $analysisSource -Bom
	)
	$run = Invoke-LintRunner -Path $colMany -BatchSize 1
	Assert-True ($run.ExitCode -eq 1) "The last chunk must still be analyzed: $($run.Output)"
	Assert-True ($run.Output -match 'PSAvoidOutNull') 'A later chunk must report its diagnostic.'

	# The analyzer receives the formatted text. The complex array rule reports a
	# column that the formatter changes, so the batch result proves which text
	# was analyzed. The batch runs check-only, so the disk file keeps the
	# original column.
	. (Join-Path $PSScriptRoot 'ps1-lint/internal/Invoke-Ps1LintBatch.ps1')
	$contentSource = @'
function Get-Fixture {
	param()

	$colPolicies = @($colPolicies|Sort-Object -Property @{ Expression = { -not $_.IsEffective } },@{ Expression = { $_.name } })
}
'@
	$contentFile = Write-Fixture 'd365bap.tools/functions/Get-Fixture.ps1' $contentSource
	$contentHash = Get-FixtureHash $contentFile
	$batchResult = Invoke-Ps1LintBatch -Path @($contentFile) -CheckOnly
	Assert-True ((Get-FixtureHash $contentFile) -eq $contentHash) 'The batch check-only run must not write the fixture.'

	$objContent = Get-Ps1FormattedContent -Path $contentFile -SettingsPath $formatSettings
	$analyzer = New-Ps1Analyzer
	$formattedResult = Invoke-Ps1Analysis -Path $contentFile -Analyzer $analyzer -ContentByPath @{ $contentFile = $objContent.Content }
	$originalResult = Invoke-Ps1Analysis -Path $contentFile -Analyzer $analyzer -ContentByPath @{ $contentFile = $contentSource }

	$formattedRule = @($formattedResult.Diagnostics | Where-Object RuleName -eq 'PSUseOneComplexArrayElementPerLine')
	$originalRule = @($originalResult.Diagnostics | Where-Object RuleName -eq 'PSUseOneComplexArrayElementPerLine')
	$batchRule = @($batchResult.Diagnostics | Where-Object RuleName -eq 'PSUseOneComplexArrayElementPerLine')
	Assert-True ($formattedRule.Count -eq 1 -and $originalRule.Count -eq 1) 'The complex array fixture must report one diagnostic in both texts.'
	Assert-True ($formattedRule[0].Column -ne $originalRule[0].Column) 'The formatter must move the diagnostic column for this fixture.'
	Assert-True ($batchRule.Count -eq 1 -and $batchRule[0].Column -eq $formattedRule[0].Column) 'The batch must analyze the formatted text, not the pre-format text.'

	# Built-in and repository diagnostics keep the same rule set and positions
	# when the analyzer reads text instead of a path.
	$paritySource = @'
function Get-Parity {
	param([string] $Name)

	Write-Host $Name
}
'@
	$parityFile = Write-Fixture 'd365bap.tools/functions/Get-Parity.ps1' $paritySource -Bom
	$parityBatch = Invoke-Ps1LintBatch -Path @($parityFile) -CheckOnly
	$parityPath = Invoke-Ps1Analysis -Path $parityFile -Analyzer (New-Ps1Analyzer)
	$batchKeys = @($parityBatch.Diagnostics | ForEach-Object { "$($_.RuleName)|$($_.Line)" } | Sort-Object)
	$pathKeys = @($parityPath.Diagnostics | ForEach-Object { "$($_.RuleName)|$($_.Line)" } | Sort-Object)
	Assert-True (($batchKeys -join ';') -ceq ($pathKeys -join ';')) "Text and path analysis must report the same diagnostics: [$($batchKeys -join ', ')] vs [$($pathKeys -join ', ')]."

	# prek and CI must keep the combined entry point and the write-free CI mode.
	$prekText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../prek.toml') -Raw
	Assert-True ($prekText -match 'id = "ps1-lint"') 'prek.toml must define the combined ps1-lint hook.'
	Assert-True ($prekText -match 'build/ps1-lint/lint/Run\.ps1') 'The combined hook must call lint/Run.ps1.'
	Assert-True ($prekText -match 'pass_filenames = 128') 'The combined hook must keep bounded batches.'
	$ciText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../.github/workflows/validate.yml') -Raw
	Assert-True ($ciText -match 'PS1_LINT_CHECK_ONLY') 'CI must select check-only mode.'
	Assert-True ($ciText -match 'prek run ps1-lint') 'CI must run the combined hook.'

	Write-Host 'Lint batch regression checks passed.'
}
finally {
	$env:PS1_LINT_CACHE = $previousCache
	if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
