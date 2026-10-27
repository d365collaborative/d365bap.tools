[CmdletBinding()]
param(
	[Parameter(Mandatory)] [string] $BaseSha,
	[Parameter(Mandatory)] [string] $HeadSha,
	[Parameter(Mandatory)] [string] $OutputPath,
	[string] $RepositoryPath = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path -LiteralPath $RepositoryPath).Path

function Invoke-GitBytes([string[]] $Arguments) {
	$start = [System.Diagnostics.ProcessStartInfo]::new()
	$start.FileName = 'git'
	$start.WorkingDirectory = $repository
	$start.UseShellExecute = $false
	$start.RedirectStandardOutput = $true
	$start.RedirectStandardError = $true
	foreach ($argument in $Arguments) { $null = $start.ArgumentList.Add($argument) }
	$process = [System.Diagnostics.Process]::Start($start)
	try {
		$errorTask = $process.StandardError.ReadToEndAsync()
		$bytes = [System.IO.MemoryStream]::new()
		try {
			$process.StandardOutput.BaseStream.CopyTo($bytes)
			$process.WaitForExit()
			$stderr = $errorTask.GetAwaiter().GetResult()
			if ($process.ExitCode -ne 0) { throw "git failed ($($process.ExitCode)): $stderr" }
			return , $bytes.ToArray()
		}
		finally { $bytes.Dispose() }
	}
	finally { $process.Dispose() }
}

foreach ($sha in @($BaseSha, $HeadSha)) {
	if ($sha -notmatch '^[0-9a-fA-F]{40}([0-9a-fA-F]{24})?$') { throw "Invalid commit object ID: $sha" }
}
$mergeBase = [Text.Encoding]::UTF8.GetString((Invoke-GitBytes @('merge-base', $BaseSha, $HeadSha))).Trim()
if ($mergeBase -notmatch '^[0-9a-fA-F]{40}([0-9a-fA-F]{24})?$') { throw 'Could not determine a unique merge base.' }
$raw = Invoke-GitBytes @('diff', '--name-status', '-z', '--find-renames', $mergeBase, $HeadSha, '--')
$records = [Text.Encoding]::UTF8.GetString($raw).Split([char]0)
if ($records[-1] -ne '') { throw 'Git returned an unterminated diff record.' }

$entries = [System.Collections.Generic.List[object]]::new()
for ($i = 0; $i -lt $records.Length - 1; ) {
	$status = $records[$i++]
	if ($status -notmatch '^[A-Z][0-9]*$' -or $i -ge $records.Length - 1) { throw 'Malformed git diff output.' }
	$path = $records[$i++]
	$oldPath = $null
	if ($status -match '^[RC]') {
		if ($i -ge $records.Length - 1) { throw 'Malformed rename/copy record.' }
		$oldPath = $path
		$path = $records[$i++]
	}
	$entries.Add([pscustomobject]@{ Status = $status; Path = $path; OldPath = $oldPath })
}

function Test-Documentation([string] $Path) {
	if ([string]::IsNullOrEmpty($Path)) { return $false }
	if ([IO.Path]::GetFileName($Path) -ieq 'AGENTS.md') { return $false }
	return ($Path -ieq 'README.md' -or
		$Path -ieq 'd365bap.tools/readme.md' -or
		$Path -ieq 'd365bap.tools/changelog.md' -or
		$Path -match '^(docs|learning)/.+\.md$' -or
		$Path -match '^wiki/[^/]+\.md$')
}

$mode = 'docs'
$reasons = [System.Collections.Generic.List[string]]::new()
$publicPaths = [System.Collections.Generic.List[string]]::new()
if ($entries.Count -eq 0) { $mode = 'full'; $reasons.Add('No changed files were detected.') }
foreach ($entry in $entries) {
	if ((Test-Documentation $entry.Path) -and ($null -eq $entry.OldPath -or (Test-Documentation $entry.OldPath))) { continue }
	if ($entry.Status -notin @('A', 'M') -or $entry.Path -cnotmatch '^d365bap\.tools/functions/[A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9]*\.ps1$') {
		$mode = 'full'
		$reasons.Add("Shared, unknown, deleted, or renamed path: $($entry.Status) $($entry.Path)")
		continue
	}
	if (-not (Test-Path -LiteralPath (Join-Path $repository $entry.Path) -PathType Leaf)) {
		$mode = 'full'
		$reasons.Add("Missing changed source at checkout: $($entry.Path)")
		continue
	}
	if ($mode -eq 'docs') { $mode = 'selective' }
	$publicPaths.Add($entry.Path)
}
$plan = [ordered]@{
	Mode        = $mode
	PublicPaths = @($publicPaths | Sort-Object -Unique)
	Reasons     = @($reasons)
	MergeBase   = $mergeBase
	HeadSha     = $HeadSha
}
$plan | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "Validation mode: $mode ($($entries.Count) changed file(s))."
foreach ($reason in $reasons) { Write-Host "  $reason" }
