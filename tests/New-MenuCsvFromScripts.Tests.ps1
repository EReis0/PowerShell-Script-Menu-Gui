Describe 'New-MenuCsvFromScripts' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        . (Join-Path $repoRoot 'PSScriptMenuGui/public/functions.ps1')
        . (Join-Path $repoRoot 'PSScriptMenuGui/private/functions.ps1')
    }

    It 'builds rows with expected metadata and defaults' {
        $scriptsPath = Join-Path $TestDrive 'scripts'
        New-Item -Path $scriptsPath -ItemType Directory | Out-Null

        @'
<#
.SYNOPSIS
Get user details.
#>
param()
'@ | Set-Content -Path (Join-Path $scriptsPath 'Get-User.ps1')

        'REM Run diagnostics' | Set-Content -Path (Join-Path $scriptsPath 'Check.cmd')
        ':: Build report' | Set-Content -Path (Join-Path $scriptsPath 'Add-Report.bat')

        $rows = New-MenuCsvFromScripts -Path $scriptsPath -PassThru

        $rows.Count | Should -Be 3

        $ps1Row = $rows | Where-Object Name -eq 'Get-User'
        $ps1Row.Method | Should -Be 'powershell_file'
        $ps1Row.Section | Should -Be 'QUERIES'
        $ps1Row.Description | Should -Be 'Get user details.'
        $ps1Row.RunAsAdmin | Should -Be 'False'

        $cmdRow = $rows | Where-Object Name -eq 'Check'
        $cmdRow.Method | Should -Be 'cmd'
        $cmdRow.Description | Should -Be 'Run diagnostics'

        $batRow = $rows | Where-Object Name -eq 'Add-Report'
        $batRow.Method | Should -Be 'cmd'
        $batRow.Section | Should -Be 'NEW'
        $batRow.Description | Should -Be 'Build report'
    }

    It 'uses longest prefix section map match' {
        $scriptsPath = Join-Path $TestDrive 'scripts-prefix'
        New-Item -Path $scriptsPath -ItemType Directory | Out-Null

        @'
<#
.SYNOPSIS
Get user info.
#>
param()
'@ | Set-Content -Path (Join-Path $scriptsPath 'Get-UserInfo.ps1')

        $rows = New-MenuCsvFromScripts -Path $scriptsPath -SectionMap @{ 'Get' = 'GENERAL'; 'Get-User' = 'USERS' } -PassThru

        $rows.Count | Should -Be 1
        $rows[0].Section | Should -Be 'USERS'
    }

    It 'writes and appends CSV output when requested' {
        $scriptsPath = Join-Path $TestDrive 'scripts-output'
        New-Item -Path $scriptsPath -ItemType Directory | Out-Null

        @'
<#
.SYNOPSIS
First script.
#>
param()
'@ | Set-Content -Path (Join-Path $scriptsPath 'Get-First.ps1')

        $outputPath = Join-Path $TestDrive 'menu.csv'
        New-MenuCsvFromScripts -Path $scriptsPath -OutputCsvPath $outputPath

        @'
<#
.SYNOPSIS
Second script.
#>
param()
'@ | Set-Content -Path (Join-Path $scriptsPath 'Get-Second.ps1')

        New-MenuCsvFromScripts -Path $scriptsPath -OutputCsvPath $outputPath -Append

        $csvRows = Import-Csv -Path $outputPath
        $csvRows.Count | Should -Be 3
        ($csvRows | Where-Object Name -eq 'Get-First').Count | Should -Be 2
        ($csvRows | Where-Object Name -eq 'Get-Second').Count | Should -Be 1
    }

    It 'throws if OutputCsvPath is a directory' {
        $scriptsPath = Join-Path $TestDrive 'scripts-errors'
        New-Item -Path $scriptsPath -ItemType Directory | Out-Null

        @'
<#
.SYNOPSIS
Example script.
#>
param()
'@ | Set-Content -Path (Join-Path $scriptsPath 'Get-Example.ps1')

        { New-MenuCsvFromScripts -Path $scriptsPath -OutputCsvPath $scriptsPath } | Should -Throw "OutputCsvPath '$scriptsPath' must be a file path, not a directory."
    }
}
