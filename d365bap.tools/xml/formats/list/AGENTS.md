# List format views

Create and maintain list views here. One file per type:

`<TypeName>.List.Format.ps1xml`

Do not edit `../../d365bap.tools.List.Format.ps1xml`. After changing a file here, run from the repo root:

```powershell
pwsh -NoProfile -File ./build/Merge-FormatPs1Xml.ps1
```
