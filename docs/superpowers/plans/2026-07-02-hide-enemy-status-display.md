# Hide Enemy Status Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop showing abnormal status indicators on enemies while keeping status gameplay effects active.

**Architecture:** Keep `StatusEffectManager` and enemy status APIs unchanged. Disable only the enemy-owned visual display paths: `StatusLabel` creation/update and status-driven enemy visual state selection.

**Tech Stack:** Godot 4.6 GDScript, headless SceneTree verification.

---

### Task 1: Add Focused Verification

**Files:**
- Create: `tools/verify/verify_enemy_status_display_hidden.gd`

- [ ] **Step 1: Write the failing test**

Create a headless script that instantiates an enemy, applies `burning`, calls the runtime tick, and asserts:
- the status stack remains active;
- no visible `StatusLabel` appears on the enemy;
- `_get_priority_status_visual_state()` returns an empty string.

- [ ] **Step 2: Run the test to verify it fails**

Run:
```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_enemy_status_display_hidden.gd
```

Expected: FAIL because current code creates a visible `StatusLabel` and reports a non-empty status visual state.

### Task 2: Disable Enemy Status Visuals

**Files:**
- Modify: `scripts/enemies/enemy_status_display_controller.gd`
- Modify: `scripts/enemies/enemy_base.gd`
- Test: `tools/verify/verify_enemy_status_display_hidden.gd`

- [ ] **Step 1: Make `EnemyStatusDisplayController.update()` hide existing labels and avoid creating labels**

Update the controller so any existing `StatusLabel` is cleared and hidden, then returns without building fragments or creating a new label.

- [ ] **Step 2: Stop status state from driving enemy visuals**

Change `EnemyBase._get_priority_status_visual_state()` to return an empty string. This keeps active statuses available through `has_status()` and `get_status_stack()`, but prevents `EnemyVisualController` from selecting `burn`, `freeze`, `poison`, `bleed`, or `slow` states.

- [ ] **Step 3: Run focused verification**

Run:
```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_enemy_status_display_hidden.gd
```

Expected: PASS.

- [ ] **Step 4: Run a relevant status runtime check**

Run:
```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_burn_status_runtime_scene.gd
```

Expected: PASS, showing status mechanics still work.
