# Fire Tornado Debug VFX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a developer-mode-only `Fire Tornado` button that spawns a self-cleaning particle VFX scene near the player.

**Architecture:** The VFX is a standalone `Node2D` scene with layered `CPUParticles2D` children configured by `FireTornadoEffect`. `DevDebugPanel` owns the debug-only spawn path and positions the effect 96 pixels toward the nearest enemy, falling back to the player's right side. No combat data, skills, damage, or area-effect behavior change.

**Tech Stack:** Godot 4 GDScript, `.tscn` scenes, `CPUParticles2D`, Node-based verification scripts.

---

## File Structure

- Create `scripts/effects/fire_tornado_effect.gd`: self-contained visual controller for lifetime, fade, emitter setup, and spiral motion.
- Create `scenes/effects/fire_tornado_effect.tscn`: scene with `Node2D` root, heat core draw node, and named `CPUParticles2D` emitters.
- Modify `scripts/debug/dev_debug_panel.gd`: preload the fire tornado scene, add a `Fire Tornado` utility button, spawn and position the scene.
- Create `tools/verify_fire_tornado_debug_vfx.js`: static verification for the scene, script, and debug-panel wiring.
- Modify `tools/validate_weapon_authoring_pipeline.js`: include the new verification in the existing validation pipeline.

The workspace is not a git repository, so commit steps are replaced with explicit `git rev-parse --is-inside-work-tree` checks that are expected to fail with `fatal: not a git repository`.

---

### Task 1: Add Failing Verification

**Files:**
- Create: `tools/verify_fire_tornado_debug_vfx.js`
- Modify: `tools/validate_weapon_authoring_pipeline.js`

- [ ] **Step 1: Write the failing verification script**

Create `tools/verify_fire_tornado_debug_vfx.js` with this content:

```javascript
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readText(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function main() {
  const scenePath = path.join(root, "scenes/effects/fire_tornado_effect.tscn");
  const scriptPath = path.join(root, "scripts/effects/fire_tornado_effect.gd");
  assert(fs.existsSync(scenePath), "fire tornado effect scene must exist");
  assert(fs.existsSync(scriptPath), "fire tornado effect script must exist");

  const scene = readText("scenes/effects/fire_tornado_effect.tscn");
  assert(scene.includes('path="res://scripts/effects/fire_tornado_effect.gd"'), "scene must attach FireTornadoEffect script");
  assert(scene.includes('name="FireTornadoEffect" type="Node2D"'), "scene root must be a Node2D named FireTornadoEffect");
  for (const nodeName of ["HeatCore", "BaseFireRing", "SpiralEmitterA", "SpiralEmitterB", "EmberSpray"]) {
    assert(scene.includes(`name="${nodeName}"`), `scene must include ${nodeName}`);
  }
  assert((scene.match(/type="CPUParticles2D"/g) || []).length >= 4, "scene must use at least four CPUParticles2D nodes");

  const script = readText("scripts/effects/fire_tornado_effect.gd");
  assert(script.includes("class_name FireTornadoEffect"), "script must declare FireTornadoEffect");
  assert(script.includes("@export_range(0.1, 30.0"), "script must expose a bounded lifetime export");
  assert(script.includes("func _process(delta: float) -> void:"), "script must animate and expire in _process");
  assert(script.includes("queue_free()"), "script must auto-clean with queue_free");
  assert(script.includes("_configure_particles("), "script must configure particle emitters");
  assert(script.includes("_update_spiral_emitters("), "script must animate spiral emitter positions");

  const debugPanel = readText("scripts/debug/dev_debug_panel.gd");
  assert(debugPanel.includes("FIRE_TORNADO_EFFECT_SCENE"), "debug panel must preload the fire tornado scene");
  assert(debugPanel.includes('"Fire Tornado"'), "debug panel must expose a Fire Tornado button");
  assert(debugPanel.includes("func _spawn_fire_tornado_effect() -> void:"), "debug panel must implement fire tornado spawning");
  assert(debugPanel.includes("func _resolve_fire_tornado_spawn_position(player: Node2D) -> Vector2:"), "debug panel must resolve spawn position");
  assert(debugPanel.includes("_get_nearest_enemy()"), "spawn position must use nearest enemy direction when available");

  console.log("Fire tornado debug VFX verified.");
}

main();
```

- [ ] **Step 2: Run the new verification to verify it fails**

Run:

```powershell
node tools\verify_fire_tornado_debug_vfx.js
```

Expected: FAIL with `fire tornado effect scene must exist`.

- [ ] **Step 3: Add the verification to the pipeline**

Modify `tools/validate_weapon_authoring_pipeline.js` by adding this entry after `["weapon attack visuals", "tools/verify_weapon_attack_visuals.js"],`:

```javascript
  ["fire tornado debug VFX", "tools/verify_fire_tornado_debug_vfx.js"],
```

- [ ] **Step 4: Run the full static pipeline to verify the new check fails through the pipeline**

Run:

```powershell
node tools\validate_weapon_authoring_pipeline.js
```

Expected: FAIL in the `fire tornado debug VFX` section with `fire tornado effect scene must exist`.

- [ ] **Step 5: Commit checkpoint**

Run:

```powershell
git rev-parse --is-inside-work-tree
```

Expected in this workspace: `fatal: not a git repository`. Do not attempt a commit.

---

### Task 2: Create the Particle VFX Scene

**Files:**
- Create: `scripts/effects/fire_tornado_effect.gd`
- Create: `scenes/effects/fire_tornado_effect.tscn`
- Test: `tools/verify_fire_tornado_debug_vfx.js`

- [ ] **Step 1: Create the effect script**

Create `scripts/effects/fire_tornado_effect.gd` with this content:

```gdscript
extends Node2D
class_name FireTornadoEffect


@export_range(0.1, 30.0, 0.1, "or_greater") var lifetime: float = 2.5
@export_range(0.1, 10.0, 0.1, "or_greater") var fade_out_time: float = 0.55
@export_range(0.1, 20.0, 0.1, "or_greater") var spin_speed: float = 7.2
@export_range(1.0, 220.0, 1.0, "or_greater") var base_radius: float = 54.0
@export_range(1.0, 220.0, 1.0, "or_greater") var column_height: float = 118.0

var _age: float = 0.0
var _base_modulate: Color = Color.WHITE

@onready var _heat_core: Node2D = get_node_or_null("HeatCore") as Node2D
@onready var _base_fire_ring: CPUParticles2D = get_node_or_null("BaseFireRing") as CPUParticles2D
@onready var _spiral_a: CPUParticles2D = get_node_or_null("SpiralEmitterA") as CPUParticles2D
@onready var _spiral_b: CPUParticles2D = get_node_or_null("SpiralEmitterB") as CPUParticles2D
@onready var _ember_spray: CPUParticles2D = get_node_or_null("EmberSpray") as CPUParticles2D


func _ready() -> void:
	_base_modulate = modulate
	_configure_particles(_base_fire_ring, 96, 0.72, Color(1.0, 0.22, 0.04, 0.78), 28.0, 96.0, 360.0)
	_configure_particles(_spiral_a, 64, 0.58, Color(1.0, 0.48, 0.06, 0.86), 42.0, 124.0, 48.0)
	_configure_particles(_spiral_b, 64, 0.58, Color(1.0, 0.78, 0.16, 0.72), 36.0, 112.0, 48.0)
	_configure_particles(_ember_spray, 72, 0.95, Color(1.0, 0.68, 0.20, 0.68), 72.0, 168.0, 360.0)
	_restart_particles()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	_update_spiral_emitters(_age)
	_update_fade()
	queue_redraw()
	if _age >= lifetime:
		queue_free()


func _draw() -> void:
	var fade: float = _get_fade_alpha()
	var pulse: float = 0.5 + 0.5 * sin(_age * 9.0)
	draw_circle(Vector2.ZERO, base_radius * (0.54 + pulse * 0.05), Color(1.0, 0.32, 0.04, 0.20 * fade))
	draw_circle(Vector2(0.0, -column_height * 0.42), base_radius * (0.28 + pulse * 0.035), Color(1.0, 0.78, 0.20, 0.16 * fade))
	draw_arc(Vector2.ZERO, base_radius * (0.86 + pulse * 0.03), 0.0, TAU, 96, Color(1.0, 0.72, 0.12, 0.58 * fade), 2.2, true)


func _configure_particles(particles: CPUParticles2D, amount: int, particle_lifetime: float, color: Color, velocity_min: float, velocity_max: float, spread: float) -> void:
	if particles == null:
		return
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = particle_lifetime
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.72
	particles.local_coords = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = base_radius * 0.16
	particles.direction = Vector2.UP
	particles.spread = spread
	particles.gravity = Vector2(0.0, -18.0)
	particles.initial_velocity_min = velocity_min
	particles.initial_velocity_max = velocity_max
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	particles.scale_amount_min = 1.8
	particles.scale_amount_max = 4.8
	particles.color = color


func _restart_particles() -> void:
	for particles: CPUParticles2D in [_base_fire_ring, _spiral_a, _spiral_b, _ember_spray]:
		if particles == null:
			continue
		particles.restart()
		particles.emitting = true


func _update_spiral_emitters(age: float) -> void:
	_position_spiral_emitter(_spiral_a, age, 0.0)
	_position_spiral_emitter(_spiral_b, age, PI)
	if _ember_spray != null:
		_ember_spray.rotation = age * spin_speed * 0.55


func _position_spiral_emitter(particles: CPUParticles2D, age: float, phase: float) -> void:
	if particles == null:
		return
	var cycle: float = fposmod(age * 0.78 + phase / TAU, 1.0)
	var angle: float = age * spin_speed + phase
	var radius: float = lerpf(base_radius * 0.54, base_radius * 0.18, cycle)
	particles.position = Vector2(cos(angle), sin(angle) * 0.38) * radius + Vector2(0.0, -column_height * cycle)
	particles.rotation = angle + PI * 0.5


func _update_fade() -> void:
	var fade: float = _get_fade_alpha()
	modulate = Color(_base_modulate.r, _base_modulate.g, _base_modulate.b, _base_modulate.a * fade)
	if _heat_core != null:
		_heat_core.modulate = Color(1.0, 1.0, 1.0, fade)


func _get_fade_alpha() -> float:
	if fade_out_time <= 0.0:
		return 1.0
	var remaining: float = lifetime - _age
	if remaining >= fade_out_time:
		return 1.0
	return clampf(remaining / fade_out_time, 0.0, 1.0)
```

- [ ] **Step 2: Create the scene**

Create `scenes/effects/fire_tornado_effect.tscn` with this content:

```gdscene
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/effects/fire_tornado_effect.gd" id="1_8d45t"]

[node name="FireTornadoEffect" type="Node2D"]
z_index = 12
script = ExtResource("1_8d45t")

[node name="HeatCore" type="Node2D" parent="."]
z_index = 1

[node name="BaseFireRing" type="CPUParticles2D" parent="."]
z_index = 2

[node name="SpiralEmitterA" type="CPUParticles2D" parent="."]
z_index = 3

[node name="SpiralEmitterB" type="CPUParticles2D" parent="."]
z_index = 4

[node name="EmberSpray" type="CPUParticles2D" parent="."]
z_index = 5
```

- [ ] **Step 3: Run the verification and confirm the expected remaining failure**

Run:

```powershell
node tools\verify_fire_tornado_debug_vfx.js
```

Expected: FAIL with `debug panel must preload the fire tornado scene`.

- [ ] **Step 4: Run a syntax/load smoke check if Godot is available**

Run:

```powershell
godot --headless --path . --quit
```

Expected if Godot is installed on PATH: exit code 0. If PowerShell reports `godot` is not recognized, record that Godot headless verification is unavailable on PATH and continue.

- [ ] **Step 5: Commit checkpoint**

Run:

```powershell
git rev-parse --is-inside-work-tree
```

Expected in this workspace: `fatal: not a git repository`. Do not attempt a commit.

---

### Task 3: Wire the Debug Panel Button

**Files:**
- Modify: `scripts/debug/dev_debug_panel.gd`
- Test: `tools/verify_fire_tornado_debug_vfx.js`
- Test: `tools/validate_weapon_authoring_pipeline.js`

- [ ] **Step 1: Add the scene preload**

In `scripts/debug/dev_debug_panel.gd`, add this constant after `const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")`:

```gdscript
const FIRE_TORNADO_EFFECT_SCENE: PackedScene = preload("res://scenes/effects/fire_tornado_effect.tscn")
```

- [ ] **Step 2: Add the Utility button**

In `_build_panel()`, find the `utility_page` block:

```gdscript
	var utility_page: VBoxContainer = _add_category_page(page_root, "utility", "Utility")
	var util_row: HBoxContainer = _add_row(utility_page)
	_add_button(util_row, "Print", Callable(self, "_print_state"), 72)
	_add_button(util_row, "Ranges", Callable(self, "_toggle_range_overlay"), 84)
```

Change it to:

```gdscript
	var utility_page: VBoxContainer = _add_category_page(page_root, "utility", "Utility")
	var util_row: HBoxContainer = _add_row(utility_page)
	_add_button(util_row, "Print", Callable(self, "_print_state"), 72)
	_add_button(util_row, "Ranges", Callable(self, "_toggle_range_overlay"), 84)
	var vfx_row: HBoxContainer = _add_row(utility_page)
	_add_button(vfx_row, "Fire Tornado", Callable(self, "_spawn_fire_tornado_effect"), 132)
```

- [ ] **Step 3: Add the spawn methods**

Add these methods near `_spawn_configured_enemies()` and other debug actions:

```gdscript
func _spawn_fire_tornado_effect() -> void:
	var player: Node2D = _get_player() as Node2D
	if player == null:
		_log_warn("Cannot spawn Fire Tornado: player not found.")
		return
	if FIRE_TORNADO_EFFECT_SCENE == null:
		_log_error("Cannot spawn Fire Tornado: scene failed to load.")
		return

	var effect: Node2D = FIRE_TORNADO_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		_log_error("Cannot spawn Fire Tornado: scene root is not Node2D.")
		return

	var parent: Node = player.get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		effect.queue_free()
		_log_error("Cannot spawn Fire Tornado: no scene parent available.")
		return

	parent.add_child(effect)
	effect.global_position = _resolve_fire_tornado_spawn_position(player)
	_log("Spawned Fire Tornado VFX.")


func _resolve_fire_tornado_spawn_position(player: Node2D) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var nearest_enemy: Node2D = _get_nearest_enemy() as Node2D
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		var to_enemy: Vector2 = nearest_enemy.global_position - player.global_position
		if to_enemy.length_squared() > 0.0001:
			direction = to_enemy.normalized()
	return player.global_position + direction * 96.0
```

- [ ] **Step 4: Run the focused verification**

Run:

```powershell
node tools\verify_fire_tornado_debug_vfx.js
```

Expected: PASS with `Fire tornado debug VFX verified.`

- [ ] **Step 5: Run the full static pipeline**

Run:

```powershell
node tools\validate_weapon_authoring_pipeline.js
```

Expected: PASS with `Weapon authoring pipeline passed.`

- [ ] **Step 6: Run Godot headless verification if available**

Run:

```powershell
godot --headless --path . --quit
```

Expected if Godot is installed on PATH: exit code 0. If PowerShell reports `godot` is not recognized, record that Godot headless verification is unavailable on PATH.

- [ ] **Step 7: Manual debug acceptance check**

Run the project in the Godot editor or the existing debug executable, open developer mode, open the `Utility` page, press `Fire Tornado`, and confirm:

- A particle-based fire tornado appears near the player.
- The tornado appears toward the nearest enemy when one exists.
- The tornado disappears after about 2.5 seconds.
- Enemy HP, statuses, cooldowns, and attack traces do not change because of the VFX.

- [ ] **Step 8: Commit checkpoint**

Run:

```powershell
git rev-parse --is-inside-work-tree
```

Expected in this workspace: `fatal: not a git repository`. Do not attempt a commit.

---

## Self-Review

- Spec coverage: Task 2 creates the standalone particle VFX scene and auto-cleaning script. Task 3 adds the debug-only spawn button and nearest-enemy positioning. Task 1 adds non-visual verification and pipeline coverage. Non-goals are preserved because no combat data or skill files are edited.
- Placeholder scan: The plan contains no unfinished placeholder markers or unspecified implementation steps.
- Type consistency: `FireTornadoEffect`, `FIRE_TORNADO_EFFECT_SCENE`, `_spawn_fire_tornado_effect`, and `_resolve_fire_tornado_spawn_position(player: Node2D)` are named consistently across tests and implementation steps.
