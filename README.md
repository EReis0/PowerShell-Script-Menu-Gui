# PSScriptMenuGui

[![PSGallery Version](https://img.shields.io/powershellgallery/v/PSScriptMenuGui.png?style=for-the-badge&logo=powershell&label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/PSScriptMenuGui/) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/PSScriptMenuGui.png?style=for-the-badge&label=Downloads)](https://www.powershellgallery.com/packages/PSScriptMenuGui/) [![PSGallery Platform](https://img.shields.io/powershellgallery/p/PSScriptMenuGui.png?style=for-the-badge&label=Platform)](https://www.powershellgallery.com/packages/PSScriptMenuGui/)

Make a graphical menu of scripts and commands from CSV.

## Basic usage

```powershell
Show-ScriptMenuGui -csvPath '.\examples\csv\basic.csv' -Verbose
```

## Show-ScriptMenuGui options

Parameter | What is it?
:--- |:---
`-csvPath` | Path to CSV file that defines the menu.
`-windowTitle` | Custom title for the menu window.
`-buttonForegroundColor` | Button text color.
`-buttonBackgroundColor` | Button background color.
`-iconPath` | Path to `.ico` file.
`-hideConsole` | Hide the calling PowerShell console.
`-noExit` | Adds `-NoExit` to PowerShell host launch.
`-columns` | Optional layout columns for `Grid` mode.
`-rows` | Optional row target used for grid auto column calculation.
`-buttonWidth` | Button width (80-600, default 150).
`-buttonHeight` | Button minimum height (25-300, default 50).
`-groupLayout` | `Stacked` (default), `Grid`, or `ColumnPerGroup`.
`-fullscreen` | Start in fullscreen/maximized mode.
`-borderlessFullscreen` | Borderless fullscreen (requires `-fullscreen`).

## CSV reference

Backward compatibility is preserved: existing `Command`-only rows continue to work.

Column header | What is it?
:--- |:---
Section *(optional)* | Heading/group
Method | `cmd` \| `powershell_file` \| `powershell_inline` \| `pwsh_file` \| `pwsh_inline`
Command | Target executable/script path or inline command
Arguments *(optional)* | Arguments passed to `Command`
WorkingDirectory *(optional)* | Process working directory
RunAsAdmin *(optional)* | `true/false`, `yes/no`, or `1/0`
Name | Button text
Description *(optional)* | Description text

## Multiple argument examples

See `examples/csv/multi-args.csv` for `.ps1`, `.cmd`, and `.bat` examples.

Quoting guidance:

- Quote argument values containing spaces: `-Name "My Value"`.
- For CSV cells with quotes, escape with double quotes, for example:
  `"-patchowner ""My Name"" -showpatches"`
- For paths with spaces, quote the path in `Arguments`.
- For Windows paths in CSV, use normal backslashes (e.g. `"C:\Program Files\App"`).

## Layout examples

```powershell
Show-ScriptMenuGui -csvPath '.\examples\csv\grid-layout.csv' -groupLayout Grid -columns 2 -buttonWidth 180 -buttonHeight 60
```

```powershell
Show-ScriptMenuGui -csvPath '.\examples\csv\grid-layout.csv' -groupLayout ColumnPerGroup
```

`Stacked` keeps the legacy behavior.

## Fullscreen

```powershell
Show-ScriptMenuGui -csvPath '.\examples\csv\grid-layout.csv' -fullscreen
Show-ScriptMenuGui -csvPath '.\examples\csv\grid-layout.csv' -fullscreen -borderlessFullscreen
```

Press `ESC` to close in fullscreen mode.

## Auto-build CSV from scripts

```powershell
New-MenuCsvFromScripts -Path '.\scripts' -Recurse -OutputCsvPath '.\generated-menu.csv' -SectionMap @{ 'Get'='QUERIES'; 'Add'='NEW' }
Show-ScriptMenuGui -csvPath '.\generated-menu.csv'
```

See: `examples/scripts/Generate-MenuAndLaunch.ps1`

## Troubleshooting

- **Arguments not parsed as expected**: verify CSV escaping/quoting.
- **Path not found**: use absolute paths or set `WorkingDirectory`.
- **Script blocked**: check execution policy and signing requirements.
- **No visible errors**: disable `-hideConsole` while troubleshooting.

## Manual validation notes

There is no test framework in this repository. Reproducible validation:

1. Import module and run `Get-Command -Module PSScriptMenuGui`.
2. Generate CSV via `New-MenuCsvFromScripts` and verify exported columns.
3. Launch menu in `Stacked`, `Grid`, `ColumnPerGroup`, and `Fullscreen` modes.
4. Validate legacy CSV rows with only `Command` still launch.
