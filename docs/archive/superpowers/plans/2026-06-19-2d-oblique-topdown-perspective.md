# 2D Oblique Top-Down Perspective Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first shippable slice of the 2D oblique top-down presentation while preserving the current 2D gameplay logic.

**Architecture:** Keep the existing `Camera2D`, `CharacterBody2D`, world coordinates, combat ranges, collision, and UI layers unchanged. Add a focused oblique presentation layer, reusable ground shadows, Y-based visual ordering, and direction-state compatibility so the scene reads closer to the provided reference without converting to 3D.

**Tech Stack:** Godot 4 GDScript, `Node2D`, `Camera2D`, `Sprite2D`, `Polygon2D`, existing scenes under `scenes/`, existing debug scripts under `scripts/debug/`.

---

## File Structure

- Create `scripts/debug/oblique_perspective_check.gd`
  - Focused headless regression check for the oblique top-down presentation. This avoids relying on `visual_config_check.gd`, which currently has unrelated Attack Once trace failures.
- Create `scripts/visual/ground_shadow.gd`
  - Reusable helper for adding a flat ellipse shadow under actors and pickups without changing physics.
- Create `scripts/maps/oblique_presentation.gd`
  - Lightweight procedural scene presentation layer that draws an oblique arena decal and dark edge framing until final map art is available.
- Modify `scenes/main.tscn`
  - Enable Y sorting on the run root and add `ObliquePresentation`.
- Modify `scripts/player/player_controller.gd`
  - Add a ground shadow to the player in `_ready()`.
- Modify `scripts/enemies/enemy_base.gd`
  - Add a ground shadow to every enemy in `_ready()`.
- Modify `scripts/drops/exp_gem.gd`
  - Add a smaller ground shadow to experience crystals in `_ready()`.
- Modify `scripts/combat/projectile.gd`
  - Add a small ground shadow to projectiles when they enter the tree.
- Modify `scripts/visual/visual_config_applier.gd`
  - Expose a public state-availability query for visual controllers.
- Modify `scripts/player/player_visual_controller.gd`
  - Make movement direction selection match oblique top-down readable directions and fall back safely when assets do not have all four states.
- Modify `scripts/enemies/enemy_visual_controller.gd`
  - Make enemy movement direction selection support up/down/left/right states with safe fallback.

## Task 1: Add Focused Oblique Perspective Regression Check

**Files:**
- Create: `scripts/debug/oblique_perspective_check.gd`

- [ ] **Step 1: Write the failing test script**

Create `scripts/debug/oblique_perspective_check.gd`:

```gdscript
extends SceneTree


var _failed: bool = false


func _init() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)


func _run_checks() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_assert(main_scene != null, "main scene loads")
	if main_scene == null:
		_finish()
		return

	var main: Node2D = main_scene.instantiate() as Node2D
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var player: Node2D = main.get_node_or_null("Player") as Node2D
	_assert(player != null, "player exists")
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D if player != null else null
	_assert(camera != null and camera.enabled, "player camera remains enabled")
	_assert(camera != null and is_zero_approx(camera.rotation), "camera is not rotated for oblique 2D presentation")
	_assert(camera != null and camera.zoom.x > 1.0 and camera.zoom.y > 1.0, "camera remains close enough for run exploration")
	_assert(bool(main.get("y_sort_enabled")), "run root enables y sorting for oblique depth")
	_assert(main.get_node_or_null("ObliquePresentation") != null, "run scene has oblique presentation layer")
	_assert(player != null and player.get_node_or_null("GroundShadow") != null, "player has ground shadow")

	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn") as PackedScene
	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	enemy.set("enemy_id", &"small_slime")
	main.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(120.0, 0.0)
	await process_frame
	_assert(enemy.get_node_or_null("GroundShadow") != null, "enemy has ground shadow")

	var gem_scene: PackedScene = load("res://scenes/experience_crystal.tscn") as PackedScene
	var gem: Node2D = gem_scene.instantiate() as Node2D
	main.add_child(gem)
	gem.global_position = player.global_position + Vector2(48.0, 48.0)
	await process_frame
	_assert(gem.get_node_or_null("GroundShadow") != null, "experience crystal has ground shadow")

	var projectile_scene: PackedScene = load("res://scenes/fireball_projectile.tscn") as PackedScene
	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	main.add_child(projectile)
	projectile.global_position = player.global_position + Vector2(96.0, 48.0)
	await process_frame
	_assert(projectile.get_node_or_null("GroundShadow") != null, "projectile has ground shadow")

	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[ObliquePerspectiveCheck] PASS %s" % message)
	else:
		_failed = true
		push_error("[ObliquePerspectiveCheck] FAIL %s" % message)


func _finish() -> void:
	print("[ObliquePerspectiveCheck] done failed=%s" % str(_failed))
	quit(1 if _failed else 0)
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --script scripts/debug/oblique_perspective_check.gd
```

Expected:

- Exit code `1`.
- Fails at least these checks:
  - `run root enables y sorting for oblique depth`
  - `run scene has oblique presentation layer`
  - `player has ground shadow`
  - `enemy has ground shadow`
  - `experience crystal has ground shadow`
  - `projectile has ground shadow`

## Task 2: Add Reusable Ground Shadow Helper

**Files:**
- Create: `scripts/visual/ground_shadow.gd`

- [ ] **Step 1: Create the ground shadow helper**

Create `scripts/visual/ground_shadow.gd`:

```gdscript
extends RefCounted
class_name GroundShadow


const SHADOW_NODE_NAME: String = "GroundShadow"


static func ensure(owner: Node2D, radius: float = 22.0, flatten: float = 0.36, offset: Vector2 = Vector2(0.0, 16.0), alpha: float = 0.42) -> Polygon2D:
	if owner == null:
		return null

	var existing: Polygon2D = owner.get_node_or_null(SHADOW_NODE_NAME) as Polygon2D
	if existing != null:
		_configure(existing, radius, flatten, offset, alpha)
		return existing

	var shadow: Polygon2D = Polygon2D.new()
	shadow.name = SHADOW_NODE_NAME
	owner.add_child(shadow)
	owner.move_child(shadow, 0)
	_configure(shadow, radius, flatten, offset, alpha)
	return shadow


static func _configure(shadow: Polygon2D, radius: float, flatten: float, offset: Vector2, alpha: float) -> void:
	var safe_radius: float = maxf(radius, 1.0)
	var safe_flatten: float = clampf(flatten, 0.08, 1.0)
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(32):
		var angle: float = TAU * float(index) / 32.0
		points.append(Vector2(cos(angle) * safe_radius, sin(angle) * safe_radius * safe_flatten))
	shadow.polygon = points
	shadow.position = offset
	shadow.color = Color(0.0, 0.0, 0.0, clampf(alpha, 0.0, 1.0))
	shadow.z_index = -4
	shadow.show_behind_parent = true
```

- [ ] **Step 2: Run encoding check**

Run:

```powershell
node tools\check_text_encoding.js
```

Expected:

- Exit code `0`.
- Output includes `Encoding check passed`.

## Task 3: Add Shadows to Player, Enemies, Pickups, and Projectiles

**Files:**
- Modify: `scripts/player/player_controller.gd`
- Modify: `scripts/enemies/enemy_base.gd`
- Modify: `scripts/drops/exp_gem.gd`
- Modify: `scripts/combat/projectile.gd`

- [ ] **Step 1: Add helper preload to player**

In `scripts/player/player_controller.gd`, add this preload near the existing preloads:

```gdscript
const GroundShadowScript: Script = preload("res://scripts/visual/ground_shadow.gd")
```

- [ ] **Step 2: Ensure player shadow in `_ready()`**

In `scripts/player/player_controller.gd`, inside `_ready()` after `_visual_controller.call("setup", self)`, add:

```gdscript
	GroundShadowScript.ensure(self, 28.0, 0.34, Vector2(0.0, 18.0), 0.42)
```

- [ ] **Step 3: Add helper preload to enemy**

In `scripts/enemies/enemy_base.gd`, add this preload near the existing preloads:

```gdscript
const GroundShadowScript: Script = preload("res://scripts/visual/ground_shadow.gd")
```

- [ ] **Step 4: Ensure enemy shadow in `_ready()`**

In `scripts/enemies/enemy_base.gd`, inside `_ready()` after `_visual_controller.call("setup", self)`, add:

```gdscript
	GroundShadowScript.ensure(self, 24.0, 0.34, Vector2(0.0, 16.0), 0.38)
```

- [ ] **Step 5: Add helper preload to experience gem**

In `scripts/drops/exp_gem.gd`, add this preload below `class_name ExpGem`:

```gdscript
const GroundShadowScript: Script = preload("res://scripts/visual/ground_shadow.gd")
```

- [ ] **Step 6: Ensure experience gem shadow in `_ready()`**

In `scripts/drops/exp_gem.gd`, inside `_ready()` after `add_to_group(&"experience_crystal")`, add:

```gdscript
	GroundShadowScript.ensure(self, 12.0, 0.32, Vector2(0.0, 10.0), 0.28)
```

- [ ] **Step 7: Add helper preload to projectile**

In `scripts/combat/projectile.gd`, add this preload near the existing preloads:

```gdscript
const GroundShadowScript: Script = preload("res://scripts/visual/ground_shadow.gd")
```

- [ ] **Step 8: Ensure projectile shadow in `_ready()`**

Find or create `_ready()` in `scripts/combat/projectile.gd`. Ensure it contains this line:

```gdscript
	GroundShadowScript.ensure(self, 10.0, 0.30, Vector2(0.0, 10.0), 0.24)
```

If `_ready()` already exists, add the line without removing existing setup.

- [ ] **Step 9: Run the oblique check**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --script scripts/debug/oblique_perspective_check.gd
```

Expected:

- Shadow checks for player, enemy, experience crystal, and projectile pass.
- Scene-level checks for Y sorting and `ObliquePresentation` still fail until Task 4.

## Task 4: Add Oblique Presentation Layer and Y Sorting

**Files:**
- Create: `scripts/maps/oblique_presentation.gd`
- Modify: `scenes/main.tscn`

- [ ] **Step 1: Create oblique presentation script**

Create `scripts/maps/oblique_presentation.gd`:

```gdscript
extends Node2D
class_name ObliquePresentation


@export var arena_radius: Vector2 = Vector2(620.0, 230.0)
@export var center_offset: Vector2 = Vector2(768.0, 512.0)
@export var ring_count: int = 5


func _ready() -> void:
	z_index = -8
	set_process(false)
	queue_redraw()


func _draw() -> void:
	_draw_dark_floor_wash()
	_draw_arena_rings()
	_draw_radial_marks()
	_draw_foreground_edge_framing()


func _draw_dark_floor_wash() -> void:
	draw_rect(Rect2(Vector2(-256.0, -256.0), Vector2(3072.0, 2048.0)), Color(0.015, 0.018, 0.026, 0.62), true)


func _draw_arena_rings() -> void:
	for ring_index in range(ring_count):
		var t: float = float(ring_index + 1) / float(ring_count)
		var radius: Vector2 = arena_radius * t
		var color: Color = Color(0.25, 0.46, 0.66, 0.12 + 0.08 * (1.0 - t))
		_draw_ellipse_polyline(center_offset, radius, color, 2.0)
	_draw_ellipse_fill(center_offset, Vector2(104.0, 38.0), Color(0.42, 0.68, 0.92, 0.16))


func _draw_radial_marks() -> void:
	for index in range(12):
		var angle: float = TAU * float(index) / 12.0
		var inner: Vector2 = center_offset + Vector2(cos(angle) * arena_radius.x * 0.18, sin(angle) * arena_radius.y * 0.18)
		var outer: Vector2 = center_offset + Vector2(cos(angle) * arena_radius.x * 0.94, sin(angle) * arena_radius.y * 0.94)
		draw_line(inner, outer, Color(0.10, 0.22, 0.34, 0.30), 3.0)


func _draw_foreground_edge_framing() -> void:
	draw_rect(Rect2(Vector2(-256.0, 1180.0), Vector2(3072.0, 460.0)), Color(0.0, 0.0, 0.0, 0.52), true)
	draw_rect(Rect2(Vector2(-256.0, -256.0), Vector2(3072.0, 260.0)), Color(0.0, 0.0, 0.0, 0.34), true)
	draw_rect(Rect2(Vector2(-256.0, -256.0), Vector2(320.0, 2048.0)), Color(0.0, 0.0, 0.0, 0.30), true)
	draw_rect(Rect2(Vector2(2496.0, -256.0), Vector2(320.0, 2048.0)), Color(0.0, 0.0, 0.0, 0.30), true)


func _draw_ellipse_fill(center: Vector2, radius: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(64):
		var angle: float = TAU * float(index) / 64.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)


func _draw_ellipse_polyline(center: Vector2, radius: Vector2, color: Color, width: float) -> void:
	var previous: Vector2 = center + Vector2(radius.x, 0.0)
	for index in range(1, 65):
		var angle: float = TAU * float(index) / 64.0
		var current: Vector2 = center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		draw_line(previous, current, color, width)
		previous = current
```

- [ ] **Step 2: Modify `scenes/main.tscn` resources**

Add this ext resource after the existing map script resource:

```ini
[ext_resource type="Script" path="res://scripts/maps/oblique_presentation.gd" id="11_oblique"]
```

- [ ] **Step 3: Enable Y sorting on Main**

In `scenes/main.tscn`, change the `Main` node block to:

```ini
[node name="Main" type="Node2D" unique_id=803732399]
y_sort_enabled = true
```

- [ ] **Step 4: Add ObliquePresentation node**

In `scenes/main.tscn`, add this node after `DungeonBackground`:

```ini
[node name="ObliquePresentation" type="Node2D" parent="." unique_id=120619001]
z_index = -8
script = ExtResource("11_oblique")
```

- [ ] **Step 5: Run the oblique check**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --script scripts/debug/oblique_perspective_check.gd
```

Expected:

- Exit code `0`.
- Output ends with `[ObliquePerspectiveCheck] done failed=false`.

## Task 5: Add Visual State Availability Query and Direction Fallback

**Files:**
- Modify: `scripts/visual/visual_config_applier.gd`
- Modify: `scripts/player/player_visual_controller.gd`
- Modify: `scripts/enemies/enemy_visual_controller.gd`

- [ ] **Step 1: Expose public state availability**

In `scripts/visual/visual_config_applier.gd`, add this public method above `_has_state_visual`:

```gdscript
static func has_state_visual(visual: Dictionary, state: String) -> bool:
	return _has_state_visual(visual, state)
```

- [ ] **Step 2: Replace player direction method**

Replace `get_move_animation_name(direction: Vector2) -> String` in `scripts/player/player_visual_controller.gd` with:

```gdscript
func get_move_animation_name(direction: Vector2) -> String:
	var preferred_state: String = "walk"
	if absf(direction.y) >= absf(direction.x):
		preferred_state = "walk_down" if direction.y > 0.0 else "walk_up"
	else:
		preferred_state = "walk_right" if direction.x > 0.0 else "walk_left"
	return _first_available_state([preferred_state, "walk", "idle"])
```

- [ ] **Step 3: Add player fallback helper**

In `scripts/player/player_visual_controller.gd`, add:

```gdscript
func _first_available_state(states: Array[String]) -> String:
	for state: String in states:
		if VisualConfigApplierScript.has_state_visual(_visual_config, state):
			return state
	return states[0] if not states.is_empty() else "idle"
```

- [ ] **Step 4: Replace enemy movement state method**

Replace `_get_move_state(state: Dictionary) -> String` in `scripts/enemies/enemy_visual_controller.gd` with:

```gdscript
func _get_move_state(state: Dictionary) -> String:
	var direction: Vector2 = state.get("move_direction", Vector2.ZERO) as Vector2
	if direction.length_squared() <= 0.0001:
		return _last_move_state

	var preferred_state: String = "move_right"
	if absf(direction.y) >= absf(direction.x):
		preferred_state = "move_down" if direction.y > 0.0 else "move_up"
	else:
		preferred_state = "move_right" if direction.x > 0.0 else "move_left"
	_last_move_state = _first_available_state([preferred_state, "move_right", "move_left", "idle"])
	return _last_move_state
```

- [ ] **Step 5: Add enemy fallback helper**

In `scripts/enemies/enemy_visual_controller.gd`, add:

```gdscript
func _first_available_state(states: Array[String]) -> String:
	for state: String in states:
		if VisualConfigApplierScript.has_state_visual(_visual_config, state):
			return state
	return states[0] if not states.is_empty() else "idle"
```

- [ ] **Step 6: Run the oblique check**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --script scripts/debug/oblique_perspective_check.gd
```

Expected:

- Exit code `0`.
- Output ends with `[ObliquePerspectiveCheck] done failed=false`.

## Task 6: Preserve Existing Gameplay and Debug Checks

**Files:**
- No new files.

- [ ] **Step 1: Run wave system check**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --script scripts/debug/wave_system_check.gd
```

Expected:

- Exit code `0`.
- Camera checks still pass, including camera zoom and camera limits.

- [ ] **Step 2: Run skill progression check**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --script scripts/debug/skill_progression_check.gd
```

Expected:

- Exit code `0`.
- Output ends with `[SkillProgressionCheck] done failed=false`.

- [ ] **Step 3: Run encoding check**

Run:

```powershell
node tools\check_text_encoding.js
```

Expected:

- Exit code `0`.
- Output includes `Encoding check passed`.

- [ ] **Step 4: Run visual config check and record known unrelated failures**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --script scripts/debug/visual_config_check.gd
```

Expected:

- Existing oblique-related checks should not fail.
- This script may still exit `1` because of pre-existing Attack Once damage trace failures. If it fails only there, report that explicitly.

## Task 7: Manual Visual Verification

**Files:**
- No file changes required.

- [ ] **Step 1: Open the project in Godot**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --editor --path .
```

Expected:

- Godot opens the project.

- [ ] **Step 2: Run the main scene**

Run the main scene from the editor.

Expected:

- The arena reads as a darker oblique top-down scene.
- Player, enemies, projectiles, and experience crystals have visible ground shadows.
- Actor overlap reads better through Y ordering.
- UI remains fixed on top of the game view.

- [ ] **Step 3: Run Developer Mode**

Open Developer Mode from the title flow.

Expected:

- Dev Tool remains usable.
- Debug range overlays still show true gameplay circles.
- Enemy spawn, status application, Skill Cards, and record card controls remain usable.

## Task 8: Version Control or Change Summary

**Files:**
- All files modified during execution.

- [ ] **Step 1: Check whether git is available**

Run:

```powershell
git status --short
```

Expected:

- If this is a git repository, review the changed files.
- If the command reports `fatal: not a git repository`, do not attempt a commit and include a changed-file summary in the final report.

- [ ] **Step 2: Commit if git is available**

Run only if `git status --short` succeeds:

```powershell
git add scripts/debug/oblique_perspective_check.gd scripts/visual/ground_shadow.gd scripts/maps/oblique_presentation.gd scenes/main.tscn scripts/player/player_controller.gd scripts/enemies/enemy_base.gd scripts/drops/exp_gem.gd scripts/combat/projectile.gd scripts/visual/visual_config_applier.gd scripts/player/player_visual_controller.gd scripts/enemies/enemy_visual_controller.gd
git commit -m "feat: add 2d oblique top-down presentation"
```

Expected:

- Commit succeeds if git is available.
- If git is unavailable, final response lists changed files and verification results.

---

## Self-Review

Spec coverage:

- Visual-only oblique top-down migration: covered by Tasks 2-5 and Task 7.
- No 3D conversion and no camera/world rotation: covered by Task 1 camera assertions and Task 4 scene changes.
- Preserve combat math, collision, targeting, enemy AI distances, and debug truth: covered by Task 6 checks and by not touching gameplay systems.
- Staged implementation with temporary first-stage visuals: covered by Task 4 procedural presentation layer and Task 7 manual verification.
- Debug overlays remain truthful: covered by Task 6 visual config check and Task 7 Developer Mode verification.

Placeholder scan:

- No `TODO` or `TBD` markers are used.
- All code-creation steps include concrete code.
- Commands and expected outputs are explicit.

Type consistency:

- `GroundShadow.ensure(...)` is defined in Task 2 and used in Task 3.
- `VisualConfigApplier.has_state_visual(...)` is defined in Task 5 before controller fallback helpers call it.
- `ObliquePresentation` is defined in Task 4 before `scenes/main.tscn` references it.
