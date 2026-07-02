# Runtime Churn Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce runtime node churn and spike frames in the real full-run attribution scenario without changing gameplay, combat math, UI content, or visual semantics.

**Architecture:** Optimize in five separately verifiable PR-sized stages. PR-1 removes the largest non-combat UI churn by reusing modal cards and gating debug-only UI. PR-2 introduces a small runtime pool for low-risk transient labels/overlays. PR-3 applies scene-root pooling to AoE/projectile combat objects through existing factories. PR-4 pools pickups and explains ObjectDB retention. PR-5 closes status tick observability gaps.

**Tech Stack:** Godot 4.6 GDScript, existing Node.js contract tests in `tools/verify`, real full-run profiler under `scripts/debug/real_full_run_profiler.gd`.

---

## Shared Acceptance Run

Use the same attribution scenario after each PR:

```powershell
Remove-Item -LiteralPath 'reports\real-full-run-profile\latest_attribution.json','reports\real-full-run-profile\latest_samples.json','reports\real-full-run-profile\report.md' -ErrorAction SilentlyContinue
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --profiling --path . -- --real-full-run-profile --survival-guard
```

Expected stop condition:

```text
status: BOSS_DAMAGE_REACHED
boss_damage_done: 1000
boss_health_modified: false
```

Always run these static checks before any real run:

```powershell
node tools\verify\verify_real_full_run_profile_contract.js
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/debug/real_full_run_profiler.gd
```

---

## PR-1: UI Dynamic Rebuild And Debug UI Gating

**Files:**
- Modify: `scripts/ui/modals/run_choice_modal_controller.gd`
- Modify: `scripts/enemies/enemy_debug_display_controller.gd`
- Test: `tools/verify/verify_pr1_ui_churn_contract.js`
- Update report: `docs/perf/REAL_FULL_RUN_PERFORMANCE_ANALYSIS.md`

- [ ] **Step 1: Write failing PR-1 contract test**

Create `tools/verify/verify_pr1_ui_churn_contract.js`:

```javascript
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const modal = readTextFile(path.join(root, "scripts", "ui", "modals", "run_choice_modal_controller.gd"));
const debugDisplay = readTextFile(path.join(root, "scripts", "enemies", "enemy_debug_display_controller.gd"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

assert(modal.includes("_ensure_choice_card_pool"), "Choice modal must pre-create/reuse card nodes.");
assert(modal.includes("_bind_choice_card"), "Choice modal must update existing card content instead of rebuilding it.");
assert(modal.includes("_hide_choice_card_pool"), "Choice modal must hide unused cards instead of queue_free-ing modal children.");
assert(!/func refresh_level_up_modal\(\)[\s\S]*?_clear_children\(_level_up_options\)/m.test(modal), "Level-up modal refresh must not clear/rebuild all children.");
assert(!/func refresh_reward_modal\(\)[\s\S]*?_clear_children\(_reward_options\)/m.test(modal), "Reward modal refresh must not clear/rebuild all children.");
assert(debugDisplay.includes("_debug_health_display_enabled"), "Enemy debug HP display must be gated by an explicit debug-display predicate.");
assert(debugDisplay.includes("developer_mode_enabled") || debugDisplay.includes("dev_debug_panel"), "Enemy debug HP display gate must be tied to runtime developer/debug state, not only OS.is_debug_build().");
assert(!/func update_health[\s\S]*?if not OS\.is_debug_build\(\) or _owner == null:/m.test(debugDisplay), "Enemy debug HP display must not be controlled only by OS.is_debug_build().");

console.log("[verify_pr1_ui_churn_contract] PASS");
```

- [ ] **Step 2: Verify PR-1 contract fails**

Run:

```powershell
node tools\verify\verify_pr1_ui_churn_contract.js
```

Expected: FAIL on missing `_ensure_choice_card_pool`.

- [ ] **Step 3: Implement modal card reuse**

In `scripts/ui/modals/run_choice_modal_controller.gd`:

```gdscript
var _choice_card_pools: Dictionary = {}
```

Add helpers:

```gdscript
func _refresh_choice_card_modal(container: BoxContainer, options: Array[Dictionary], return_state: String, consumes_pending_level: bool) -> void:
	_prepare_choice_card_layout(container)
	_ensure_choice_card_pool(container, LEVEL_UP_OPTION_COUNT)
	for index: int in range(LEVEL_UP_OPTION_COUNT):
		var slot: Dictionary = _choice_card_pools[container][index]
		if index < options.size():
			_bind_choice_card(slot, options[index], return_state, consumes_pending_level)
		else:
			_set_choice_card_slot_visible(slot, false)
	_finish_choice_card_layout(container)
	call_deferred("_update_choice_card_sizes", container)
```

Replace `refresh_level_up_modal()` and `refresh_reward_modal()` so they do not call `_clear_children()` for card modals.

- [ ] **Step 4: Implement card content rebinding**

Split card construction from binding:

```gdscript
func _create_choice_card_slot(parent: BoxContainer) -> Dictionary:
	# Create edge/gap/cell/button/content/title/icon/description/rarity/value rows once.
	# Return a Dictionary containing references to every mutable child.
	return {
		"cell": cell,
		"button": button,
		"title": title_label,
		"icon": texture_rect,
		"description": description_label,
		"rarity": rarity_label,
		"value_rows": value_rows,
		"value_icons": value_icons,
		"value_names": value_name_labels,
		"value_amounts": value_amount_labels
	}
```

Bind content:

```gdscript
func _bind_choice_card(slot: Dictionary, option: Dictionary, return_state: String, consumes_pending_level: bool) -> void:
	var button: Button = slot["button"]
	for connection: Dictionary in button.pressed.get_connections():
		button.pressed.disconnect(connection["callable"])
	button.pressed.connect(Callable(self, "_select_upgrade_option").bind(option, return_state, consumes_pending_level))
	slot["title"].text = _get_option_title(option)
	slot["description"].text = _get_option_description_text(option)
	slot["rarity"].text = _get_option_rarity_text(option)
	slot["icon"].texture = _load_texture(_get_option_icon_texture(option))
	_bind_value_rows(slot, option)
	_set_choice_card_slot_visible(slot, true)
```

- [ ] **Step 5: Gate enemy debug HP bars**

In `scripts/enemies/enemy_debug_display_controller.gd`, replace the `OS.is_debug_build()`-only gate:

```gdscript
func update_health(current_health: int, max_health: int) -> void:
	if not _debug_health_display_enabled() or _owner == null:
		return
```

Add:

```gdscript
func _debug_health_display_enabled() -> bool:
	if not OS.is_debug_build() or _owner == null:
		return false
	var tree: SceneTree = _owner.get_tree()
	if tree == null or tree.root == null:
		return false
	return bool(tree.root.get_meta("developer_mode_enabled", false))
```

- [ ] **Step 6: Verify PR-1 static checks**

Run:

```powershell
node tools\verify\verify_pr1_ui_churn_contract.js
node tools\verify\verify_real_full_run_profile_contract.js
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/ui/modals/run_choice_modal_controller.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --check-only --script res://scripts/enemies/enemy_debug_display_controller.gd
```

Expected: all exit 0.

- [ ] **Step 7: Run PR-1 acceptance profile**

Run the shared acceptance run and parse:

```powershell
node -e "const fs=require('fs'); const p=JSON.parse(fs.readFileSync('reports/real-full-run-profile/latest_attribution.json','utf8')); console.log(JSON.stringify({status:p.status,boss_damage_done:p.boss_damage_done,created:p.node_created_total,destroyed:p.node_destroyed_total,ui_created:p.created_by_category.ui,ui_destroyed:p.destroyed_by_category.ui,spikes50:p.spike_frames_over_50ms.length,spikes100:p.spike_frames_over_100ms.length},null,2));"
```

Expected target: UI created <= 3500 if modal/debug churn dominates. If not reached, report the measured delta and remaining top UI keys.

- [ ] **Step 8: PR-1 acceptance report**

Update `docs/perf/REAL_FULL_RUN_PERFORMANCE_ANALYSIS.md` with:

```text
PR-1 Before/After
- UI created/destroyed
- total created/destroyed
- >50ms and >100ms spikes
- p95/p99/max frame time
- top remaining UI churn keys
- visual/gameplay changes: none intended
```

Stop and wait for user confirmation before PR-2.

---

## PR-2: RuntimeObjectPool For DamageNumber And StatusVisualOverlay

**Files:**
- Create: `scripts/runtime/runtime_object_pool.gd`
- Create: `scripts/runtime/runtime_pool_registry.gd`
- Modify: `scripts/combat/damage_number_popup.gd`
- Modify: `scripts/combat/status_effect_manager.gd`
- Test: `tools/verify/verify_pr2_runtime_pool_contract.js`
- Update report: `docs/perf/REAL_FULL_RUN_PERFORMANCE_ANALYSIS.md`

- [ ] **Step 1: Write failing PR-2 contract test**

Assert a runtime pool exists, supports `spawn`, `despawn`, `prewarm`, `fallback instantiate`, and is wired only to DamageNumber / PlayerDamageNumber / StatusVisualOverlay.

- [ ] **Step 2: Add `RuntimeObjectPool`**

Implement a generic pool with:

```gdscript
func prewarm(key: StringName, factory: Callable, count: int, parent: Node) -> void
func spawn(key: StringName, factory: Callable, parent: Node) -> Node
func despawn(key: StringName, node: Node) -> void
func get_stats() -> Dictionary
```

- [ ] **Step 3: Add `RuntimePoolRegistry` autoload-style local resolver**

Use root metadata or a root child named `RuntimePoolRegistry`; do not require project setting changes in this PR.

- [ ] **Step 4: Pool damage numbers**

Change `DamageNumberPopup.show()` to request Label nodes from the pool, reset all text/style/position/modulate/scale/tween state, and return them on tween completion.

- [ ] **Step 5: Pool or reuse status overlays**

Prefer per-target `StatusVisualOverlay` reuse in `StatusEffectManager`; fall back to pool if ownership removal is safer.

- [ ] **Step 6: Verify and profile**

Run static checks and shared acceptance run. Target:

```text
DamageNumber created <= 300
StatusVisualOverlay created <= 300
No stale text/color/animation
```

Stop for user confirmation before PR-3.

---

## PR-3: Scene-Root Pooling For AoE And Projectiles

**Files:**
- Modify: `scripts/combat/combat_object_factory.gd`
- Modify: `scripts/combat/area_effect.gd`
- Modify: `scripts/combat/projectile.gd`
- Modify: `scripts/combat/damage_area.gd`
- Test: `tools/verify/verify_pr3_combat_scene_pool_contract.js`
- Update report: `docs/perf/REAL_FULL_RUN_PERFORMANCE_ANALYSIS.md`

- [ ] **Step 1: Write failing PR-3 contract test**

Assert `CombatObjectFactory.create_area_effect()` and `create_projectile()` use scene-root pool spawn/despawn hooks and do not pool child nodes.

- [ ] **Step 2: Add Poolable lifecycle methods**

For `area_effect.gd`, `projectile.gd`, and `damage_area.gd`:

```gdscript
func prepare_for_pool_spawn(params: Dictionary) -> void
func prepare_for_pool_despawn() -> void
func despawn_or_free() -> void
```

- [ ] **Step 3: Replace internal `queue_free()` exits**

Use `despawn_or_free()` in pooled scenes; fallback to `queue_free()` when no pool owner exists.

- [ ] **Step 4: Wire CombatObjectFactory**

Pool whole scene roots for:

```text
area_effect.tscn
scorching_vortex_area.tscn
damage_area.tscn
fireball_projectile.tscn
enemy_projectile.tscn
```

- [ ] **Step 5: Verify and profile**

Target:

```text
area_effect scene child churn down 70%+
fireball_projectile scene child churn down 70%+
projectile category created significantly lower
combat behavior equivalent
```

Stop for user confirmation before PR-4.

---

## PR-4: Pickup Pooling And ObjectDB Delta Explanation

**Files:**
- Modify: `scripts/drops/exp_gem.gd`
- Modify: `scripts/enemies/enemy_base.gd`
- Modify: `scripts/enemies/timeline/enemy_cleanup_service.gd`
- Modify: `scripts/game/run_scene_coordinator.gd`
- Test: `tools/verify/verify_pr4_pickup_pool_contract.js`
- Update report: `docs/perf/REAL_FULL_RUN_PERFORMANCE_ANALYSIS.md`

- [ ] **Step 1: Write failing PR-4 contract test**

Assert `experience_crystal.tscn` spawn path uses the pool and cleanup paths despawn active pickups.

- [ ] **Step 2: Add pickup lifecycle reset**

In `exp_gem.gd`, reset target, magnet state, collect state, velocity, tween, animation, collision, monitoring.

- [ ] **Step 3: Wire enemy drop path**

Change `enemy_base.gd` `_drop_experience_crystal()` to use pooled scene root with fallback.

- [ ] **Step 4: Wire cleanup paths**

Ensure wave end, run end, main menu transition, and restart despawn active pickups.

- [ ] **Step 5: Verify and profile**

Target:

```text
experience_crystal created down 70%+
pickup net live does not grow across run end
ObjectDB delta expected retained pool objects are explained
```

Stop for user confirmation before PR-5.

---

## PR-5: Status Tick Observability And Regression Reporting

**Files:**
- Modify: `scripts/combat/status_effect_manager.gd`
- Modify: `scripts/debug/real_full_run_profiler.gd`
- Create: `tools/verify/verify_pr5_status_tick_observability_contract.js`
- Update report: `docs/perf/REAL_FULL_RUN_PERFORMANCE_ANALYSIS.md`

- [ ] **Step 1: Write failing PR-5 contract test**

Assert profiler-only status events are present and no debug panel UI refresh is introduced.

- [ ] **Step 2: Add profiler-only event counters**

Emit or record lightweight counters:

```text
status_tick_due
status_tick_applied
status_expired
status_visual_spawn
status_visual_update
status_reaction_triggered
```

- [ ] **Step 3: Collect counters in real profiler**

Add these counters to `latest_attribution.json` spike buckets and summary.

- [ ] **Step 4: Verify and profile**

Target:

```text
status_tick_observation no longer reports observability_gap for normal status tick events
spike frames include status tick/reaction counts
no gameplay/status math changes
```

- [ ] **Step 5: Final rollout report**

Produce final before/after table for PR-1 through PR-5:

```text
node_created_total
node_destroyed_total
UI created
DamageNumber created
StatusVisualOverlay created
AoE/projectile scene churn
pickup net live
ObjectDB delta
frames > 50ms
frames > 100ms
p95/p99/max frame time
```

Stop for user confirmation and integration decision.
