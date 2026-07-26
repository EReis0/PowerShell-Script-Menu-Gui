# PowerShell-Script-Menu-Gui — Issue Resolution Plan

This document provides a practical, phased plan to address the current open issues:

- #1 Enhancements (auto-build CSV from scripts, metadata extraction)
- #2 More parameters to customize items (layout controls)
- #3 Scripts with multiple parameters
- #4 Additional functionality (fullscreen mode, grid layout)

---

## 1) Goals

1. Improve usability for non-technical users by reducing manual CSV authoring.
2. Expand layout and UI customization without breaking existing configs.
3. Support real-world command invocation (multi-parameter scripts).
4. Keep backward compatibility with existing CSV files and usage patterns.

---

## 2) Design Principles

- **Backward compatible by default**: existing CSV and commands should continue to work.
- **Opt-in features**: new behavior enabled via optional parameters/settings.
- **Small, testable increments**: ship in phases with validation examples.
- **Clear documentation first-class**: every feature includes sample CSV + usage docs.

---

## 3) Proposed Delivery Phases

## Phase 0 — Baseline & Refactor Prep ✅ COMPLETE

### Tasks
- [x] Map current execution flow:
  - CSV parsing
  - button/control creation
  - command execution
  - form sizing/layout logic
- [x] Isolate responsibilities into helper functions if currently monolithic.
- [x] Add a lightweight "internal model" object for menu entries so feature additions do not directly couple to raw CSV rows.

### Deliverables
- [x] Internal notes in code comments.
- [x] Minimal refactor PR (no behavior change).

### Success criteria
- [x] Existing sample CSV works exactly as before.

### Progress note
Completed. Code is organized into `public/functions.ps1` (exported functions: `Show-ScriptMenuGui`, `New-ScriptMenuGuiExample`, `New-MenuCsvFromScripts`) and `private/functions.ps1` (internal helpers: `Hide-Console`, `New-GuiHeading`, `New-GuiRow`, `Get-XamlSafeString`, `New-GuiForm`, `Invoke-ButtonAction`, `Get-LogicalBoolean`, `Resolve-MenuWorkingDirectory`, `Get-LayoutPlan`, `Start-Script`). Layout elements and CSV rows are represented as `PSCustomObject` instances with explicit named properties, decoupling downstream functions from raw CSV column access. Execution flow documented via a header comment block in `public/functions.ps1`.

---

## Phase 1 — Multiple Parameters Support (Issue #3) ✅ COMPLETE

### Problem
Users need commands like:

`checkup.ps1 -patchowner "My Name" -showpatches`

Current model appears to be constrained for simple script paths/arguments.

### Implementation plan
1. **CSV schema extension (non-breaking):**
   - Keep existing `Command` field as primary launch string.
   - Add optional fields:
     - `Arguments` (raw argument string)
     - `WorkingDirectory` (optional)
     - `RunAsAdmin` (optional bool)
2. **Execution logic:**
   - If `Arguments` exists, launch `Command` + parsed arguments.
   - If absent, preserve existing behavior.
3. **Quoting strategy:**
   - Document recommended quoting in CSV for strings/spaces.
   - Prefer `Start-Process` with explicit argument handling where possible.
4. **Validation:**
   - Add sample entries for `.ps1`, `.cmd`, `.bat` with multiple arguments.

### Deliverables
- [x] Updated command execution function (`Start-Script` in `private/functions.ps1` accepts `Arguments`, `WorkingDirectory`, `RunAsAdmin` via pipeline from CSV row).
- [x] Example CSV section "Scripts with multiple parameters" (`examples/csv/multi-args.csv`).
- [x] README update with do/don't examples around quoting.

### Success criteria
- [x] Multiple examples with spaces/flags/switches across `example_data.csv` (9 rows) and `multi-args.csv` (3 rows with spaces and quoted values) run correctly.

### Progress note
Completed. `Start-Script` accepts `Arguments` (appended to the process argument list), `WorkingDirectory` (resolved via `Resolve-MenuWorkingDirectory`), and `RunAsAdmin` (interpreted via `Get-LogicalBoolean`). Backward compatible: rows without these columns are unaffected. `examples/csv/multi-args.csv` demonstrates `.ps1`, `.cmd`, and `.bat` with quoted values and spaces. README quoting guidance added.

---

## Phase 2 — Layout Customization Controls (Issue #2 + part of #4 grid) ✅ COMPLETE

### Problem
Users want control over:
- number of lines,
- button width/height,
- number of columns,
- grouping by column.

### Implementation plan
1. **Add optional cmdlet parameters** (or configuration object):
   - `-Columns <int>`
   - `-Rows <int>` (or auto-calc if omitted)
   - `-ButtonWidth <int>`
   - `-ButtonHeight <int>`
   - `-GroupLayout <string>` (e.g., `Stacked`, `ColumnPerGroup`, `Grid`)
2. **Layout engine abstraction:**
   - Introduce function like `Get-MenuItemCoordinates` to separate layout math from control creation.
3. **Grid layout mode:**
   - Provide deterministic ordering (by section, then label/command).
4. **Constraints & defaults:**
   - Guardrails for min/max values.
   - Preserve current auto-layout when params are not provided.

### Deliverables
- [x] New parameters and validation (`-columns 0–10`, `-rows 0–200`, `-buttonWidth 80–600`, `-buttonHeight 25–300`, `-groupLayout Stacked|Grid|ColumnPerGroup`).
- [x] Grid/column layout implementation (`Get-LayoutPlan` in `private/functions.ps1` handles all three modes).
- [x] Before/after visuals in docs (README visual section).

### Success criteria
- [x] Users can explicitly control size/shape of menu and reproduce consistent layouts.

### Progress note
Completed. `Show-ScriptMenuGui` accepts `-columns`, `-rows`, `-buttonWidth`, `-buttonHeight`, and `-groupLayout`. `Get-LayoutPlan` (private) implements `Stacked` (legacy default), `Grid` (multi-column with deterministic sort and binary-search row-target logic), and `ColumnPerGroup` (one column per section). Guardrails throw on out-of-range values. `examples/csv/grid-layout.csv` demonstrates multi-section grid usage. README now includes a dedicated before/after visual section for layout modes.

---

## Phase 3 — Fullscreen Mode + UI Behavior Improvements (Issue #4) ✅ COMPLETE

### Implementation plan
1. Add optional switch `-Fullscreen`.
2. Fullscreen behavior:
   - maximize form,
   - remove borders optionally (`-BorderlessFullscreen` optional),
   - maintain ESC key to close (if safe and desired),
   - preserve keyboard navigation.
3. Ensure controls reflow correctly under high resolution and DPI scaling.

### Deliverables
- [x] Fullscreen mode implementation (`-fullscreen` sets `WindowState="Maximized"`, `-borderlessFullscreen` adds `WindowStyle="None" ResizeMode="NoResize"`; `-borderlessFullscreen` requires `-fullscreen`).
- [x] Accessibility notes: ESC key closes the window in fullscreen mode (documented in README). Tab/keyboard navigation is handled natively by WPF.

### Success criteria
- [x] App can switch into fullscreen and remain usable with large menus (`ScrollViewer` wraps the grid, so large menus remain scrollable in all modes).

### Progress note
Completed. `-fullscreen` switch maximizes the WPF window. `-borderlessFullscreen` removes the window chrome. ESC key handler is wired via `Add_KeyDown` on the form when fullscreen is active. `ScrollViewer` ensures large menus are accessible in all screen sizes.

---

## Phase 4 — Auto-Build CSV from Script Folder (Issue #1) ✅ COMPLETE

### Problem
Users want automatic menu generation from script directory contents.

### Implementation plan
1. **New helper command/function** (recommended):
   - `New-MenuCsvFromScripts`
2. **Discovery input:**
   - `-Path` (folder containing scripts)
   - `-Recurse` (optional)
   - supported extensions: `.ps1`, `.cmd`, `.bat`
3. **Metadata extraction rules:**
   - **Section** from filename prefixes map (configurable), e.g.:
     - `Get* -> QUERIES`
     - `Add* -> NEW`
   - **Method** from extension:
     - `.ps1 -> PowerShell`
     - `.cmd/.bat -> Command`
   - **Command** from file name/path.
   - **Description**:
     - `.ps1`: parse comment-based help `.SYNOPSIS`
     - `.cmd/.bat`: first comment line fallback
4. **Output options:**
   - `-OutputCsvPath`
   - `-Append` / overwrite behavior
   - `-SectionMap @{ 'Get'='QUERIES'; 'Add'='NEW' }`
5. **Integration path:**
   - Step A: generate CSV only.
   - Step B: optional pipeline into `Show-MenuGui`.

### Deliverables
- [x] New function + examples (`New-MenuCsvFromScripts` in `public/functions.ps1`, exported from module manifest).
- [x] Sample "main script" demonstrating end-to-end generation and launch (`examples/scripts/Generate-MenuAndLaunch.ps1`).

### Success criteria
- [x] User can point to a scripts folder and get a valid menu CSV with minimal manual edits.

### Progress note
Completed. `New-MenuCsvFromScripts` scans a folder (with optional `-Recurse`) for `.ps1`, `.cmd`, `.bat` files, extracts `.SYNOPSIS` from comment-based help for `.ps1` files and the first `REM`/`::` comment for batch files, applies `-SectionMap` prefix matching (longest-prefix-first), and writes a full-schema CSV (Section, Method, Command, Arguments, WorkingDirectory, RunAsAdmin, Name, Description). `-Append` and `-PassThru` are supported. `examples/scripts/Generate-MenuAndLaunch.ps1` shows end-to-end generation and launch with grid layout.

---

## Phase 5 — Automated Pester Coverage (post-vNext hardening) ✅ COMPLETE

### Problem
Manual-only validation is increasingly costly as the feature surface grows.

### Implementation plan
1. Add a lightweight Pester test suite focused on non-UI logic that runs cross-platform.
2. Cover core CSV generation behavior (`New-MenuCsvFromScripts`) including:
   - metadata extraction,
   - section prefix mapping,
   - CSV write/append behavior,
   - error handling for invalid output path usage.
3. Document a repeatable local test command.

### Deliverables
- [x] Pester tests added under `tests/` for `New-MenuCsvFromScripts`.
- [x] README updated with automated test instructions.

### Success criteria
- [x] Tests execute successfully with `Invoke-Pester` and validate CSV generation behavior.

### Progress note
Completed. Added `tests/New-MenuCsvFromScripts.Tests.ps1` with focused coverage for script discovery, `.SYNOPSIS`/batch comment extraction, longest-prefix section mapping, CSV append behavior, and output path validation.

---

## 4) Documentation Plan (critical) ✅ COMPLETE

For each phase, update:
1. README feature section.
2. Parameter reference table.
3. One "quick start" example.
4. One "advanced" example.
5. Troubleshooting section (quoting, path errors, execution policy).

Add a dedicated `examples/` folder:
- `examples/csv/basic.csv`
- `examples/csv/multi-args.csv`
- `examples/csv/grid-layout.csv`
- `examples/scripts/Generate-MenuAndLaunch.ps1`

### Progress note
Completed. README has parameter reference table, quoting guidance, layout examples, fullscreen examples, auto-build CSV example, and a troubleshooting section. All four example files exist in the `examples/` folder at the repository root.

---

## 5) Testing Strategy

### Manual test matrix
- PowerShell versions (Windows PowerShell 5.1, PowerShell 7+).
- Script types (`.ps1`, `.cmd`, `.bat`).
- Path edge cases (spaces, unicode, long paths).
- Argument patterns (quoted strings, switches, key-value).
- Small and large menu sizes (10, 50, 200 items).
- Display scenarios (normal, high DPI, fullscreen).

### Regression checks
- Existing sample CSV behavior unchanged.
- Existing command-only rows still execute.

### Automated checks ✅ COMPLETE
- Run `Invoke-Pester -Path .\tests` from the repository root.
- Current automated coverage targets CSV auto-generation behavior in `New-MenuCsvFromScripts`.

---

## 6) Suggested Issue-to-Phase Mapping

- **Issue #3** → Phase 1 (high priority / quick user impact)
- **Issue #2** → Phase 2 (layout controls)
- **Issue #4** → Phase 2 + Phase 3 (grid + fullscreen)
- **Issue #1** → Phase 4 (largest feature; highest complexity)

---

## 7) Proposed Milestones

### Milestone A (vNext-1) ✅ COMPLETE
- Phase 1 complete
- Docs + examples for multiple parameters

### Milestone B (vNext-2) ✅ COMPLETE
- Phase 2 complete
- Grid layout + customization params

### Milestone C (vNext-3) ✅ COMPLETE
- Phase 3 complete
- Fullscreen support

### Milestone D (vNext-4) ✅ COMPLETE
- Phase 4 complete
- Auto CSV generation tooling + walkthrough

---

## 8) Risks and Mitigations

1. **Argument parsing/quoting bugs**
   - Mitigation: strict examples, centralized launcher helper, broad test cases.
2. **Layout regressions across resolutions**
   - Mitigation: separate layout engine + fallback defaults.
3. **Script metadata extraction inconsistencies**
   - Mitigation: best-effort extraction with clear fallback values and warnings.
4. **Feature creep**
   - Mitigation: phase gates and acceptance criteria per issue.

---

## 9) Definition of Done (per issue)

- Feature implemented behind compatible defaults.
- At least one sample demonstrating real use.
- README updated.
- Issue comment drafted with usage snippet and limitations.
- No regressions in existing behavior.

---

## 10) Recommended Next Step

~~Start with **Issue #3** (multiple parameters), because it has high user value, low-to-medium implementation complexity, and establishes robust execution plumbing needed by later features.~~

All planned phases are now complete. Next follow-up work should focus on:
- Publishing an updated module version to the PowerShell Gallery.

## Issue #1 – Enhancements (Auto-build CSV + Samples) — Remaining Work Plan

### Goal
Deliver an optional workflow that can automatically discover scripts in a folder, generate a Menu GUI CSV, and optionally launch `Show-MenuGui`.  
This enhancement should be **best-effort and configurable**, without breaking existing CSV-driven usage.

---

### Scope

#### 1) New helper command: auto-build CSV from scripts
Add a new public function (proposed name):
- `New-MenuCsvFromScripts`

Proposed parameters:
- `-ScriptsPath <string>` (required): root folder to scan
- `-OutputCsvPath <string>` (required): destination CSV path
- `-IncludeExtensions <string[]>` (optional, default: `@('.ps1','.cmd','.bat')`)
- `-SectionMap <hashtable>` (optional): maps filename prefix/pattern to Section name
- `-DefaultSection <string>` (optional, default: `"MISC"`)
- `-Recurse` (switch): recurse into subfolders
- `-LaunchGui` (switch): call `Show-MenuGui` after CSV generation
- `-PassThru` (switch): return generated objects in pipeline
- `-WhatIf` / `-Confirm` support (if feasible with existing command style)

Out of scope for this issue:
- Fullscreen mode / advanced layout engine
- Replacing `Show-MenuGui` input model
- Hard dependency on naming conventions

---

#### 2) Script discovery and filtering
Implementation requirements:
- Enumerate files in `-ScriptsPath` using allowed extensions
- Skip non-matching extensions
- Handle inaccessible/unreadable files with warnings (no hard stop unless path invalid)
- Deterministic ordering (e.g., by directory then name) to produce stable CSV output

Acceptance criteria:
- Given a folder with mixed files, only configured extensions are included
- Invalid path returns clear terminating error
- Unreadable file emits warning and processing continues

---

#### 3) CSV field auto-completion rules

##### 3.1 Section
Rule:
- Derive Section from file name prefix using `-SectionMap`
- Example default mapping (documented, user-overridable):
  - `Get*` => `QUERIES`
  - `Add*`/`New*` => `NEW`
  - `Set*` => `UPDATE`
  - `Remove*` => `DELETE`
- If no match: `-DefaultSection`

Acceptance criteria:
- Prefix mapping is case-insensitive
- User-provided `-SectionMap` overrides default behavior
- No match safely falls back to default section

##### 3.2 Method
Rule:
- Derive from extension:
  - `.ps1` => `PowerShell`
  - `.cmd` => `CMD`
  - `.bat` => `BAT`
- Allow future extension map customization (optional backlog item; not required now)

Acceptance criteria:
- Every generated row has non-empty Method value
- Unknown extension is excluded unless explicitly allowed

##### 3.3 Command
Rule:
- Use base filename (without extension), removing recognized verb/prefix token when present
- Example:
  - `Get-Users.ps1` => `Users`
  - `Add-LocalAdmin.cmd` => `LocalAdmin`
- If no known prefix token found, keep full base name

Acceptance criteria:
- Command is human-readable and non-empty
- Prefix stripping is conservative (never returns empty string)

##### 3.4 Description
Rule:
- `.ps1`: extract `.SYNOPSIS` from comment-based help when available
- `.cmd`/`.bat`: read first comment line (`REM ...` or `:: ...`) where available
- Fallback: empty string or configured fallback text

Acceptance criteria:
- Missing help/comment does not fail generation
- Description extraction is best-effort with warnings only for malformed edge cases (non-blocking)

---

#### 4) CSV writing and compatibility
Implementation requirements:
- Emit CSV schema compatible with existing `Show-MenuGui` expectations
- Use explicit encoding and delimiter strategy consistent with repository standards
- Overwrite behavior must be explicit (document whether overwrite is default or guarded)

Acceptance criteria:
- Generated CSV can be consumed directly by current `Show-MenuGui`
- Sample-generated CSV launches menu without manual edits

---

#### 5) Optional launch flow
If `-LaunchGui` is specified:
1. Generate and save CSV
2. Invoke `Show-MenuGui` with generated CSV path
3. Surface invocation errors clearly

Acceptance criteria:
- Without `-LaunchGui`, command only generates CSV
- With `-LaunchGui`, end-to-end flow works from a single command

---

### Documentation & Samples (required to close issue #1)

#### 6) README updates
Add a new section: **“Auto-build menu from script folder”**
Must include:
- Prerequisites and conventions:
  - Naming conventions improve Section/Command quality
  - `.SYNOPSIS`/comment usage improves Description quality
- Minimal example
- Advanced example with custom `-SectionMap`
- Notes on fallbacks and warning behavior

#### 7) New sample script
Add an end-to-end sample file (proposed):
- `examples/Build-And-Show-MenuGui.ps1`

Sample flow:
1. Set scripts folder
2. Build CSV automatically
3. Launch GUI
4. Demonstrate optional custom SectionMap

---

### Tests

#### 8) Unit tests
Add tests for:
- Section mapping logic (default + custom)
- Command derivation (prefix stripping + fallback)
- Method mapping by extension
- Description extraction for:
  - `.ps1` with and without `.SYNOPSIS`
  - `.cmd/.bat` with and without comment line

#### 9) Integration test
Fixture directory with representative scripts; validate:
- CSV is created
- Row count matches discovered scripts
- Required columns are present
- Generated CSV can be passed to `Show-MenuGui` (mock or non-interactive check if needed)

---

### Implementation safeguards / reasons to avoid overreach
These are **constraints**, not blockers:
- Heuristics are inherently imperfect; must remain overridable and non-fatal
- Do not hardcode one naming convention as mandatory
- Keep helper command optional to preserve backward compatibility

Conclusion:
- No reason to reject the feature set in issue #1
- Implement as optional, configurable, best-effort workflow

---

### Closure checklist for Issue #1
- [ ] `New-MenuCsvFromScripts` (or equivalent) implemented
- [ ] Auto-completion for Section/Method/Command/Description implemented
- [ ] Supports `.ps1`, `.cmd`, `.bat`
- [ ] CSV output is compatible with `Show-MenuGui`
- [ ] `-LaunchGui` optional end-to-end flow works
- [ ] README section added with prerequisites and examples
- [ ] Sample script added
- [ ] Unit + integration tests added
- [ ] Issue #1 validated against acceptance criteria and closed
