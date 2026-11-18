<#
    .SYNOPSIS
        Generates about_* help topics from the wiki topic sources.

    .DESCRIPTION
        Converts wiki/topics/*.md pages into about_*.help.txt files, mapped by
        the topic name in the page header.

    .PARAMETER SourceFolder
        Folder with the markdown topic sources.

        Default: ..\wiki\topics next to the build folder.

    .PARAMETER OutputFolder
        Folder receiving the generated topics.

        Default: ..\d365bap.tools\en-us.

    .PARAMETER WikiBaseUrl
        Base URL used for the online link of each topic.

        Default: the repository wiki URL.

    .PARAMETER MaxLines
        Maximum number of lines per generated topic. Longer output fails.

        Default: 120.
#>
[CmdletBinding()]
param(
	[string] $SourceFolder = (Join-Path -Path $PSScriptRoot -ChildPath '..\wiki\topics'),

	[string] $OutputFolder = (Join-Path -Path $PSScriptRoot -ChildPath '..\d365bap.tools\en-us'),

	[string] $WikiBaseUrl = 'https://github.com/d365collaborative/d365bap.tools/wiki',

	[int] $MaxLines = 120
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -Path $SourceFolder)) {
	throw "Topic source folder not found: $SourceFolder"
}

$null = New-Item -Path $OutputFolder -ItemType Directory -Force

$sourceFiles = @(Get-ChildItem -Path $SourceFolder -Filter '*.md' | Sort-Object -Property Name)

if ($sourceFiles.Count -eq 0) {
	throw "No topic sources found in: $SourceFolder"
}

function Convert-TopicInline {
	[CmdletBinding()]
	param (
		[string] $Text
	)

	process {
		$result = $Text
		$result = $result -replace '\[([^\]]+)\]\(([^)]+)\)', '$1 ($2)'
		$result = $result -replace '`([^`]+)`', '$1'
		$result = $result -replace '\*\*([^*]+)\*\*', '$1'
		$result = $result -replace '\*([^*]+)\*', '$1'
		$result.Trim()
	}
}

function Get-WrappedTopicText {
	[CmdletBinding()]
	param (
		[string] $Text,

		[string] $Prefix = "`t",

		[string] $ContinuePrefix = "`t",

		[int] $Width = 72
	)

	process {
		$colWords = @($Text -split '\s+' | Where-Object { $_ -ne '' })

		if ($colWords.Count -eq 0) { return }

		$colWrapped = [System.Collections.Generic.List[string]]::new()
		$current = ''

		foreach ($itemWord in $colWords) {
			if ($current -eq '') {
				$current = $itemWord
			}
			elseif (($current.Length + 1 + $itemWord.Length) -gt $Width) {
				$colWrapped.Add($current)
				$current = $itemWord
			}
			else {
				$current = "$current $itemWord"
			}
		}

		if ($current -ne '') { $colWrapped.Add($current) }

		$first = $true
		foreach ($itemLine in $colWrapped) {
			if ($first) {
				"$Prefix$itemLine"
				$first = $false
			}
			else {
				"$ContinuePrefix$itemLine"
			}
		}
	}
}

function Get-TopicHeaderEnd {
	[CmdletBinding()]
	param (
		[string[]] $RawLines,

		[string] $SourceName
	)

	process {
		if ($RawLines.Count -eq 0 -or $RawLines[0] -ne '<!--') {
			throw "$SourceName`: expected a <!-- ... --> header with topic and keywords as the first line."
		}

		$headerEndIndex = -1
		for ($index = 1; $index -lt $RawLines.Count; $index++) {
			if ($RawLines[$index] -match '^\s*-->\s*$') {
				$headerEndIndex = $index
				break
			}
		}

		if ($headerEndIndex -lt 1) {
			throw "$SourceName`: the <!-- header is not closed."
		}

		$headerEndIndex
	}
}

# Pass one: read every page header and build the source to topic map.

$topicBySource = @{}
$keywordsBySource = @{}
$seenTopics = @{}

foreach ($sourceFile in $sourceFiles) {
	$rawText = [IO.File]::ReadAllText($sourceFile.FullName) -replace "`r`n", "`n"
	$rawLines = @($rawText -split "`n")

	$headerEnd = Get-TopicHeaderEnd -RawLines $rawLines -SourceName $sourceFile.Name

	$topicName = ''
	$keywords = ''

	for ($index = 1; $index -lt $headerEnd; $index++) {
		if ($rawLines[$index] -match '^\s*topic:\s*(\S.*)$') {
			$topicName = $Matches[1].Trim()
		}
		elseif ($rawLines[$index] -match '^\s*keywords:\s*(.*)$') {
			$keywords = $Matches[1].Trim()
		}
	}

	if ([string]::IsNullOrWhiteSpace($topicName)) {
		throw "$($sourceFile.Name): the header must contain a 'topic: <name>' entry."
	}

	if ([string]::IsNullOrWhiteSpace($keywords)) {
		throw "$($sourceFile.Name): the header must contain a 'keywords: <list>' entry."
	}

	if ($seenTopics.ContainsKey($topicName)) {
		throw "Topic '$topicName' is defined by both $($seenTopics[$topicName]) and $($sourceFile.Name)."
	}

	$seenTopics[$topicName] = $sourceFile.Name
	$topicBySource[$sourceFile.BaseName] = $topicName
	$keywordsBySource[$sourceFile.BaseName] = $keywords
}

# Pass two: parse and convert each page body.

$blockKind = [System.Collections.Generic.List[string]]::new()
$blockText = [System.Collections.Generic.List[string]]::new()
$paragraph = [System.Collections.Generic.List[string]]::new()
$seeAlsoTopics = [System.Collections.Generic.HashSet[string]]::new()
$previousKind = ''

function Add-TopicBlock {
	[CmdletBinding()]
	param (
		[string] $Kind,

		[string] $Text
	)

	process {
		$blockKind.Add($Kind)
		$blockText.Add($Text)
		$script:previousKind = $Kind
	}
}

function Complete-TopicParagraph {
	[CmdletBinding()]
	param()

	process {
		if ($paragraph.Count -gt 0) {
			Add-TopicBlock -Kind 'para' -Text (($paragraph -join ' ').Trim())
			$paragraph.Clear()
		}
	}
}

$resolveLinks = {
	param ([string] $Line)

	$lineText = $Line
	$linkMatches = [regex]::Matches($lineText, '\[([^\]]+)\]\(([^)]+)\)')

	foreach ($linkMatch in $linkMatches) {
		$linkText = $linkMatch.Groups[1].Value
		$linkTarget = $linkMatch.Groups[2].Value

		if ($linkTarget -notmatch '^https?://') {
			$targetBase = $linkTarget -replace '\.md$', ''

			if (-not $topicBySource.ContainsKey($targetBase)) {
				throw "$($sourceFile.Name): relative link target '$linkTarget' does not match a topic source. Use a full URL for non-topic links."
			}

			$replacement = "$linkText (about_$($topicBySource[$targetBase]))"
			$lineText = $lineText.Replace($linkMatch.Value, $replacement)
			$null = $seeAlsoTopics.Add($topicBySource[$targetBase])
		}
	}

	$lineText
}

$writtenFileNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

foreach ($sourceFile in $sourceFiles) {
	$topicName = $topicBySource[$sourceFile.BaseName]

	$rawText = [IO.File]::ReadAllText($sourceFile.FullName) -replace "`r`n", "`n"
	$rawLines = @($rawText -split "`n")

	$headerEnd = Get-TopicHeaderEnd -RawLines $rawLines -SourceName $sourceFile.Name

	if (($headerEnd + 1) -gt ($rawLines.Count - 1)) {
		throw "$($sourceFile.Name): the page has no body after the header."
	}

	$bodyLines = $rawLines[($headerEnd + 1)..($rawLines.Count - 1)]
	$seeAlsoTopics.Clear()

	$blockKind.Clear()
	$blockText.Clear()
	$paragraph.Clear()
	$script:previousKind = ''
	$inVerbatim = $false

	foreach ($rawLine in $bodyLines) {
		if ($inVerbatim) {
			if ($rawLine -match '^\s*```\w*\s*$') {
				$inVerbatim = $false
			}
			else {
				Add-TopicBlock -Kind 'verbatim' -Text $rawLine.TrimEnd()
			}
			continue
		}

		if ($rawLine -match '^\s*```\w*\s*$') {
			Complete-TopicParagraph
			$inVerbatim = $true
			continue
		}

		if ($rawLine -match '^\s*$') {
			Complete-TopicParagraph
			continue
		}

		if ($rawLine -match '^#\s+(.*)$') {
			Complete-TopicParagraph
			continue
		}

		if ($rawLine -match '^##\s+(.*)$') {
			Complete-TopicParagraph
			Add-TopicBlock -Kind 'heading2' -Text (Convert-TopicInline -Text $Matches[1])
			continue
		}

		if ($rawLine -match '^###\s+(.*)$') {
			Complete-TopicParagraph
			Add-TopicBlock -Kind 'heading3' -Text (Convert-TopicInline -Text $Matches[1])
			continue
		}

		if ($rawLine -match '^\|\s') {
			throw "$($sourceFile.Name): tables are not supported. Write the command map as a bullet list instead."
		}

		if ($rawLine -match '^[-*]\s+(.*)$') {
			Complete-TopicParagraph
			$blockKind.Add('bullet')
			$blockText.Add((Convert-TopicInline -Text (& $resolveLinks -Line $Matches[1])))
			$script:previousKind = 'bullet'
			continue
		}

		if ($rawLine -match '^(\d+)\.\s+(.*)$') {
			Complete-TopicParagraph
			$blockKind.Add("numbered:$($Matches[1])")
			$blockText.Add((Convert-TopicInline -Text (& $resolveLinks -Line $Matches[2])))
			$script:previousKind = "numbered:$($Matches[1])"
			continue
		}

		if ($rawLine -match '^\s+(.*)$') {
			if ($paragraph.Count -gt 0) {
				$paragraph.Add((Convert-TopicInline -Text (& $resolveLinks -Line $Matches[1])))
			}
			elseif ($script:previousKind -like 'bullet*' -or $script:previousKind -like 'numbered*') {
				$blockKind.Add('nested')
				$blockText.Add((Convert-TopicInline -Text (& $resolveLinks -Line $Matches[1])))
			}
			else {
				Add-TopicBlock -Kind 'verbatim' -Text $rawLine.TrimEnd()
			}
			continue
		}

		$paragraph.Add((Convert-TopicInline -Text (& $resolveLinks -Line $rawLine)))
	}

	Complete-TopicParagraph

	if ($blockKind.Count -eq 0 -or $blockKind[0] -ne 'para') {
		throw "$($sourceFile.Name): the body must start with a one paragraph short description right after the H1."
	}

	$shortDescription = $blockText[0]

	if ($shortDescription.Length -gt 200) {
		throw "$($sourceFile.Name): the short description is $($shortDescription.Length) characters. Keep it under 200."
	}

	$bodyOut = [System.Collections.Generic.List[string]]::new()
	$previousRenderedKind = ''

	for ($blockIndex = 1; $blockIndex -lt $blockKind.Count; $blockIndex++) {
		$kind = $blockKind[$blockIndex]
		$text = $blockText[$blockIndex]

		$inListRun = ($previousRenderedKind -eq 'bullet') -or ($previousRenderedKind -eq 'nested') -or ($previousRenderedKind -like 'numbered:*')

		$needsBlankBefore = $false
		if ($kind -eq 'heading2' -or $kind -eq 'heading3' -or $kind -eq 'para') {
			$needsBlankBefore = $true
		}
		elseif ($kind -eq 'nested') {
			$needsBlankBefore = $false
		}
		elseif ($kind -eq 'bullet' -or $kind -like 'numbered:*') {
			$needsBlankBefore = -not $inListRun
		}
		elseif ($kind -eq 'verbatim') {
			$needsBlankBefore = $previousRenderedKind -ne 'verbatim'
		}

		if ($needsBlankBefore -and $bodyOut.Count -gt 0) { $bodyOut.Add('') }

		if ($kind -eq 'heading2') {
			$bodyOut.Add("`t$text")
			$bodyOut.Add("`t" + ('-' * $text.Length))
		}
		elseif ($kind -eq 'heading3') {
			$bodyOut.Add("`t$text")
		}
		elseif ($kind -eq 'para') {
			foreach ($line in (Get-WrappedTopicText -Text $text)) { $bodyOut.Add($line) }
		}
		elseif ($kind -eq 'bullet') {
			foreach ($line in (Get-WrappedTopicText -Text $text -Prefix "`t- " -ContinuePrefix "`t  " -Width 70)) { $bodyOut.Add($line) }
		}
		elseif ($kind -eq 'nested') {
			$bodyOut.Add("`t    $text")
		}
		elseif ($kind -eq 'verbatim') {
			if ([string]::IsNullOrEmpty($text)) { $bodyOut.Add('') } else { $bodyOut.Add("`t    $text") }
		}
		else {
			$marker = $kind.Substring(9)
			foreach ($line in (Get-WrappedTopicText -Text $text -Prefix "`t$marker. " -ContinuePrefix "`t   " -Width 68)) { $bodyOut.Add($line) }
		}

		$previousRenderedKind = $kind
	}

	$seeAlso = [System.Collections.Generic.List[string]]::new()

	if ($topicName -eq 'd365bap.tools') {
		foreach ($otherTopic in ($topicBySource.Values | Sort-Object)) {
			if ($otherTopic -ne 'd365bap.tools') {
				$null = $seeAlso.Add("about_$otherTopic")
			}
		}
	}
	else {
		$null = $seeAlso.Add('about_d365bap.tools')

		foreach ($linkedTopic in ($seeAlsoTopics | Sort-Object -Unique)) {
			if ($linkedTopic -ne $topicName) {
				$null = $seeAlso.Add("about_$linkedTopic")
			}
		}
	}

	$wikiUrl = $WikiBaseUrl
	if ($topicName -ne 'd365bap.tools') {
		$wikiUrl = "$WikiBaseUrl/Topics/$($sourceFile.BaseName)"
	}
	$null = $seeAlso.Add("Online: $wikiUrl")

	$outputLines = [System.Collections.Generic.List[string]]::new()
	$outputLines.Add('TOPIC')
	$outputLines.Add("`tabout_$topicName")
	$outputLines.Add('')
	$outputLines.Add('SHORT DESCRIPTION')
	foreach ($line in (Get-WrappedTopicText -Text $shortDescription)) { $outputLines.Add($line) }
	$outputLines.Add('')
	$outputLines.Add('LONG DESCRIPTION')
	foreach ($line in $bodyOut) { $outputLines.Add($line) }
	$outputLines.Add('')
	$outputLines.Add('KEYWORDS')
	$outputLines.Add("`t$($keywordsBySource[$sourceFile.BaseName])")
	$outputLines.Add('')
	$outputLines.Add('SEE ALSO')
	foreach ($item in $seeAlso) { $outputLines.Add("`t$item") }

	if ($outputLines.Count -gt $MaxLines) {
		throw "$($sourceFile.Name): the generated topic has $($outputLines.Count) lines, over the $MaxLines line budget. Split the topic or trim it."
	}

	$targetPath = Join-Path -Path $OutputFolder -ChildPath "about_$topicName.help.txt"
	$cleanLines = foreach ($outputLine in $outputLines) { $outputLine.TrimEnd() }
	[IO.File]::WriteAllText($targetPath, (@($cleanLines) -join "`r`n") + "`r`n", [Text.UTF8Encoding]::new($true))
	$null = $writtenFileNames.Add("about_$topicName.help.txt")

	Write-Host "Generated about_$topicName.help.txt ($($outputLines.Count) lines)."
}

foreach ($existingFile in @(Get-ChildItem -Path $OutputFolder -Filter 'about_*.help.txt')) {
	if (-not $writtenFileNames.Contains($existingFile.Name)) {
		Remove-Item -Path $existingFile.FullName -Force
		Write-Host "Removed stale topic: $($existingFile.Name)."
	}
}
