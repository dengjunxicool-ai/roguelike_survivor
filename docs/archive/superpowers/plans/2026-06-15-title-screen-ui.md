# Title Screen UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a polished dark fantasy 3/4 top-down welcome screen for the roguelike survivor game.

**Architecture:** Keep the implementation isolated inside `TitleScreenController`. The existing `UIManager` state machine remains the owner of screen registration, transitions, and quit handling.

**Tech Stack:** Godot 4 GDScript, generated PNG assets, `TextureRect`, `ColorRect`, `PanelContainer`, `StyleBoxFlat`, existing `LocalizationService`.

---

### Task 1: Generate and Persist the Top-Down Background

**Files:**
- Create: `assets/ui/title/title_screen_topdown_background.png`

- [x] **Step 1: Generate the image**

Use built-in image generation with a 16:9 3/4 top-down dark fantasy dungeon arena prompt. The image must have no text, no characters, no monsters, and no UI.

- [x] **Step 2: Copy the selected output into the project**

Run:

```powershell
$src = Get-ChildItem -Path $env:USERPROFILE\.codex\generated_images -Recurse -Filter *.png | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
Copy-Item -LiteralPath $src -Destination 'assets\ui\title\title_screen_topdown_background.png' -Force
```

Expected: `assets/ui/title/title_screen_topdown_background.png` exists and shows a 3/4 top-down dungeon arena.

### Task 2: Rebuild the Controller Layout

**Files:**
- Modify: `scripts/ui/screens/title_screen_controller.gd`

- [x] **Step 1: Update background asset constants**

Point `TITLE_BACKGROUND_PATH` to `res://assets/ui/title/title_screen_topdown_background.png` and keep the previous generated background plus map art as fallbacks.

- [x] **Step 2: Build background layers**

Create a dark base, full-screen `TextureRect`, readability wash, title shadow, menu shadow, and bottom vignette.

- [x] **Step 3: Build title hierarchy**

Create a left title stack with kicker, title, accent line, subtitle, and press-any-key prompt.

- [x] **Step 4: Build action menu**

Create a right-side `PanelContainer` with menu title and existing action callbacks.

- [x] **Step 5: Apply title-specific button styling**

Use `StyleBoxFlat` normal, hover, pressed, focus, and disabled states with dark gold accents.

- [x] **Step 6: Implement responsive layout**

Compact screens stack title and menu vertically, while desktop screens keep title left and menu right.

### Task 3: Import and Verify

**Files:**
- Test: `tools/check_text_encoding.js`
- Test: `tools/verify_ui_architecture.gd`

- [x] **Step 1: Import the generated asset**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --editor --path . --quit
```

Expected: Godot creates `assets/ui/title/title_screen_topdown_background.png.import`.

- [x] **Step 2: Check text encoding**

Run:

```powershell
node tools\check_text_encoding.js
```

Expected: process exits with code 0.

- [x] **Step 3: Check Godot project load**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --quit
```

Expected: project loads without parse errors.

- [x] **Step 4: Check UI architecture**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_ui_architecture.gd
```

Expected: UI architecture verification passes.
