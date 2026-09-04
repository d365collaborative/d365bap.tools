# Format XML

Do not edit `d365bap.tools.Table.Format.ps1xml` or `d365bap.tools.List.Format.ps1xml`. They are generated.

Create and maintain each view in its own file:

- Table: `formats/table/<TypeName>.Table.Format.ps1xml`
- List: `formats/list/<TypeName>.List.Format.ps1xml`

`<TypeName>` is the `PSTypeName` on the object (for example `D365Bap.Tools.UdeEnvironmentPackage`).

After adding or changing a per-type file, rebuild the two loadable files from the repo root:

```powershell
pwsh -NoProfile -File ./build/Merge-FormatPs1Xml.ps1
```

Include both the per-type file and the regenerated consolidated files in the same commit.

The module loads table first (default output), then list (`Format-List`). Do not add views to `FormatsToProcess` in the manifest.
