# Public functions

Comment-based help must never document the automatic ShouldProcess parameters.
Do not write `.PARAMETER Confirm` or `.PARAMETER WhatIf` blocks. PowerShell
and platyPS document those on their own. `Help.Tests.ps1` treats them as
common parameters and skips them.
