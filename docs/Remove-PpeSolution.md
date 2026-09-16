---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Remove-PpeSolution

## SYNOPSIS
Remove solutions from a Power Platform environment.

## SYNTAX

```
Remove-PpeSolution [-EnvironmentId] <String> [[-Name] <String>] [-Force] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Removes unmanaged Dataverse solutions (solutions) from a specified environment.

Solutions are matched by friendly name, unique name or id.
Nothing is removed unless the -Force switch is supplied.
Without -Force the cmdlet lists the solutions that would be removed.

Managed solutions cannot be uninstalled with this cmdlet when they have managed dependencies - remove the dependent components first.

## EXAMPLES

### EXAMPLE 1
```
Remove-PpeSolution -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Name "contoso_tools"
```

This will show the solution that would be removed for the specified environment id.
It will NOT remove the solution yet, allowing you to review it before deciding to remove it.

### EXAMPLE 2
```
Remove-PpeSolution -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Name "contoso_tools" -Force
```

This will remove the specified solution for the specified environment id without further confirmation.

### EXAMPLE 3
```
Get-PpeSolution -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Name "*contoso*" | Remove-PpeSolution -Force
```

This will remove all solutions returned for the specified environment id without further confirmation.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

```yaml
Type: String
Parameter Sets: (All)
Aliases: PpacEnvId

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Name
The name of the solution that you want to remove.

Can be either the friendly name, unique name or id of the solution.
Supports wildcard characters for flexible matching.

Defaults to "*" - combine with -Force to remove every unmanaged solution, which is almost never what you want.

```yaml
Type: String
Parameter Sets: (All)
Aliases: SystemName, PpeSolutionId

Required: False
Position: 2
Default value: *
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Force
Instructs the function to proceed with removing the solutions.

Nothing happens unless this parameter is supplied.

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
