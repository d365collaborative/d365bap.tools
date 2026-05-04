$scbRestTraverse = {
    $values = "ServiceGroup", "Service", "Operation", "Detail"

    # Generate completion results
    foreach ($item in $values) {
        New-PSFTeppCompletionResult -CompletionText $item -ToolTip $item
    }
}

Register-PSFTeppScriptblock `
    -Name "d365bap.tools.tepp.fscm.rest.service.traverse" `
    -ScriptBlock $scbRestTraverse `
    -Mode Full