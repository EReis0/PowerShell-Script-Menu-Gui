# Execution flow overview (Show-ScriptMenuGui):
#   1. CSV parsing      - Import-Csv reads rows; each row gets a unique Reference property.
#   2. Layout planning  - Get-LayoutPlan (private) converts CSV rows into typed layout elements
#                         (Heading / Item) and returns column widths + row count.
#   3. XAML generation  - New-GuiHeading / New-GuiRow (private) emit XAML fragments; the full
#                         Window XML is assembled from those fragments.
#   4. Form creation    - New-GuiForm (private) parses XAML, loads WPF assemblies, and collects
#                         button objects from the visual tree into $script:buttons.
#   5. Event wiring     - Each button's Click handler calls Invoke-ButtonAction (private), which
#                         looks up the matching CSV row and delegates to Start-Script (private).
#   6. Command execution- Start-Script (private) launches the target via Start-Process, choosing
#                         powershell.exe / pwsh.exe / cmd based on the Method column.

Function Show-ScriptMenuGui {
    <#
    .SYNOPSIS
        Use a CSV file to make a graphical menu of PowerShell scripts. Easy to customise and fast to launch.
    .DESCRIPTION
        Do you have favourite scripts that go forgotten?

        Does your organisation have scripts that would be useful to frontline staff who are not comfortable with the command line?

        This module uses a CSV file to make a graphical menu of PowerShell scripts.

        You can also add Windows programs and files to the menu.
    .PARAMETER csvPath
        Path to CSV file that defines the menu.

        See CSV reference: https://github.com/weebsnore/PowerShell-Script-Menu-Gui
    .PARAMETER windowTitle
        Custom title for the menu window.
    .PARAMETER buttonForegroundColor
        Custom button foreground (text) color.

        Hex codes (e.g. #C00077) and color names (e.g. Azure) are valid.

        See .NET Color Class: https://docs.microsoft.com/en-us/dotnet/api/system.windows.media.colors
    .PARAMETER buttonBackgroundColor
        Custom button background color.
    .PARAMETER iconPath
        Path to .ico file for use in menu.
    .PARAMETER hideConsole
        Hide the PowerShell console that the menu is called from.

        Note: This means you won't be able to see any errors from button clicks. If things aren't working, this should be the first thing you stop using.
    .PARAMETER noExit
        Start all PowerShell instances with -NoExit ("Does not exit after running startup commands.")

        Note: You can set -NoExit on individual menu items by using the Arguments column.

        See CSV reference: https://github.com/weebsnore/PowerShell-Script-Menu-Gui
    .EXAMPLE
        Show-ScriptMenuGui -csvPath '.\example_data.csv' -Verbose
    .NOTES
        Run New-ScriptMenuGuiExample to get some example files
    .LINK
        https://github.com/weebsnore/PowerShell-Script-Menu-Gui
    #>
    [CmdletBinding()]
    param(
        [string][Parameter(Mandatory)]$csvPath,
        [string]$windowTitle = 'PowerShell Script Menu',
        [string]$buttonForegroundColor = 'White',
        [string]$buttonBackgroundColor = '#366EE8',
        [string]$iconPath,
        [switch]$hideConsole,
        [switch]$noExit,
        [int]$columns = 0,
        [int]$rows = 0,
        [int]$buttonWidth = 150,
        [int]$buttonHeight = 50,
        [ValidateSet('Stacked','Grid','ColumnPerGroup')][string]$groupLayout = 'Stacked',
        [switch]$fullscreen,
        [switch]$borderlessFullscreen
    )
    Write-Verbose 'Show-ScriptMenuGui started'

    if ($columns -lt 0 -or $columns -gt 10) {
        throw 'Columns must be between 0 and 10 (0 uses auto/default behavior, primarily for Grid mode).'
    }
    if ($rows -lt 0 -or $rows -gt 200) {
        throw 'Rows must be between 0 and 200 (0 uses auto/default behavior).'
    }
    if ($buttonWidth -lt 80 -or $buttonWidth -gt 600) {
        throw 'ButtonWidth must be between 80 and 600.'
    }
    if ($buttonHeight -lt 25 -or $buttonHeight -gt 300) {
        throw 'ButtonHeight must be between 25 and 300.'
    }
    if ($borderlessFullscreen -and -not $fullscreen) {
        throw 'BorderlessFullscreen requires Fullscreen.'
    }

    # -Verbose value, to pass to select cmdlets
    $verbose = $false
    try {
        if ($PSBoundParameters['Verbose'].ToString() -eq 'True') {
            $verbose = $true
        }
    }
    catch {}

    $csvData = Import-CSV -Path $csvPath -ErrorAction Stop
    Write-Verbose "Got $($csvData.Count) CSV rows"

    # Add unique Reference to each item
    # Used as x:Name of button and to look up action on click
    $i = 0
    $csvData | ForEach-Object {
        $_ | Add-Member -Name Reference -MemberType NoteProperty -Value "button$i"
        $i++
    }

    # Build layout plan
    $layoutPlan = Get-LayoutPlan -csvData $csvData -groupLayout $groupLayout -columns $columns -rows $rows -buttonWidth $buttonWidth -buttonHeight $buttonHeight -Verbose:$verbose

    $columnDefinitions = ($layoutPlan.ColumnWidths | ForEach-Object { "                <ColumnDefinition Width=`"$_`"/>" }) -join [Environment]::NewLine
    $rowDefinitions = ((1..$layoutPlan.RowCount) | ForEach-Object { '                <RowDefinition/>' }) -join [Environment]::NewLine

    $contentLines = @()
    foreach ($element in $layoutPlan.Elements) {
        if ($element.Type -eq 'Heading') {
            $contentLines += New-GuiHeading -name $element.Name -row $element.Row -column $element.ButtonColumn -columnSpan $element.ColumnSpan
            continue
        }

        $contentLines += New-GuiRow -item $element.Item -row $element.Row -buttonColumn $element.ButtonColumn -descriptionColumn $element.DescriptionColumn -buttonWidth $buttonWidth -buttonHeight $buttonHeight -buttonBackgroundColor $buttonBackgroundColor -buttonForegroundColor $buttonForegroundColor
    }

    $windowAttributes = @('WindowStartupLocation="CenterScreen"')
    if ($fullscreen) {
        $windowAttributes += 'WindowState="Maximized"'
        $windowAttributes += 'SizeToContent="Manual"'
    }
    else {
        $windowAttributes += 'SizeToContent="WidthAndHeight"'
        $windowAttributes += 'MaxHeight="800"'
        $windowAttributes += 'MinHeight="200"'
        $windowAttributes += 'MaxWidth="600"'
    }
    if ($borderlessFullscreen) {
        $windowAttributes += 'WindowStyle="None"'
        $windowAttributes += 'ResizeMode="NoResize"'
    }

    if ($iconPath) {
        # WPF wants the absolute path
        $iconPath = (Resolve-Path -Path $iconPath -ErrorAction Stop).Path
        $windowAttributes += "Icon=`"$(Get-XamlSafeString $iconPath)`""
    }

    $xaml = @"
<Window x:Class="WpfApp.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        mc:Ignorable="d"
        Title="$(Get-XamlSafeString $windowTitle)" $($windowAttributes -join ' ')>
    <ScrollViewer Padding="10,0,10,10">
        <Grid>
            <Grid.ColumnDefinitions>
$columnDefinitions
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
$rowDefinitions
            </Grid.RowDefinitions>
$($contentLines -join [Environment]::NewLine)
        </Grid>
    </ScrollViewer>
</Window>
"@

    Write-Verbose 'Creating XAML objects...'
    $form = New-GuiForm -inputXml $xaml

    Write-Verbose "Found $($buttons.Count) buttons"
    Write-Verbose 'Adding click actions...'
    ForEach ($button in $buttons) {
        $button.Add_Click( {
            # Use object in pipeline to identify script to run
            Invoke-ButtonAction $_.Source.Name
        } )
    }

    if ($fullscreen) {
        $form.Add_KeyDown({
            if ($_.Key -eq 'Escape') {
                $_.Handled = $true
                $this.Close()
            }
        })
    }

    if ($hideConsole) {
        if ($global:error[0].Exception.CommandInvocation.MyCommand.ModuleName -ne 'PSScriptMenuGui') {
            # Do not hide console if there have been errors
            Hide-Console | Out-Null
        }
    }

    Write-Verbose 'Showing dialog...'
    $Form.ShowDialog() | Out-Null
}

Function New-ScriptMenuGuiExample {
    <#
    .SYNOPSIS
        Creates an example set of files for PSScriptMenuGui
    .PARAMETER path
        Path of output folder
    .EXAMPLE
        New-ScriptMenuGuiExample -path 'PSScriptMenuGui_example'
    .LINK
        https://github.com/weebsnore/PowerShell-Script-Menu-Gui
    #>
    [CmdletBinding()]
    param (
        [string]$path = 'PSScriptMenuGui_example'
    )

    # Ensure folder exists
    if (-not (Test-Path -Path $path -PathType Container) ) {
        New-Item -Path $path -ItemType 'directory' -Verbose | Out-Null
    }

    Write-Verbose "Copying example files to $path..." -Verbose
    Copy-Item -Path "$moduleRoot\examples\*" -Destination $path
}

Function New-MenuCsvFromScripts {
    <#
    .SYNOPSIS
        Build menu CSV rows from scripts in a folder.
    .PARAMETER Path
        Folder to scan for script files.
    .PARAMETER Recurse
        Scan all subfolders.
    .PARAMETER OutputCsvPath
        Optional output path to write CSV file. Required when -LaunchGui is specified.
    .PARAMETER Append
        Append rows if OutputCsvPath already exists.
    .PARAMETER IncludeExtensions
        File extensions to include. Defaults to .ps1, .cmd and .bat.
    .PARAMETER SectionMap
        Map filename prefixes to section names (case-insensitive prefix match). Longer prefixes
        take priority over shorter ones. Defaults to Get->QUERIES, Add/New->NEW, Set->UPDATE,
        Remove->DELETE.
    .PARAMETER DefaultSection
        Section name used when no SectionMap prefix matches the file name. Defaults to MISC.
    .PARAMETER LaunchGui
        After generating the CSV, call Show-ScriptMenuGui with the generated file.
        Requires -OutputCsvPath to be specified.
    .PARAMETER PassThru
        Return the generated rows to the pipeline even when OutputCsvPath is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$OutputCsvPath,
        [switch]$Recurse,
        [switch]$Append,
        [string[]]$IncludeExtensions = @('.ps1', '.cmd', '.bat'),
        [hashtable]$SectionMap = @{
            'Get'    = 'QUERIES'
            'Add'    = 'NEW'
            'New'    = 'NEW'
            'Set'    = 'UPDATE'
            'Remove' = 'DELETE'
        },
        [string]$DefaultSection = 'MISC',
        [switch]$LaunchGui,
        [switch]$PassThru
    )

    if ($LaunchGui -and -not $OutputCsvPath) {
        throw '-LaunchGui requires -OutputCsvPath to be specified.'
    }

    $resolvedPath = (Resolve-Path -Path $Path -ErrorAction Stop).Path

    $childItemParams = @{
        Path = $resolvedPath
        File = $true
    }
    if ($Recurse) {
        $childItemParams['Recurse'] = $true
    }

    $files = Get-ChildItem @childItemParams | Where-Object { $_.Extension -in $IncludeExtensions } | Sort-Object FullName

    $getBatchDescription = {
        param([string]$filePath)
        foreach ($line in (Get-Content -Path $filePath)) {
            if ($line -match '^\s*(?:REM\s+|::)(.+)$') {
                return $matches[1].Trim()
            }
        }
        return ''
    }
    $rows = foreach ($file in $files) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $section = $DefaultSection
        foreach ($prefix in ($SectionMap.Keys | Sort-Object Length -Descending)) {
            if ($baseName.StartsWith([string]$prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $section = [string]$SectionMap[$prefix]
                break
            }
        }

        switch ($file.Extension.ToLowerInvariant()) {
            '.ps1' {
                $method = 'powershell_file'
                $description = ''
                $raw = Get-Content -Path $file.FullName -Raw
                # Match comment-based help (<# ... #>), capture the text immediately after .SYNOPSIS,
                # and stop before the next help keyword (for example .DESCRIPTION) or the closing #>.
                $synopsisMatch = [regex]::Match($raw, '(?ms)<#.*?\.SYNOPSIS\s*(?<synopsis>.+?)(?:\r?\n\s*\.[A-Z][A-Z0-9_]*|#>)')
                if ($synopsisMatch.Success) {
                    $description = (($synopsisMatch.Groups['synopsis'].Value -split "`r?`n") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1).Trim()
                }
            }
            '.cmd' {
                $method = 'cmd'
                $description = & $getBatchDescription $file.FullName
            }
            '.bat' {
                $method = 'cmd'
                $description = & $getBatchDescription $file.FullName
            }
            default {
                Write-Warning "Skipping '$($file.Name)': extension '$($file.Extension)' is not supported. Supported extensions: .ps1, .cmd, .bat."
                continue
            }
        }

        [PSCustomObject]@{
            Section = $section
            Method = $method
            Command = $file.FullName
            Arguments = ''
            WorkingDirectory = $file.DirectoryName
            RunAsAdmin = 'False'
            Name = $baseName
            Description = $description
        }
    }

    if ($OutputCsvPath) {
        if (Test-Path -Path $OutputCsvPath -PathType Container) {
            throw "OutputCsvPath '$OutputCsvPath' must be a file path, not a directory."
        }

        $outputExists = Test-Path -Path $OutputCsvPath -PathType Leaf
        if ($outputExists -and -not $Append) {
            Remove-Item -Path $OutputCsvPath -Force
            $outputExists = $false
        }

        if ($Append -and $outputExists) {
            $rows | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Append
        }
        else {
            $rows | Export-Csv -Path $OutputCsvPath -NoTypeInformation
        }
    }

    if ($LaunchGui) {
        Show-ScriptMenuGui -csvPath $OutputCsvPath
    }

    if ($PassThru -or -not $OutputCsvPath) {
        return $rows
    }
}
