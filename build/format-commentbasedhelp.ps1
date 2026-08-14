# Script to format the comments/documentation of the cmdlets used for the commend based help.
# based on https://gist.github.com/Splaxi/ff7485a24f6ed9937f3e8da76b5d4840
# See also https://github.com/d365collaborative/d365fo.tools/wiki/Building-tools
$path = "$PSScriptRoot\..\d365bap.tools"

function Get-Header ($text) {
    $start = $text.IndexOf('<#')
    $temp = $start - 2
    if($temp -gt 0) {
        $text.SubString(0, $start - 2)
    }
    else {
    ""
    }
}

function Format-Help ($text) {
    $start = $text.IndexOf('<#')
    $end = $text.IndexOf('#>')
    $help = $text.SubString($start + 2, $end - $start - 3)
    
    $skipfirst = $null # to avoid trailing spaces
    foreach ($newline in $help.Split("`n")) {
        if (-not $skipfirst) { $skipfirst = $true; continue }
        $trimmed = $newline.Trim()
        foreach ($line in $trimmed) {
            if ($line.StartsWith(".")) {
                "    $line"
            }
            else {
                "        $line"
            }
        }
    }
}

function Get-Body ($text) {
    $end = $text.IndexOf('#>')
    $text.SubString($end, $text.Length - $end)
}

$files = New-Object System.Collections.ArrayList
$filesPublic = Get-ChildItem -Path "$path\functions\*.ps1"
$files.AddRange($filesPublic)
$filesInternal = Get-ChildItem -Path "$path\internal\functions\*.ps1"
$files.AddRange($filesInternal)

# -Encoding UTF8 means "no BOM" on PowerShell 7, so write the files explicitly with a BOM instead
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$newLine = [System.Environment]::NewLine

foreach ($file in $files) {
    $text = ($file | Get-Content -Raw).Trim()

    $builder = New-Object System.Text.StringBuilder
    $null = $builder.Append((Get-Header $text).TrimEnd()).Append($newLine)
    $null = $builder.Append("<#").Append($newLine)

    foreach ($line in (Format-Help $text)) {
        $null = $builder.Append($line).Append($newLine)
    }

    $null = $builder.Append((Get-Body $text).TrimEnd())

    [System.IO.File]::WriteAllText($file.FullName, $builder.ToString(), $utf8Bom)
}