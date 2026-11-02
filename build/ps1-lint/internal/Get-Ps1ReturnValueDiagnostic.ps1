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

function Get-Ps1ReturnValueDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'RepositoryScript')) { return }

	foreach ($itemReturn in @(Get-Ps1AstNode $Analysis ReturnStatementAst)) {
		if ($null -eq $itemReturn.Pipeline) { continue }
		if (Test-Ps1ReturnValueClassMember -Node $itemReturn) { continue }

		$message = if ($itemReturn.Pipeline.Extent.Text.Trim() -eq '$null') {
			'Do not use return with a value. A bare return stops execution without emitting $null; emit $null explicitly when it is intended output.'
		}
		else {
			'Do not use return with a value. Emit the value as output; use a bare return only to stop execution.'
		}

		New-Ps1Diagnostic $Path 'PSAvoidReturnValue' $message $itemReturn.Extent
	}
}
