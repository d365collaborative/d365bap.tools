$script:Ps1EnvironmentLookupExemptions = @(
	'Get-BapEnvironment.ps1'
	'Get-UnifiedEnvironment.ps1'
	'Get-Environment.ps1'
)

function Get-Ps1EnvironmentLookupDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }

	$fileName = [IO.Path]::GetFileName($Path)
	if ($fileName -like '*Tests.ps1') { return }
	if ($fileName -in $script:Ps1EnvironmentLookupExemptions) { return }

	foreach ($command in $Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)) {
		$commandName = $command.GetCommandName()
		if ($null -eq $commandName) { continue }

		$commandName = ($commandName -split '\\')[-1]

		$message = switch ($commandName) {
			'Get-BapEnvironment' {
				'Use Get-Environment instead of Get-BapEnvironment; the default shape needs no extra calls.'
			}
			'Get-UnifiedEnvironment' {
				$skipVersion = @($command.CommandElements | Where-Object {
						$_ -is [Management.Automation.Language.CommandParameterAst] -and
						'SkipVersionDetails'.StartsWith($_.ParameterName, [StringComparison]::OrdinalIgnoreCase)
					}).Count -gt 0

				if ($skipVersion) {
					'Use Get-Environment -Unified instead of Get-UnifiedEnvironment -SkipVersionDetails.'
				}
				else {
					'Use Get-Environment -Unified -VersionDetails instead of Get-UnifiedEnvironment; only callers that need provisioning data should pay for it.'
				}
			}
			default { $null }
		}

		if ($null -eq $message) { continue }

		[pscustomobject]@{
			RuleName   = 'PSUseCentralEnvironmentLookup'
			Severity   = 'Error'
			ScriptName = $fileName
			Line       = $command.Extent.StartLineNumber
			Column     = $command.Extent.StartColumnNumber
			Message    = $message
		}
	}
}
