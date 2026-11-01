function Get-Ps1CommentDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$fileName = [IO.Path]::GetFileName($Path)
	if ($fileName -like '*Tests.ps1') { return }
	if ($fileName -like '*.tepp.ps1') { return }

	$normalized = $Path -replace '\\', '/'
	if ($normalized -match '/d365bap\.tools/tests/') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($comment in $Analysis.CommentGroups) {
		if ($comment.IsHelp) { continue }
		if ($comment.Text -match '^#\s*(?:end)?region\b') { continue }

		[pscustomobject]@{
			RuleName   = 'PSOnlyCommentBasedHelp'
			Severity   = 'Error'
			ScriptName = $fileName
			Line       = $comment.Line
			Column     = $comment.Column
			Message    = 'Only comment-based help and #region markers are allowed. Remove this comment or move its documentation into help.'
		}
	}
}
