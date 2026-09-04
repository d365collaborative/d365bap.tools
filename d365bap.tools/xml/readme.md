# XML

This is the folder where project XML files go, notably:

 - Format XML
 - Type Extension XML

External help files should _not_ be placed in this folder!

## Notes on Files and Naming

There should be few format files and one type extension file per project, as importing them has a notable impact on import times.

PowerShell treats each `FormatsToProcess` entry as a nested module load (limit 10). Combined with `RequiredModules` (especially Az.Accounts), format data fails to register: `Get-FormatData` returns nothing and objects render as List. The per-type files under `xml/formats` are for editing. Rebuild the two loadable files with `build/Merge-FormatPs1Xml.ps1`. The module loads **table first, then list** from `internal/scripts/load-formatdata.ps1`, not from `FormatsToProcess`.

 - Table views: `d365bap.tools.Table.Format.ps1xml` (default output)
 - List views: `d365bap.tools.List.Format.ps1xml` (`Format-List`)
 - The Type Extension XML should be named `d365bap.tools.Types.ps1xml`

## Tools

### New-PSMDFormatTableDefinition

This function will take an input object and generate format xml for an auto-sized table.

It provides a simple way to get started with formats.

### Get-PSFTypeSerializationData

```
C# Warning!
This section is only interest if you're using C# together with PowerShell.
```

This function generates type extension XML that allows PowerShell to convert types written in C# to be written to file and restored from it without being 'Deserialized'. Also works for jobs or remoting, if both sides have the `PSFramework` module and type extension loaded.

In order for a class to be eligible for this, it needs to conform to the following rules:

 - Have the `[Serializable]` attribute
 - Be public
 - Have an empty constructor
 - Allow all public properties/fields to be set (even if setting it doesn't do anything) without throwing an exception.

```
non-public properties and fields will be lost in this process!
```