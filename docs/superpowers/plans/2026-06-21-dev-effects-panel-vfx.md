# Dev Effects Panel VFX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an extensible Effects page to the dev debug panel and implement a debug-only 火星飞弹 VFX using `GPUParticles2D` with `ParticleProcessMaterial`.

**Architecture:** Keep this as a dev/debug presentation feature. Add a focused Mars Spark Missile effect scene and script, expose both Fire Tornado and Mars Spark Missile through a small effect registry in `DevDebugPanel`, and verify the UI contract plus particle-node contract with focused scripts.

**Tech Stack:** Godot 4.6 GDScript, `.tscn` scenes, `GPUParticles2D`, `ParticleProcessMaterial`, Node.js verification scripts.

---

## File Structure

- Create: `scripts/effects/mars_spark_missile_effect.gd`
  - Runtime logic for a single self-cleaning spark missile or a short continuous emitter.
  - Configures `GPUParticles2D` children at runtime with `ParticleProcessMaterial`.
- Create: `scenes/effects/mars_spark_missile_effect.tscn`
  - Scene root and required `GPUParticles2D` child nodes.
- Create: `tools/verify_dev_effects_panel_vfx.js`
  - Static contract for DevDebugPanel Effects UI and Mars Spark Missile particle scene.
- Create: `tools/verify_mars_spark_missile_effect_runtime.gd`
  - Runtime scene instantiation and self-clean check.
- Modify: `scripts/debug/dev_debug_panel.gd`
  - Add Effects category and effect dropdown.
  - Replace standalone Fire Tornado utility button with generic continuous/single effect buttons.
  - Route Fire Tornado and Mars Spark Missile through the selected effect id.
- Modify: `tools/validate_weapon_authoring_pipeline.js`
  - Add the new static verifier to the existing validation pipeline.
- Modify: `tools/verify_fire_tornado_debug_vfx.js`
  - Update expectations from standalone Fire Tornado button to the new Effects registry.

No commit steps are included because `E:\roguelike_survivor` currently reports `fatal: not a git repository`.

---

### Task 1: Add Failing Static Contract For Effects Panel

**Files:**
- Create: `tools/verify_dev_effects_panel_vfx.js`

- [ ] **Step 1: Write the failing verifier**

Create `tools/verify_dev_effects_panel_vfx.js`:

```javascript
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");

function readText(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8").replace(/^\uFEFF/, "");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function main() {
  const panelPath = path.join(root, "scripts/debug/dev_debug_panel.gd");
  const scenePath = path.join(root, "scenes/effects/mars_spark_missile_effect.tscn");
  const scriptPath = path.join(root, "scripts/effects/mars_spark_missile_effect.gd");
  assert(fs.existsSync(panelPath), "DevDebugPanel script must exist");
  assert(fs.existsSync(scenePath), "Mars Spark Missile effect scene must exist");
  assert(fs.existsSync(scriptPath), "Mars Spark Missile effect script must exist");

  const panel = readText("scripts/debug/dev_debug_panel.gd");
  assert(panel.includes('MARS_SPARK_MISSILE_EFFECT_SCENE'), "DevDebugPanel must preload the Mars Spark Missile effect scene");
  assert(panel.includes('_add_category_button(category_grid, "effects", "Effects")'), "DevDebugPanel must add an Effects category");
  assert(panel.includes('_effect_option = _add_option_row(effects_page, "Effect")'), "Effects page must expose an effect dropdown");
  assert(panel.includes('_populate_effect_options()'), "DevDebugPanel must populate effect options");
  assert(panel.includes('"Fire Tornado"'), "Effects dropdown must include Fire Tornado");
  assert(panel.includes('"火星飞弹"'), "Effects dropdown must include 火星飞弹");
  assert(panel.includes('"持续发射"'), "Effects page must include a continuous fire button");
  assert(panel.includes('"单次发射"'), "Effects page must include a single fire button");
  assert(panel.includes("func _play_selected_effect_continuous() -> void:"), "DevDebugPanel must implement continuous effect playback");
  assert(panel.includes("func _play_selected_effect_once() -> void:"), "DevDebugPanel must implement single effect playback");
  assert(panel.includes("func _spawn_mars_spark_missile_effect(continuous: bool) -> void:"), "DevDebugPanel must spawn Mars Spark Missile by selected mode");

  const scene = readText("scenes/effects/mars_spark_missile_effect.tscn");
  assert(scene.includes('type="GPUParticles2D"'), "Mars Spark Missile scene must use GPUParticles2D nodes");
  assert((scene.match(/type="GPUParticles2D"/g) || []).length >= 3, "Mars Spark Missile scene must have at least three GPUParticles2D nodes");
  assert(scene.includes('type="ParticleProcessMaterial"'), "Mars Spark Missile scene must serialize ParticleProcessMaterial resources");
  for (const nodeName of ["CoreParticles", "TrailParticles", "EmberParticles"]) {
    assert(scene.includes(`name="${nodeName}"`), `Mars Spark Missile scene must include ${nodeName}`);
  }
  assert(scene.includes('path="res://scripts/effects/mars_spark_missile_effect.gd"'), "Mars Spark Missile scene must attach its script");

  const script = readText("scripts/effects/mars_spark_missile_effect.gd");
  assert(script.includes("class_name MarsSparkMissileEffect"), "Mars Spark Missile script must declare class_name");
  assert(script.includes("GPUParticles2D"), "Mars Spark Missile script must configure GPUParticles2D nodes");
  assert(script.includes("ParticleProcessMaterial"), "Mars Spark Missile script must configure ParticleProcessMaterial");
  assert(script.includes("func configure("), "Mars Spark Missile script must expose configure()");
  assert(script.includes("func _spawn_missile("), "Mars Spark Missile script must spawn missiles");
  assert(script.includes("queue_free()"), "Mars Spark Missile script must self-clean");

  console.log("Dev effects panel VFX verified.");
}

main();
```

- [ ] **Step 2: Run the verifier to confirm RED**

Run:

```powershell
node tools\verify_dev_effects_panel_vfx.js
```

Expected: FAIL with `Mars Spark Missile effect scene must exist`.

---

### Task 2: Add Failing Runtime Check For Mars Spark Missile

**Files:**
- Create: `tools/verify_mars_spark_missile_effect_runtime.gd`

- [ ] **Step 1: Write the failing runtime check**

Create `tools/verify_mars_spark_missile_effect_runtime.gd`:

```gdscript
extends SceneTree


var _failed: bool = false


func _init() -> void:
	process_frame.connect(_run_check, CONNECT_ONE_SHOT)


func _run_check() -> void:
	var packed_scene: PackedScene = load("res://scenes/effects/mars_spark_missile_effect.tscn") as PackedScene
	_expect(packed_scene != null, "Mars Spark Missile scene loads")
	if packed_scene == null:
		_finish()
		return

	var effect: Node2D = packed_scene.instantiate() as Node2D
	_expect(effect != null, "Mars Spark Missile scene instantiates as Node2D")
	if effect == null:
		_finish()
		return

	root.add_child(effect)
	_expect(effect.has_method("configure"), "Mars Spark Missile exposes configure")
	if effect.has_method("configure"):
		effect.call("configure", Vector2.ZERO, Vector2(160.0, 0.0), false)
	await process_frame
	await process_frame

	var particles: Array[Node] = []
	for child: Node in effect.get_children():
		if child is GPUParticles2D:
			particles.append(child)
	_expect(particles.size() >= 3, "Mars Spark Missile has at least three GPUParticles2D children")
	for particle_node: Node in particles:
		var gpu_particles: GPUParticles2D = particle_node as GPUParticles2D
		_expect(gpu_particles.process_material is ParticleProcessMaterial, "%s uses ParticleProcessMaterial" % gpu_particles.name)

	if is_instance_valid(effect):
		effect.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
	else:
		_failed = true
		push_error("FAIL %s" % message)


func _finish() -> void:
	if _failed:
		quit(1)
		return
	print("Mars Spark Missile runtime scene verified.")
	quit(0)
```

- [ ] **Step 2: Run runtime check to confirm RED**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_mars_spark_missile_effect_runtime.gd
```

Expected: FAIL with `Mars Spark Missile scene loads`.

---

### Task 3: Implement Mars Spark Missile Effect Scene And Script

**Files:**
- Create: `scripts/effects/mars_spark_missile_effect.gd`
- Create: `scenes/effects/mars_spark_missile_effect.tscn`

- [ ] **Step 1: Add the effect script**

Create `scripts/effects/mars_spark_missile_effect.gd`:

```gdscript
extends Node2D
class_name MarsSparkMissileEffect


@export_range(0.1, 12.0, 0.1, "or_greater") var lifetime: float = 1.25
@export_range(32.0, 1200.0, 1.0, "or_greater") var speed: float = 420.0
@export_range(0.05, 2.0, 0.01, "or_greater") var burst_interval: float = 0.16
@export_range(1, 64, 1, "or_greater") var burst_count: int = 1
@export var spread_degrees: float = 12.0

var _age: float = 0.0
var _continuous: bool = false
var _origin: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.RIGHT * 160.0
var _direction: Vector2 = Vector2.RIGHT
var _burst_timer: float = 0.0
var _spawned: int = 0

@onready var _core_particles: GPUParticles2D = get_node_or_null("CoreParticles") as GPUParticles2D
@onready var _trail_particles: GPUParticles2D = get_node_or_null("TrailParticles") as GPUParticles2D
@onready var _ember_particles: GPUParticles2D = get_node_or_null("EmberParticles") as GPUParticles2D


func configure(origin: Vector2, target: Vector2, continuous: bool) -> void:
	_origin = origin
	_target = target
	_continuous = continuous
	global_position = origin
	_direction = origin.direction_to(target)
	if _direction.length_squared() <= 0.0001:
		_direction = Vector2.RIGHT
	rotation = _direction.angle()
	burst_count = 18 if continuous else 4
	lifetime = 3.4 if continuous else 1.25
	_burst_timer = 0.0
	_spawned = 0
	_spawn_missile()


func _ready() -> void:
	_configure_particles()
	set_process(true)
	if _spawned <= 0:
		configure(global_position, global_position + Vector2.RIGHT * 160.0, false)


func _process(delta: float) -> void:
	_age += delta
	if _continuous and _spawned < burst_count:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_spawn_missile()
			_burst_timer = burst_interval
	if not _continuous:
		global_position += _direction * speed * delta
	if _age >= lifetime:
		queue_free()


func _spawn_missile() -> void:
	_spawned += 1
	var angle_offset: float = deg_to_rad(randf_range(-spread_degrees, spread_degrees))
	var missile_direction: Vector2 = _direction.rotated(angle_offset)
	if _continuous:
		var missile: MarsSparkMissileEffect = duplicate() as MarsSparkMissileEffect
		if missile == null:
			return
		missile._continuous = false
		missile.burst_count = 1
		missile.lifetime = 1.1
		missile.speed = speed * randf_range(0.88, 1.14)
		missile.global_position = _origin + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		missile._direction = missile_direction
		missile.rotation = missile_direction.angle()
		get_parent().add_child(missile)
		return
	global_position = _origin
	_direction = missile_direction
	rotation = _direction.angle()
	_restart_particles()


func _configure_particles() -> void:
	_configure_particle_node(_core_particles, 42, 0.28, Color(1.0, 0.30, 0.045, 0.90), Vector2(-70.0, 0.0), 2.6, 5.2)
	_configure_particle_node(_trail_particles, 86, 0.46, Color(1.0, 0.15, 0.02, 0.48), Vector2(-130.0, 0.0), 1.2, 3.8)
	_configure_particle_node(_ember_particles, 34, 0.62, Color(1.0, 0.58, 0.12, 0.58), Vector2(-58.0, 0.0), 0.55, 1.8)


func _configure_particle_node(particles: GPUParticles2D, amount: int, particle_lifetime: float, color: Color, gravity: Vector2, scale_min: float, scale_max: float) -> void:
	if particles == null:
		return
	var material: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	if material == null:
		material = ParticleProcessMaterial.new()
		particles.process_material = material
	material.direction = Vector3(-1.0, 0.0, 0.0)
	material.spread = 20.0
	material.gravity = Vector3(gravity.x, gravity.y, 0.0)
	material.initial_velocity_min = 12.0
	material.initial_velocity_max = 78.0
	material.scale_min = scale_min
	material.scale_max = scale_max
	material.color = color
	particles.amount = amount
	particles.lifetime = particle_lifetime
	particles.one_shot = false
	particles.explosiveness = 0.08
	particles.randomness = 0.72
	particles.local_coords = true
	particles.emitting = true


func _restart_particles() -> void:
	for particles: GPUParticles2D in [_core_particles, _trail_particles, _ember_particles]:
		if particles == null:
			continue
		particles.restart()
		particles.emitting = true
```

- [ ] **Step 2: Add the effect scene**

Create `scenes/effects/mars_spark_missile_effect.tscn`:

```gdscene
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/effects/mars_spark_missile_effect.gd" id="1_spark"]

[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_core"]
direction = Vector3(-1, 0, 0)
spread = 18.0
gravity = Vector3(-70, 0, 0)
initial_velocity_min = 12.0
initial_velocity_max = 78.0
scale_min = 2.6
scale_max = 5.2
color = Color(1, 0.3, 0.045, 0.9)

[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_trail"]
direction = Vector3(-1, 0, 0)
spread = 20.0
gravity = Vector3(-130, 0, 0)
initial_velocity_min = 12.0
initial_velocity_max = 78.0
scale_min = 1.2
scale_max = 3.8
color = Color(1, 0.15, 0.02, 0.48)

[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_ember"]
direction = Vector3(-1, 0, 0)
spread = 26.0
gravity = Vector3(-58, 0, 0)
initial_velocity_min = 12.0
initial_velocity_max = 78.0
scale_min = 0.55
scale_max = 1.8
color = Color(1, 0.58, 0.12, 0.58)

[node name="MarsSparkMissileEffect" type="Node2D"]
z_index = 13
script = ExtResource("1_spark")

[node name="CoreParticles" type="GPUParticles2D" parent="."]
amount = 42
lifetime = 0.28
process_material = SubResource("ParticleProcessMaterial_core")

[node name="TrailParticles" type="GPUParticles2D" parent="."]
amount = 86
lifetime = 0.46
process_material = SubResource("ParticleProcessMaterial_trail")

[node name="EmberParticles" type="GPUParticles2D" parent="."]
amount = 34
lifetime = 0.62
process_material = SubResource("ParticleProcessMaterial_ember")
```

- [ ] **Step 3: Run static and runtime checks**

Run:

```powershell
node tools\verify_dev_effects_panel_vfx.js
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_mars_spark_missile_effect_runtime.gd
```

Expected: static verifier still fails on DevDebugPanel missing Effects UI; runtime check passes.

---

### Task 4: Add Effects Page To DevDebugPanel

**Files:**
- Modify: `scripts/debug/dev_debug_panel.gd`

- [ ] **Step 1: Add scene preload and option field**

At the top with existing constants, add:

```gdscript
const MARS_SPARK_MISSILE_EFFECT_SCENE: PackedScene = preload("res://scenes/effects/mars_spark_missile_effect.tscn")
```

Near `_status_option`, add:

```gdscript
var _effect_option: OptionButton
```

- [ ] **Step 2: Add Effects category and page**

In `_build_panel()`, after Enemy Spawn category:

```gdscript
_add_category_button(category_grid, "effects", "Effects")
```

After enemy spawn page setup and before status page setup, add:

```gdscript
var effects_page: VBoxContainer = _add_category_page(page_root, "effects", "Effects")
_effect_option = _add_option_row(effects_page, "Effect")
var effects_row: HBoxContainer = _add_row(effects_page)
_add_button(effects_row, "持续发射", Callable(self, "_play_selected_effect_continuous"), 116)
_add_button(effects_row, "单次发射", Callable(self, "_play_selected_effect_once"), 116)
```

Remove the old Utility VFX row:

```gdscript
var vfx_row: HBoxContainer = _add_row(utility_page)
_add_button(vfx_row, "Fire Tornado", Callable(self, "_spawn_fire_tornado_effect"), 132)
```

- [ ] **Step 3: Populate effect options**

In `_populate_options()`, after `_populate_enemy_state_options()` add:

```gdscript
_populate_effect_options()
```

Add this method near the option population methods:

```gdscript
func _populate_effect_options() -> void:
	if _effect_option == null:
		return
	_effect_option.clear()
	_add_option_item(_effect_option, "Fire Tornado", "fire_tornado")
	_add_option_item(_effect_option, "火星飞弹", "mars_spark_missile")
	_select_first_enabled_option(_effect_option)
```

- [ ] **Step 4: Add selected effect dispatch**

Replace `_spawn_fire_tornado_effect()` with these methods:

```gdscript
func _play_selected_effect_continuous() -> void:
	_play_selected_effect(true)


func _play_selected_effect_once() -> void:
	_play_selected_effect(false)


func _play_selected_effect(continuous: bool) -> void:
	var effect_id: StringName = _get_selected_id(_effect_option)
	match effect_id:
		&"fire_tornado":
			_spawn_fire_tornado_effect()
		&"mars_spark_missile":
			_spawn_mars_spark_missile_effect(continuous)
		_:
			_log_warn("No debug effect selected.")
```

Keep `_spawn_fire_tornado_effect()` as an internal helper with its existing body.

- [ ] **Step 5: Add Mars Spark Missile spawn helper**

Add after `_spawn_fire_tornado_effect()`:

```gdscript
func _spawn_mars_spark_missile_effect(continuous: bool) -> void:
	var player: Node2D = _get_player() as Node2D
	if player == null:
		_log_warn("Cannot spawn 火星飞弹: player not found.")
		return
	if MARS_SPARK_MISSILE_EFFECT_SCENE == null:
		_log_error("Cannot spawn 火星飞弹: scene failed to load.")
		return

	var effect: Node2D = MARS_SPARK_MISSILE_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		_log_error("Cannot spawn 火星飞弹: scene root is not Node2D.")
		return

	var parent: Node = player.get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		effect.queue_free()
		_log_error("Cannot spawn 火星飞弹: no scene parent available.")
		return

	var origin: Vector2 = player.global_position + Vector2(18.0, -6.0)
	var target: Vector2 = origin + Vector2.RIGHT * 180.0
	var nearest_enemy: Node2D = _get_nearest_enemy() as Node2D
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		target = nearest_enemy.global_position

	parent.add_child(effect)
	if effect.has_method("configure"):
		effect.call("configure", origin, target, continuous)
	else:
		effect.global_position = origin
	_log("Spawned 火星飞弹 VFX (%s)." % ("continuous" if continuous else "single"))
```

- [ ] **Step 6: Run static verifier**

Run:

```powershell
node tools\verify_dev_effects_panel_vfx.js
```

Expected: PASS.

---

### Task 5: Update Existing Fire Tornado Verifier And Validation Pipeline

**Files:**
- Modify: `tools/verify_fire_tornado_debug_vfx.js`
- Modify: `tools/validate_weapon_authoring_pipeline.js`

- [ ] **Step 1: Update Fire Tornado verifier for Effects page**

In `tools/verify_fire_tornado_debug_vfx.js`, replace:

```javascript
assert(debugPanel.includes('"Fire Tornado"'), "debug panel must expose a Fire Tornado button");
assert(debugPanel.includes("func _spawn_fire_tornado_effect() -> void:"), "debug panel must implement fire tornado spawning");
```

with:

```javascript
assert(debugPanel.includes('"Fire Tornado"'), "debug panel must expose Fire Tornado in the Effects selector");
assert(debugPanel.includes('_add_category_button(category_grid, "effects", "Effects")'), "debug panel must expose an Effects category");
assert(debugPanel.includes("func _spawn_fire_tornado_effect() -> void:"), "debug panel must keep fire tornado spawning helper");
assert(debugPanel.includes("func _play_selected_effect_once() -> void:"), "debug panel must route selected effects through the Effects page");
```

- [ ] **Step 2: Add dev effects verifier to pipeline**

In `tools/validate_weapon_authoring_pipeline.js`, after:

```javascript
["fire tornado debug VFX", "tools/verify_fire_tornado_debug_vfx.js"],
```

add:

```javascript
["dev effects panel VFX", "tools/verify_dev_effects_panel_vfx.js"],
```

- [ ] **Step 3: Run verification**

Run:

```powershell
node tools\verify_fire_tornado_debug_vfx.js
node tools\verify_dev_effects_panel_vfx.js
node tools\validate_weapon_authoring_pipeline.js
```

Expected: all pass.

---

### Task 6: Final Godot Verification

**Files:**
- Verify: `scripts/debug/dev_debug_panel.gd`
- Verify: `scripts/effects/mars_spark_missile_effect.gd`
- Verify: `tools/verify_mars_spark_missile_effect_runtime.gd`

- [ ] **Step 1: Parse modified/new GDScript**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/debug/dev_debug_panel.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/effects/mars_spark_missile_effect.gd
```

Expected: both exit code `0`.

- [ ] **Step 2: Run runtime checks**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_mars_spark_missile_effect_runtime.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_fire_tornado_effect_runtime.gd
```

Expected: both exit code `0`.

- [ ] **Step 3: Run project startup check**

Run:

```powershell
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --quit
```

Expected: exit code `0`.

---

## Self-Review

- Spec coverage:
  - Effects category: Task 4.
  - Dropdown with Fire Tornado and 火星飞弹: Task 4.
  - Continuous and single buttons: Task 4.
  - 火星飞弹 with `GPUParticles2D` and `ParticleProcessMaterial`: Task 3.
  - Debug-only no damage/status: Task 3 and Task 4 keep effect scene independent from combat APIs.
  - Verification: Tasks 1, 2, 5, and 6.
- Placeholder scan:
  - No placeholder or deferred-work markers remain.
- Type consistency:
  - Effect id is consistently `mars_spark_missile`.
  - Scene/script names are consistently `MarsSparkMissileEffect`.
  - Dev panel field name is consistently `_effect_option`.
