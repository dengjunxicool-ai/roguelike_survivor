# Debug Combat Trace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Draw fireball explosion ranges at the actual explosion site in developer mode, keep them until cleared, and show the damage breakdown for one manual attack in the Dev Debug Tool.

**Architecture:** Runtime combat remains authoritative. `SkillActionExecutor` records explosion site data when it actually spawns an explosion, and enemy damage application records real `DamageResult` data after the existing calculation pipeline. `DevDebugPanel` starts a trace for "Attack Once", reads trace records, and clears site overlays on demand.

**Tech Stack:** Godot 4.6 GDScript, existing debug panel, existing skill/action/damage runtime, existing headless `visual_config_check.gd`.

---

### Task 1: Regression Coverage

**Files:**
- Modify: `scripts/debug/visual_config_check.gd`

- [ ] **Step 1: Write failing assertions**

Add a visual check path that opens developer mode, applies the fireball burst branch, spawns a target, clicks/calls the new attack-once entry, waits for projectile impact, and asserts:

```gdscript
_assert(root.has_meta("debug_combat_trace_records"), "dev debug attack once records damage entries")
_assert(main.find_child("DebugExplosionSiteOverlay*", true, false) != null, "dev debug leaves explosion site overlay")
_assert(String(debug_panel.get("_last_attack_damage_text")).find("Damage Breakdown") >= 0, "dev debug panel displays attack damage breakdown")
```

- [ ] **Step 2: Run failing check**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://scripts/debug/visual_config_check.gd
```

Expected before implementation: fails because `_attack_once_player_skills`, trace records, and explosion site overlay do not exist.

### Task 2: Debug Trace Recorder

**Files:**
- Create: `scripts/debug/debug_explosion_site_overlay.gd`
- Create: `scripts/debug/debug_combat_trace.gd`

- [ ] **Step 1: Implement persistent explosion overlay**

Create a `Node2D` script that stores `radius`, draws an orange ring, labels `skill_id` and radius, and remains at `global_position` until queued for deletion.

- [ ] **Step 2: Implement trace recorder static API**

Create static methods:

```gdscript
begin_attack_trace(root: Node) -> int
current_attack_trace_id(root: Node) -> int
record_explosion(root: Node, parent: Node, position: Vector2, radius: float, skill_id: String, source_instance_id: String) -> void
record_damage(root: Node, target: Node, amount_or_packet: Variant, damage_result: Dictionary, final_amount: int) -> void
clear(root: Node) -> int
get_records(root: Node) -> Array
```

The recorder stores records in `root` metadata and creates/removes `DebugExplosionSiteOverlay` nodes under the current scene.

### Task 3: Runtime Hooks

**Files:**
- Modify: `scripts/skills/skill_action_executor.gd`
- Modify: `scripts/combat/projectile.gd`
- Modify: `scripts/combat/application_stages/enemy_health_application_stage.gd`

- [ ] **Step 1: Propagate trace id**

When attack trace is active, copy `debug_attack_trace_id` into spawned projectiles, projectile hit event context, and damage packets built by `SkillActionExecutor`.

- [ ] **Step 2: Record explosion site**

In `_spawn_area`, after resolving actual explosion `position` and `radius`, call `DebugCombatTrace.record_explosion(...)` only for `source_type == "explosion"` and only in developer/debug trace mode.

- [ ] **Step 3: Record damage result**

After enemy health application receives `damage_result` and `final_amount`, call `DebugCombatTrace.record_damage(...)` when the source packet carries the current trace id.

### Task 4: Dev Tool UI

**Files:**
- Modify: `scripts/debug/dev_debug_panel.gd`

- [ ] **Step 1: Add buttons and label**

In the Runtime page, add `Attack Once` and `Clear Attack Trace` buttons. Add a small autowrapped label that displays the latest attack damage breakdown.

- [ ] **Step 2: Implement attack once**

`Attack Once` calls the trace recorder to begin a new trace, temporarily disables debug control mode like the existing manual attack does, calls runtime `debug_cast_all_skills()`, then refreshes the damage label.

- [ ] **Step 3: Implement clear**

`Clear Attack Trace` removes all persistent explosion overlays and clears trace records and the damage label.

### Task 5: Verification

**Files:**
- Modify: `scripts/debug/visual_config_check.gd`

- [ ] **Step 1: Update assertions to exact method/label names**

Use the implemented methods and assert records, overlay, clear behavior, and label content.

- [ ] **Step 2: Run verification**

Run:

```powershell
node tools\check_text_encoding.js
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://scripts/debug/visual_config_check.gd
```

Expected: encoding passes; visual check exits 0 with `done failed=false`.
