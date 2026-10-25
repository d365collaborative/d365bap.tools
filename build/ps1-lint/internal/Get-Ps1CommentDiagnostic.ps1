function Get-Ps1CommentDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	$isFragment = $normalized -match '/d365bap\.tools/(functions|internal)/' -and $normalized -notmatch '/internal/scripts/(preimport|postimport|load-formatdata)\.ps1$'
	if ($isFragment) { return }

	foreach ($comment in $Analysis.CommentGroups) {
		if ($comment.IsHelp) { continue }
		[pscustomobject]@{
			RuleName   = 'PSOnlyCommentBasedHelp'
			Severity   = 'Error'
			ScriptName = [IO.Path]::GetFileName($Path)
			Line       = $comment.Line
			Column     = $comment.Column
			Message    = 'Only comment-based help is allowed. Remove this comment or move its documentation into script or function help.'
		}
	}
}
