param(
    [Parameter(Mandatory)][string]$ScriptsPath,
    [string]$OutputCsvPath = '.\generated-menu.csv'
)

Import-Module PSScriptMenuGui -ErrorAction Stop

New-MenuCsvFromScripts -Path $ScriptsPath -Recurse -OutputCsvPath $OutputCsvPath -SectionMap @{ 'Get' = 'QUERIES'; 'Add' = 'NEW'; 'Set' = 'CHANGE' }
Show-ScriptMenuGui -csvPath $OutputCsvPath -groupLayout Grid -columns 2 -fullscreen
