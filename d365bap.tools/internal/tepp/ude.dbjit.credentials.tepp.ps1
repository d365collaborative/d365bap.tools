$scbUdeDbJit = { Get-UdeDbJitCache | Sort-Object Id | Select-Object -ExpandProperty Id }
Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.ude.dbjit.credentials" -ScriptBlock $scbUdeDbJit -Mode Simple
