# CI stub: token minting is out of scope for validate/build import paths.
function Get-AzContext {
	[CmdletBinding()]
	param(
		[switch] $ListAvailable
	)

	if ($ListAvailable) {
		return @()
	}
}

function Get-AzAccessToken {
	[CmdletBinding()]
	param(
		[Parameter(ValueFromRemainingArguments = $true)]
		[object[]] $RemainingArguments
	)

	$null = $RemainingArguments
	throw 'CI Az.Accounts stub does not mint tokens. Use a real Az.Accounts install outside CI stub mode.'
}
