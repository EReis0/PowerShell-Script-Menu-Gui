param(
    [Parameter(Mandatory)][string]$ScriptsPath,
    [string]$OutputCsvPath = '.\generated-menu.csv'
)

Import-Module PSScriptMenuGui -ErrorAction Stop

# Example 1: Auto-generate and launch in one command using -LaunchGui
New-MenuCsvFromScripts -Path $ScriptsPath -Recurse -OutputCsvPath $OutputCsvPath -LaunchGui

# Example 2: Generate CSV with a custom SectionMap, then launch with layout options
# New-MenuCsvFromScripts -Path $ScriptsPath -Recurse -OutputCsvPath $OutputCsvPath `
#     -SectionMap @{ 'Get' = 'QUERIES'; 'Add' = 'NEW'; 'Set' = 'CHANGE'; 'Invoke' = 'ACTIONS' } `
#     -DefaultSection 'OTHER'
# Show-ScriptMenuGui -csvPath $OutputCsvPath -groupLayout Grid -columns 2 -fullscreen
