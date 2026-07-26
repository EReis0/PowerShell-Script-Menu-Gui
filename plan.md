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

## Phase 0 — Baseline & Refactor Prep

### Tasks
- Map current execution flow:
  - CSV parsing
  - button/control creation
  - command execution
  - form sizing/layout logic
- Isolate responsibilities into helper functions if currently monolithic.
- Add a lightweight “internal model” object for menu entries so feature additions do not directly couple to raw CSV rows.

### Deliverables
- Internal notes in code comments.
- Minimal refactor PR (no behavior change).

### Success criteria
- Existing sample CSV works exactly as before.

---

## Phase 1 — Multiple Parameters Support (Issue #3)

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
- Updated command execution function.
- Example CSV section “Scripts with multiple parameters”.
- README update with do/don’t examples around quoting.

### Success criteria
- At least 5 tested command examples with spaces/flags/switches run correctly.

---

## Phase 2 — Layout Customization Controls (Issue #2 + part of #4 grid)

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
- New parameters and validation.
- Grid/column layout implementation.
- Before/after screenshots in docs.

### Success criteria
- Users can explicitly control size/shape of menu and reproduce consistent layouts.

---

## Phase 3 — Fullscreen Mode + UI Behavior Improvements (Issue #4)

### Implementation plan
1. Add optional switch `-Fullscreen`.
2. Fullscreen behavior:
   - maximize form,
   - remove borders optionally (`-BorderlessFullscreen` optional),
   - maintain ESC key to close (if safe and desired),
   - preserve keyboard navigation.
3. Ensure controls reflow correctly under high resolution and DPI scaling.

### Deliverables
- Fullscreen mode implementation.
- Accessibility notes (focus order/tab behavior).

### Success criteria
- App can switch into fullscreen and remain usable with large menus.

---

## Phase 4 — Auto-Build CSV from Script Folder (Issue #1)

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
- New function + examples.
- Sample “main script” demonstrating end-to-end generation and launch.

### Success criteria
- User can point to a scripts folder and get a valid menu CSV with minimal manual edits.

---

## 4) Documentation Plan (critical)

For each phase, update:
1. README feature section.
2. Parameter reference table.
3. One “quick start” example.
4. One “advanced” example.
5. Troubleshooting section (quoting, path errors, execution policy).

Add a dedicated `examples/` folder:
- `examples/csv/basic.csv`
- `examples/csv/multi-args.csv`
- `examples/csv/grid-layout.csv`
- `examples/scripts/Generate-MenuAndLaunch.ps1`

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

---

## 6) Suggested Issue-to-Phase Mapping

- **Issue #3** → Phase 1 (high priority / quick user impact)
- **Issue #2** → Phase 2 (layout controls)
- **Issue #4** → Phase 2 + Phase 3 (grid + fullscreen)
- **Issue #1** → Phase 4 (largest feature; highest complexity)

---

## 7) Proposed Milestones

### Milestone A (vNext-1)
- Phase 1 complete
- Docs + examples for multiple parameters

### Milestone B (vNext-2)
- Phase 2 complete
- Grid layout + customization params

### Milestone C (vNext-3)
- Phase 3 complete
- Fullscreen support

### Milestone D (vNext-4)
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

Start with **Issue #3** (multiple parameters), because it has high user value, low-to-medium implementation complexity, and establishes robust execution plumbing needed by later features.
