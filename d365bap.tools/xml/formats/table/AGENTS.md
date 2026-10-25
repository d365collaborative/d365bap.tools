# Table format views

Create and maintain table views here. One file per type:

`<TypeName>.Table.Format.ps1xml`

Do not edit `../../d365bap.tools.Table.Format.ps1xml` (owned by the regen
workflow). After changing a file here, push only the per-type file; the regen
workflow commits the rebuilt consolidated file back onto the PR branch
automatically.

Local preview only (never commit the result):

```powershell
pwsh -NoProfile -File ./build/Merge-FormatPs1Xml.ps1
```
