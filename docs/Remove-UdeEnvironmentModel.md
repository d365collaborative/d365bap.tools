---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Remove-UdeEnvironmentModel

## SYNOPSIS
Remove models from a unified environment.

## SYNTAX

```
Remove-UdeEnvironmentModel [-EnvironmentId] <String> [-Model] <String[]> [[-WorkFolder] <String>]
 [-WaitForCompletion] [-DownloadLog] [-Force] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Removes one or more models from a unified environment (UDE, USE and others).

Implements Way 2 from Plan-UdeModelDelete-Way2: downloads the last
uploaded deploy zip for each model as a seed, rebuilds it as a Delete
package and deploys it with BuildType=Delete.

-Model accepts an array of names.
Each name is validated against
Get-UdeEnvironmentModel.
Unknown names stop the cmdlet.

Dependency linked models are supported: descriptor files
(Descriptor/\<model\>.xml) from all installed models are read from
their seed packages.
If a model outside the removal list references
a model inside it, the cmdlet stops.
If a model inside the removal
list references another installed model, the referenced model is
added to the removal list, so the environment stays in a working
state.

Without -Force the cmdlet never calls DELETE msprov_fnomodules.
That record-only fallback requires -Force.

## EXAMPLES

### EXAMPLE 1
```
Remove-UdeEnvironmentModel -EnvironmentId "env-123" -Model "B"
```

This will remove the model B from the specified environment id.
It will wait for the delete deployment to complete.

### EXAMPLE 2
```
Remove-UdeEnvironmentModel -EnvironmentId "env-123" -Model "A" -DownloadLog
```

This will remove the model A and all models that depend on it from the specified environment id.
It will download the operation logs to the work folder.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against

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

### -Model
The names of the models that you want to remove.

Each name is validated against Get-UdeEnvironmentModel.
If the module table is empty, names fall back to the package
names from Get-UnifiedEnvironmentPackage.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Name

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WorkFolder
The folder where seed and delete packages are stored.

Defaults to "C:\Temp\d365bap.tools\RemoveUdeModel".

Files are organized in subfolders for each environment and model.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: C:\Temp\d365bap.tools\RemoveUdeModel
Accept pipeline input: False
Accept wildcard characters: False
```

### -WaitForCompletion
Instructs the cmdlet to wait until the delete deployment has completed.

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

### -DownloadLog
Instructs the cmdlet to download the operation logs for the delete deployment.

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

### -Force
Instructs the cmdlet to allow the record-only fallback.

Without Force the cmdlet never calls DELETE msprov_fnomodules.

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

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
