# Public functions

Comment-based help must never document automatic parameters.
Do not write `.PARAMETER Confirm`, `.PARAMETER WhatIf`, or `.PARAMETER ProgressAction` blocks. PowerShell
and platyPS document those on their own. `Help.Tests.ps1` treats them as
common parameters and skips them.
