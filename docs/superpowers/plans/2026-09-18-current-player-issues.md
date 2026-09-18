# Current Player-Visible Issues Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair the eight confirmed player-visible combat, responsive-UI, input, and result-cache defects without changing unrelated gameplay or desktop presentation.

**Architecture:** Keep each fix inside its current owner: Player owns dash lifecycle, the area builder owns opt-in filter parameters, screen controllers own responsive orientation, the HUD controller owns design-space scaling, UIManager owns pause routing, and the result service owns cache lifetime. Every task starts with a focused regression that fails against the current working tree, then applies the smallest production change required.

**Tech Stack:** Godot 4.6.3, GDScript, JSON gameplay configuration, Node.js validation helpers.

**Spec:** `docs/superpowers/specs/2026-09-18-current-player-issues-design.md`

## Global Constraints

- Preserve all pre-existing staged and unstaged changes; never reset, overwrite, or reformat unrelated code.
- Do not modify gameplay numbers, skill descriptions, save data, or desktop layouts except where the approved specification requires it.
- Run Godot runtime checks outside the restricted sandbox because sandboxed Godot startup produces an environmental signal-11 crash.
- A regression must be observed failing for the intended reason before its production code is changed.
- Dormant `radiance`, generic modal flow, and unrelated stale verification scripts remain out of scope.

---

### Task 1: Emit a Complete Dash Lifecycle

**Files:**
- Modify: `tools/verify/verify_player_dash.gd`
- Modify: `scripts/player/player_controller.gd:382-399`

**Interfaces:**
- Consumes: `Player._emit_dash_skill_event(event_name: StringName)` and the existing `SkillEventBus`.
- Produces: exactly one `dash_end` event when `_dash_time_remaining` crosses from positive to zero.

- [ ] **Step 1: Extend the runtime regression**

Add a recording subscriber in `verify_player_dash.gd` and assert this sequence for one completed dash:

```gdscript
_expect(recorded_events.count(&"dash_start") == 1, "dash emits one start event")
_expect(recorded_events.count(&"dash_tick") >= 1, "dash emits tick events while active")
_expect(recorded_events.count(&"dash_end") == 1, "dash emits one end event")
player.call("_physics_process", 0.1)
_expect(recorded_events.count(&"dash_end") == 1, "idle frames do not repeat dash end")
```

- [ ] **Step 2: Run the regression and verify RED**

Run:

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/verify/verify_player_dash.gd
```

Expected: exit 1 because `dash_end` count is zero.

- [ ] **Step 3: Implement the minimal lifecycle transition**

Capture whether the dash was active before decrementing its timer. After the final dash movement is applied, emit `dash_end` only when the previous state was active and the new state is inactive. Keep collision-exception cleanup in the same transition block.

- [ ] **Step 4: Verify GREEN**

Run the same command and require exit 0 with `verify_player_dash: PASS`.

### Task 2: Make Dash-Path Area Filtering Explicit

**Files:**
- Create: `tools/verify/verify_dash_area_path_filter.gd`
- Modify: `scripts/skills/skill_action_area_builder.gd:20-55`
- Modify only if an intended path-shaped action exists: `data/skills/skills.json`

**Interfaces:**
- Consumes: `SkillActionAreaBuilder.build_effect_spawn_params(input: Dictionary) -> Dictionary`.
- Produces: `dash_path_filter=false` unless `area_params.dash_path_filter` is explicitly true.

- [ ] **Step 1: Write the builder regression**

The new verification must build parameters with dash context twice:

```gdscript
var radial := SkillActionAreaBuilderScript.build_effect_spawn_params({
    "params": {"radius": 80.0},
    "context": {"dash_path_start": Vector2.ZERO, "dash_path_end": Vector2.RIGHT * 120.0}
})
_expect(not bool(radial.get("dash_path_filter", false)), "radial dash area does not inherit path filtering")

var path_area := SkillActionAreaBuilderScript.build_effect_spawn_params({
    "params": {"radius": 80.0, "dash_path_filter": true},
    "context": {"dash_path_start": Vector2.ZERO, "dash_path_end": Vector2.RIGHT * 120.0}
})
_expect(bool(path_area.get("dash_path_filter", false)), "explicit path filtering is preserved")
```

- [ ] **Step 2: Run the regression and verify RED**

Expected: the radial assertion fails because current code enables filtering from context alone.

- [ ] **Step 3: Implement explicit opt-in**

Read the flag from the action/area parameters and only attach dash endpoints when opt-in is true. Do not add opt-in to the start/end chaos rifts.

- [ ] **Step 4: Verify GREEN and run related area checks**

Run the new regression plus `verify_area_effect_motion.gd` and `verify_scorching_vortex_area_behavior.gd`.

### Task 3: Make Character and Map Selection Responsive

**Files:**
- Modify: `tools/verify/verify_character_select_ui.gd`
- Modify: `tools/verify/verify_map_select_ui.gd`
- Modify: `scripts/ui/screens/character_loadout_controller.gd`
- Modify: `scripts/ui/screens/map_select_controller.gd`

**Interfaces:**
- Consumes: each controller's existing `update_layout(viewport_size: Vector2)`.
- Produces: horizontal desktop layout and vertical compact layout with panel widths no larger than available content width.

- [ ] **Step 1: Add compact-layout assertions**

Name the content rows so the verifiers can locate them. At `Vector2(720, 720)` for character selection and `Vector2(720, 720)` for map selection, assert that the row is vertical and each major panel's minimum width is within the viewport. At `Vector2(1280, 720)`, assert the row is horizontal.

- [ ] **Step 2: Run both checks and verify RED**

Expected: current HBox rows cannot switch orientation and compact panel widths exceed the available width.

- [ ] **Step 3: Implement orientation switching**

Use `BoxContainer` with its `vertical` property. Preserve current desktop constants. In compact mode set vertical orientation, set each panel's minimum width to zero or the calculated available width, and retain the existing vertical ScrollContainer.

- [ ] **Step 4: Verify GREEN**

Run `verify_character_select_ui.gd` and `verify_map_select_ui.gd`; require both exit 0.

### Task 4: Keep the Combat HUD Inside Narrow Viewports

**Files:**
- Modify: `tools/verify/verify_run_hud_skill_slots.gd`
- Modify: `scripts/ui/hud/run_hud_controller.gd:313-340`

**Interfaces:**
- Consumes: registered design-space `Rect2` layout items.
- Produces: a uniform fixed-HUD scale and scaled anchor positioning based on viewport width.

- [ ] **Step 1: Add visual-bounds regressions**

Build the HUD, invoke layout for desktop, 720px, and 360px widths, then assert:

```gdscript
_expect(_visual_rect(skill_bar).position.x >= 0.0, "skill bar left edge is visible", _visual_rect(skill_bar))
_expect(_visual_rect(skill_bar).end.x <= viewport_width, "skill bar right edge is visible", _visual_rect(skill_bar))
_expect(_visual_rect(player_panel).end.x <= viewport_width, "player panel fits compact viewport", _visual_rect(player_panel))
```

Desktop scale must remain `Vector2.ONE`.

- [ ] **Step 2: Run and verify RED**

Expected: 720px skill-bar bounds and 360px player-panel bounds exceed the viewport.

- [ ] **Step 3: Implement design-space scaling**

Calculate a width-derived scale for fixed HUD groups, apply it to the control, and anchor using `rect.size * scale`. Clamp to the approved readable lower bound. Do not remove slots or labels.

- [ ] **Step 4: Verify GREEN**

Run `verify_run_hud_skill_slots.gd` and require all existing composition assertions plus new bounds assertions to pass.

### Task 5: Make the Minimal Title Layout Reachable

**Files:**
- Modify: `tools/verify/verify_title_screen_runtime.gd`
- Modify: `scripts/ui/screens/title_screen_controller.gd`

**Interfaces:**
- Consumes: `TitleScreenController.update_layout(viewport_size)` and current title/menu controls.
- Produces: positive, in-bounds action-menu geometry at 320×240, with vertical scrolling when actions exceed available height.

- [ ] **Step 1: Add the 320×240 regression**

Invoke the controller layout at exactly `Vector2(320, 240)` and assert menu width/height are positive, its top is non-negative, its bottom does not exceed 240, and the last action can be reached through its ScrollContainer.

- [ ] **Step 2: Run and verify RED**

Expected: current menu height is `-12` and its top is outside the viewport.

- [ ] **Step 3: Add a bounded scroll host**

Wrap or host the action list in a vertical ScrollContainer. Clamp compact menu height to available viewport space and position it inside the viewport. Keep desktop geometry unchanged.

- [ ] **Step 4: Verify GREEN**

Run `verify_title_screen_runtime.gd` and `verify_title_screen_font.gd`.

### Task 6: Add Standard Pause Input and Button Focus

**Files:**
- Create: `tools/verify/verify_pause_input_runtime.gd`
- Modify: `scripts/ui/ui_manager.gd:148-151`
- Modify: `scripts/ui/hud/run_hud_controller.gd:131-143`

**Interfaces:**
- Consumes: Godot's `ui_cancel` input action and existing UI state transitions.
- Produces: `RUNNING -> PAUSE_MENU` and `PAUSE_MENU -> RUNNING` from one standard action.

- [ ] **Step 1: Write the runtime input regression**

Instantiate the app, start a run through the existing controller flow, dispatch an `InputEventAction` for `ui_cancel`, and assert both pause and resume transitions. Also assert the pause button uses `Control.FOCUS_ALL`.

- [ ] **Step 2: Run and verify RED**

Expected: state remains `RUNNING` and the pause button reports `FOCUS_NONE`.

- [ ] **Step 3: Implement standard input handling**

Handle pressed, non-echo `ui_cancel` events in `UIManager._input`. Transition only for RUNNING and PAUSE_MENU, then mark the viewport input handled. Change the pause button to `FOCUS_ALL`.

- [ ] **Step 4: Verify GREEN**

Run the new pause regression and the title/runtime UI checks.

### Task 7: Reset Result Unlock Cache Per Run

**Files:**
- Create: `tools/verify/verify_result_unlock_cache_lifetime.gd`
- Modify: `scripts/ui/result_unlock_service.gd`
- Modify: `scripts/ui/screens/result_screen_controller.gd`
- Modify: `scripts/ui/ui_manager.gd:585-600`

**Interfaces:**
- Produces: `ResultUnlockService.reset_for_new_run() -> void` and `ResultScreenController.reset_for_new_run() -> void`.
- Consumes: UIManager's existing run initialization path.

- [ ] **Step 1: Write the cache-lifetime regression**

Seed one result-key cache entry, verify a same-run repeat returns it, call `reset_for_new_run`, then verify the cache no longer contains the key. Also verify the controller exposes and delegates the reset method.

- [ ] **Step 2: Run and verify RED**

Expected: reset methods do not exist and the stale entry remains.

- [ ] **Step 3: Implement the reset chain**

Add the two reset methods and invoke the controller reset once while `_start_run` initializes a new run. Do not clear during result-screen refresh.

- [ ] **Step 4: Verify GREEN**

Run the new regression and `verify_result_screen_diagnostic_call.js`.

### Task 8: Integrated Regression and Real-Window Flow

**Files:**
- Modify only if required by verified regressions: `package.json` to register newly created checks.

**Interfaces:**
- Consumes all repaired systems.
- Produces verification evidence; no new runtime behavior.

- [ ] **Step 1: Register focused verification commands**

Add `verify:*` entries for new scripts without renaming existing commands.

- [ ] **Step 2: Run all focused checks**

Run Tasks 1-7 checks individually and confirm zero failures.

- [ ] **Step 3: Run configuration validators**

```powershell
node tools/validate/check_text_encoding.js
node tools/validate/validate_enemy_configs.js
node tools/validate/validate_modifier_effects.js
```

- [ ] **Step 4: Run relevant gameplay/UI coverage**

Run title, character select, map select, HUD, player dash, area effects, result-screen, and coverage-report checks. Report unrelated pre-existing failures separately.

- [ ] **Step 5: Run normal-window full-flow autoplay**

```powershell
D:\Godot\Godot_v4.6.3-stable_win64_console.exe --path . res://scenes/app/full_flow_autoplay.tscn
```

Require successful title/select/map/run transitions, combat kills and level-ups, a terminal result or clean 90-second completion, exit 0, and no GDScript errors.

- [ ] **Step 6: Review the final diff**

Confirm only scoped production files, focused verification files, `package.json`, and approved documentation changed. Do not commit or include unrelated existing worktree changes.
