function Get-Ps1CommentDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$fileName = [IO.Path]::GetFileName($Path)
	if ($fileName -like '*Tests.ps1') { return }
	if ($fileName -like '*.tepp.ps1') { return }

	$normalized = $Path -replace '\\', '/'
	if ($normalized -match '/d365bap\.tools/tests/') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemComment in $Analysis.CommentGroups) {
		if ($itemComment.IsHelp) { continue }
		if ($itemComment.Text -match '^#\s*(?:end)?region\b') { continue }

		[pscustomobject]@{
			RuleName   = 'PSOnlyCommentBasedHelp'
			Severity   = 'Error'
			ScriptName = $fileName
			Line       = $itemComment.Line
			Column     = $itemComment.Column
			Message    = 'Only comment-based help and #region markers are allowed. Remove this comment or move its documentation into help.'
		}
	}
}
