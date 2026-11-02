function Get-Ps1CommentDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'Documentation')) { return }

	foreach ($itemComment in $Analysis.CommentGroups) {
		if ($itemComment.IsHelp) { continue }
		if ($itemComment.Text -match '^#\s*(?:end)?region\b') { continue }

		New-Ps1Diagnostic $Path 'PSOnlyCommentBasedHelp' 'Only comment-based help and #region markers are allowed. Remove this comment or move its documentation into help.' $null $itemComment.Line $itemComment.Column
	}
}
