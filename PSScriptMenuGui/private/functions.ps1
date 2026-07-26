function Hide-Console {
    Write-Verbose 'Hiding PowerShell console...'
    # .NET method for hiding the PowerShell console window
    # https://stackoverflow.com/questions/40617800/opening-powershell-script-and-hide-command-prompt-but-not-the-gui
    Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
    '
    $consolePtr = [Console.Window]::GetConsoleWindow()
    [Console.Window]::ShowWindow($consolePtr, 0) # 0 = hide
}

Function New-GuiHeading {
    param(
        [Parameter(Mandatory)][string]$name,
        [Parameter(Mandatory)][int]$row,
        [Parameter(Mandatory)][int]$column,
        [Parameter(Mandatory)][int]$columnSpan
    )

    return "            <TextBlock Text=`"$(Get-XamlSafeString $name)`" TextWrapping=`"Wrap`" Grid.Row=`"$row`" Grid.Column=`"$column`" Grid.ColumnSpan=`"$columnSpan`" FontSize=`"25`" Padding=`"5,10,0,5`" />"
}

Function New-GuiRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject]$item,
        [Parameter(Mandatory)][int]$row,
        [Parameter(Mandatory)][int]$buttonColumn,
        [Parameter(Mandatory)][int]$descriptionColumn,
        [Parameter(Mandatory)][int]$buttonWidth,
        [Parameter(Mandatory)][int]$buttonHeight,
        [Parameter(Mandatory)][string]$buttonBackgroundColor,
        [Parameter(Mandatory)][string]$buttonForegroundColor
    )

    $safeName = Get-XamlSafeString $item.Name
    $safeDescription = ''
    if (-not [string]::IsNullOrWhiteSpace($item.Description)) {
        $safeDescription = Get-XamlSafeString $item.Description
    }

    return @(
"            <Button x:Name=`"$($item.Reference)`" Grid.Row=`"$row`" Grid.Column=`"$buttonColumn`" Background=`"$buttonBackgroundColor`" Foreground=`"$buttonForegroundColor`" Width=`"$buttonWidth`" MinHeight=`"$buttonHeight`" VerticalAlignment=`"Top`" Padding=`"10`" Margin=`"0,5,0,5`" >",
"                <TextBlock TextWrapping=`"Wrap`" TextAlignment=`"Center`">$safeName</TextBlock>",
'            </Button>',
"            <TextBlock TextWrapping=`"Wrap`" Grid.Row=`"$row`" Grid.Column=`"$descriptionColumn`" Padding=`"10,5,0,5`" VerticalAlignment=`"Center`">$safeDescription</TextBlock>"
    )
}

Function Get-XamlSafeString {
    param(
        [AllowEmptyString()][string]$string
    )
    if ($null -eq $string) {
        $string = ''
    }

    # https://docs.microsoft.com/en-us/dotnet/framework/wpf/advanced/how-to-use-special-characters-in-xaml
    # Order matters: &amp first
    $string = $string.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
    # Restore line breaks
    $string = $string -replace '&lt;\s*?LineBreak\s*?\/\s*?&gt;','<LineBreak />'

    return $string
}

Function New-GuiForm {
    # Based on: https://foxdeploy.com/2015/05/14/part-iii-using-advanced-gui-elements-in-powershell/
    param (
        [Parameter(Mandatory)][array]$inputXml # XML has not been converted to object yet
    )
    # Process raw XML
    $inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*','<Window'

    # Read XAML
    [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
    [xml]$xaml = $inputXML
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    try {
        $form = [Windows.Markup.XamlReader]::Load($reader)
    }
    catch {
        Write-Warning "Unable to parse XML!
Ensure that there are NO SelectionChanged or TextChanged properties in your textboxes (PowerShell cannot process them).
Note that this module does not currently work with PowerShell 7-preview and the VS Code integrated console."
        throw
    }

    # Load XAML button objects in PowerShell
    $script:buttons = @()
    $xaml.SelectNodes("//*[@Name]") | ForEach-Object {
        try {
            $script:buttons += $Form.FindName($_.Name)
        }
        catch {
            throw
        }
    }

    return $form
}

Function Invoke-ButtonAction {
    param(
        [Parameter(Mandatory)][string]$buttonName
    )
    Write-Verbose "$buttonName clicked"

    # Get relevant CSV row
    $csvMatch = $csvData | Where-Object {$_.Reference -eq $buttonName}
    Write-Verbose $csvMatch

    # Pipe match to Start-Script function
    # Lets us check CSV data via parameter validation
    try {
        $csvMatch | Start-Script -ErrorAction Stop
    }
    catch {
        Write-Error $_
    }
}

Function Get-LogicalBoolean {
    param(
        [AllowNull()][AllowEmptyString()][object]$Value
    )

    if ($null -eq $Value) {
        return $false
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $false
    }

    switch -Regex ($text.Trim()) {
        '^(?i:true|1|yes|y)$' { return $true }
        '^(?i:false|0|no|n)$' { return $false }
        default { throw "Invalid boolean value '$Value'. Valid values: true/false, yes/no, y/n, 1/0." }
    }
}

Function Resolve-MenuWorkingDirectory {
    param(
        [AllowNull()][AllowEmptyString()][string]$WorkingDirectory
    )

    if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        return $null
    }

    try {
        return (Resolve-Path -Path $WorkingDirectory -ErrorAction Stop).Path
    }
    catch {
        throw "WorkingDirectory '$WorkingDirectory' was not found."
    }
}

Function Get-LayoutPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][array]$csvData,
        [Parameter(Mandatory)][ValidateSet('Stacked','Grid','ColumnPerGroup')][string]$groupLayout,
        [Parameter()][int]$columns,
        [Parameter()][int]$rows,
        [Parameter()][int]$buttonWidth = 150,
        [Parameter()][int]$buttonHeight = 50
    )

    $elements = @()
    $buttonColumnWidth = [string]$buttonWidth
    $columnWidths = @($buttonColumnWidth,'*')
    $rowCount = 0

    $orderedSectionsList = [System.Collections.Generic.List[string]]::new()
    $seenSections = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($row in $csvData) {
        if ([string]::IsNullOrWhiteSpace($row.Section)) {
            continue
        }

        $normalizedSection = $row.Section.Trim()
        if ($seenSections.Add($normalizedSection)) {
            [void]$orderedSectionsList.Add($normalizedSection)
        }
    }
    $orderedSections = $orderedSectionsList.ToArray()

    $blankSectionItems = @($csvData | Where-Object { [string]::IsNullOrWhiteSpace($_.Section) })

    switch ($groupLayout) {
        'Stacked' {
            $currentRow = 0
            foreach ($section in $orderedSections) {
                $elements += [PSCustomObject]@{ Type='Heading'; Name=$section; Row=$currentRow; ButtonColumn=0; DescriptionColumn=1; ColumnSpan=2 }
                $currentRow++
                foreach ($item in ($csvData | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Section) -and $_.Section.Trim() -eq $section })) {
                    $elements += [PSCustomObject]@{ Type='Item'; Item=$item; Row=$currentRow; ButtonColumn=0; DescriptionColumn=1; ColumnSpan=1 }
                    $currentRow++
                }
            }
            foreach ($item in $blankSectionItems) {
                $elements += [PSCustomObject]@{ Type='Item'; Item=$item; Row=$currentRow; ButtonColumn=0; DescriptionColumn=1; ColumnSpan=1 }
                $currentRow++
            }
            $rowCount = [Math]::Max($currentRow,1)
        }
        'Grid' {
            $sortedData = $csvData | Sort-Object @{Expression={ if ([string]::IsNullOrWhiteSpace($_.Section)) { 1 } else { 0 } }}, @{Expression={ if ([string]::IsNullOrWhiteSpace($_.Section)) { '' } else { $_.Section.Trim() } }}, Name, Command

            $itemCount = [Math]::Max($sortedData.Count,1)
            $gridColumns = 0
            $sectionCounts = @()
            foreach ($section in ($orderedSections + @(''))) {
                if ([string]::IsNullOrWhiteSpace($section)) {
                    $sectionItems = @($sortedData | Where-Object { [string]::IsNullOrWhiteSpace($_.Section) })
                    if ($sectionItems.Count -gt 0) {
                        $sectionCounts += [PSCustomObject]@{ HasHeading = $false; Count = $sectionItems.Count }
                    }
                }
                else {
                    $sectionItems = @($sortedData | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Section) -and $_.Section.Trim() -eq $section })
                    if ($sectionItems.Count -gt 0) {
                        $sectionCounts += [PSCustomObject]@{ HasHeading = $true; Count = $sectionItems.Count }
                    }
                }
            }

            # Calculate total rows needed for a given Grid column count
            # (includes section heading rows + distributed item rows).
            $getRowsForColumns = {
                param([int]$columnCount)

                if ($columnCount -lt 1) {
                    throw "Invalid column count for Grid layout calculation: $columnCount (must be at least 1)."
                }

                $totalRows = 0
                foreach ($sectionCount in $sectionCounts) {
                    if ($sectionCount.HasHeading) {
                        $totalRows++
                    }
                    $totalRows += [Math]::Ceiling($sectionCount.Count / $columnCount)
                }

                if ($totalRows -lt 1) {
                    return 1
                }

                return $totalRows
            }

            if ($rows -gt 0) {
                if ($columns -gt 0) {
                    $gridColumns = $columns
                    $calculatedRows = & $getRowsForColumns $gridColumns
                    if ($calculatedRows -gt $rows) {
                        throw "Rows/Columns combination cannot fit this menu in Grid layout (required rows: $calculatedRows, requested rows: $rows, columns: $columns). Use a larger -rows value or a smaller -columns value."
                    }
                }
                else {
                    $left = 1
                    $right = $itemCount
                    $bestColumns = 0

                    while ($left -le $right) {
                        $candidateColumns = [int][Math]::Floor(($left + $right) / 2)
                        $candidateRows = & $getRowsForColumns $candidateColumns

                        if ($candidateRows -le $rows) {
                            $bestColumns = $candidateColumns
                            $right = $candidateColumns - 1
                        }
                        else {
                            $left = $candidateColumns + 1
                        }
                    }

                    if ($bestColumns -gt 0) {
                        $gridColumns = $bestColumns
                    }
                    else {
                        $gridColumns = $itemCount
                    }
                }
            }
            elseif ($columns -gt 0) {
                $gridColumns = $columns
            }
            else {
                $gridColumns = 2
            }
            $gridColumns = [Math]::Max($gridColumns,1)

            $columnWidths = @()
            for ($i = 0; $i -lt $gridColumns; $i++) {
                $columnWidths += $buttonColumnWidth
                $columnWidths += '*'
            }

            $currentRow = 0
            foreach ($section in ($orderedSections + @(''))) {
                if ([string]::IsNullOrWhiteSpace($section)) {
                    $sectionItems = @($sortedData | Where-Object { [string]::IsNullOrWhiteSpace($_.Section) })
                }
                else {
                    $sectionItems = @($sortedData | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Section) -and $_.Section.Trim() -eq $section })
                }
                if ($sectionItems.Count -eq 0) {
                    continue
                }

                if (-not [string]::IsNullOrWhiteSpace($section)) {
                    $elements += [PSCustomObject]@{ Type='Heading'; Name=$section; Row=$currentRow; ButtonColumn=0; DescriptionColumn=1; ColumnSpan=($gridColumns * 2) }
                    $currentRow++
                }

                for ($i = 0; $i -lt $sectionItems.Count; $i++) {
                    $itemRow = $currentRow + [Math]::Floor($i / $gridColumns)
                    $buttonColumn = ($i % $gridColumns) * 2
                    $elements += [PSCustomObject]@{ Type='Item'; Item=$sectionItems[$i]; Row=$itemRow; ButtonColumn=$buttonColumn; DescriptionColumn=($buttonColumn + 1); ColumnSpan=1 }
                }

                $currentRow += [Math]::Ceiling($sectionItems.Count / $gridColumns)
            }

            $rowCount = [Math]::Max($currentRow,1)
        }
        'ColumnPerGroup' {
            $sectionBlocks = @()
            foreach ($section in $orderedSections) {
                $sectionBlocks += [PSCustomObject]@{
                    Name = $section
                    Items = @($csvData | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Section) -and $_.Section.Trim() -eq $section } | Sort-Object Name, Command)
                }
            }
            if ($blankSectionItems.Count -gt 0) {
                $sectionBlocks += [PSCustomObject]@{ Name='Other'; Items=($blankSectionItems | Sort-Object Name, Command) }
            }
            if ($sectionBlocks.Count -eq 0) {
                $sectionBlocks += [PSCustomObject]@{ Name='Items'; Items=@($csvData | Sort-Object Name, Command) }
            }

            $columnWidths = @()
            for ($i = 0; $i -lt $sectionBlocks.Count; $i++) {
                $columnWidths += $buttonColumnWidth
                $columnWidths += '*'
            }

            $maxRowsPerSection = 0
            for ($i = 0; $i -lt $sectionBlocks.Count; $i++) {
                $buttonColumn = $i * 2
                $section = $sectionBlocks[$i]
                $elements += [PSCustomObject]@{ Type='Heading'; Name=$section.Name; Row=0; ButtonColumn=$buttonColumn; DescriptionColumn=($buttonColumn + 1); ColumnSpan=2 }
                for ($j = 0; $j -lt $section.Items.Count; $j++) {
                    $elements += [PSCustomObject]@{ Type='Item'; Item=$section.Items[$j]; Row=($j + 1); ButtonColumn=$buttonColumn; DescriptionColumn=($buttonColumn + 1); ColumnSpan=1 }
                }
                if ($section.Items.Count -gt $maxRowsPerSection) {
                    $maxRowsPerSection = $section.Items.Count
                }
            }

            $rowCount = [Math]::Max(($maxRowsPerSection + 1),1)
        }
    }

    return [PSCustomObject]@{
        Elements = $elements
        ColumnWidths = $columnWidths
        RowCount = $rowCount
    }
}

Function Start-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [ValidateSet('cmd','powershell_file','powershell_inline','pwsh_file','pwsh_inline')]
        [string]$method,

        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][string]$command,

        [Parameter(ValueFromPipelineByPropertyName)][string]$arguments,

        [Parameter(ValueFromPipelineByPropertyName)][string]$workingDirectory,

        [Parameter(ValueFromPipelineByPropertyName)][object]$runAsAdmin
    )

    if ([string]::IsNullOrWhiteSpace($command)) {
        throw 'Command must not be empty.'
    }

    $startProcessParams = @{
        Verbose = $verbose
    }

    $resolvedWorkingDirectory = Resolve-MenuWorkingDirectory -WorkingDirectory $workingDirectory
    if ($resolvedWorkingDirectory) {
        $startProcessParams['WorkingDirectory'] = $resolvedWorkingDirectory
    }

    if (Get-LogicalBoolean -Value $runAsAdmin) {
        $startProcessParams['Verb'] = 'RunAs'
    }

    # Handle cmd first
    if ($method -eq 'cmd') {
        $startProcessParams['FilePath'] = $command
        if (-not [string]::IsNullOrWhiteSpace($arguments)) {
            $startProcessParams['ArgumentList'] = $arguments
        }
        Start-Process @startProcessParams
        return
    }

    # Set Start-Process params according to CSV method
    $splitMethod = $method.Split('_')
    switch ($splitMethod[0]) {
        powershell {
            $filePath = 'powershell.exe'
        }
        pwsh {
            $filePath = 'pwsh.exe'
        }
    }

    $processArguments = '-ExecutionPolicy Bypass -NoLogo'
    if ($noExit) {
        $processArguments += ' -NoExit'
    }

    switch ($splitMethod[1]) {
        file {
            $processArguments += " -File `"$command`""
            if (-not [string]::IsNullOrWhiteSpace($arguments)) {
                $processArguments += " $arguments"
            }
        }
        inline {
            $encodedCommand = [Convert]::ToBase64String( [System.Text.Encoding]::Unicode.GetBytes($command) )
            $processArguments += " -EncodedCommand `"$encodedCommand`""
            if (-not [string]::IsNullOrWhiteSpace($arguments)) {
                $processArguments += " $arguments"
            }
        }
    }

    $startProcessParams['FilePath'] = $filePath
    $startProcessParams['ArgumentList'] = $processArguments

    # Launch process
    Write-Verbose $processArguments
    Start-Process @startProcessParams
}
