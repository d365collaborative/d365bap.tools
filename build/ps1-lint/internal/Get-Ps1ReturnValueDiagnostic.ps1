function Test-Ps1ReturnValueClassMember {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) {
			if ($parent.Parent -is [Management.Automation.Language.FunctionMemberAst]) { $true; return }
			return
		}
		if ($parent -is [Management.Automation.Language.FunctionMemberAst]) { $true; return }
		$parent = $parent.Parent
	}

	$false
}

function New-Ps1ReturnValueDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSAvoidReturnValue'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1ReturnValueDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	$isModuleFile = $normalized -match '/d365bap\.tools/'
	$isBuildFile = $normalized -match '/build/'
	if (-not $isModuleFile -and -not $isBuildFile) { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/tests/') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemReturn in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.ReturnStatementAst] }, $true)) {
		if ($null -eq $itemReturn.Pipeline) { continue }
		if (Test-Ps1ReturnValueClassMember -Node $itemReturn) { continue }

		$message = if ($itemReturn.Pipeline.Extent.Text.Trim() -eq '$null') {
			'Do not use return with a value. Use a bare return to stop execution.'
		}
		else {
			'Do not use return with a value. Emit the value as output; use a bare return only to stop execution.'
		}

		New-Ps1ReturnValueDiagnostic -Path $Path -Message $message -Extent $itemReturn.Extent
	}
}
