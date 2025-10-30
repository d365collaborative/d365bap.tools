---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-UdeWindowsDefenderRules

## SYNOPSIS
Adds Windows Defender exclusion rules for UDE development tools and environments.

## SYNTAX

```
Add-UdeWindowsDefenderRules [-Force] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function configures Windows Defender by adding exclusion rules for processes, paths, and file extensions commonly used in UDE development environments.

This helps to prevent Windows Defender from interfering with development activities.

## EXAMPLES

### EXAMPLE 1
```
Add-UdeWindowsDefenderRules
```

This command adds the necessary Windows Defender exclusion rules for UDE development.
If the current session is not running as Administrator, it will fail.

### EXAMPLE 2
```
Add-UdeWindowsDefenderRules -Force
```

This command adds the necessary Windows Defender exclusion rules for UDE development.
If the current session is not running as Administrator, it will restart PowerShell with elevated privileges.

## PARAMETERS

### -Force
Instructs the function to run with elevated (Administrator) privileges.
If the current PowerShell session is not running as Administrator, the function will restart PowerShell with elevated privileges.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
