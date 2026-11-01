function Get-Ps1CommentDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	foreach ($comment in $Analysis.CommentGroups) {
		if ($comment.IsHelp) { continue }
		if ($comment.Text -match '^#\s*(?:end)?region\b') { continue }

		[pscustomobject]@{
			RuleName   = 'PSOnlyCommentBasedHelp'
			Severity   = 'Error'
			ScriptName = [IO.Path]::GetFileName($Path)
			Line       = $comment.Line
			Column     = $comment.Column
			Message    = 'Only comment-based help and #region markers are allowed. Remove this comment or move its documentation into help.'
		}
	}
}
