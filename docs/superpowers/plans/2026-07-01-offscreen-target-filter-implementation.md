# Offscreen Target Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent automatic skill and primary-attack target selection from choosing enemies outside the active camera view, even when those enemies are within numeric range.

**Architecture:** Centralize camera-view target validity in `TargetingService`, then reuse that public target validity from projectile homing. Missing camera/viewport state remains permissive so headless checks and isolated tool scenes keep working.

**Tech Stack:** Godot 4.6 GDScript, Node.js static verification scripts, existing `npm run verify:*` commands.

---

## File Structure

- Create `tools/verify/verify_offscreen_target_filter.js`
  - Static regression verifier for camera-visible target filtering and projectile homing integration.
- Modify `package.json`
  - Add `verify:offscreen-target-filter`.
- Modify `scripts/skills/targeting_service.gd`
  - Add active-camera visibility helper and call it from `_is_valid_enemy()`.
- Modify `scripts/combat/projectile.gd`
  - Reuse `TargetingService.is_valid_target()` in homing target selection and swept hit filtering.

---

### Task 1: Add Offscreen Target Verification

**Files:**
- Create: `tools/verify/verify_offscreen_target_filter.js`
- Modify: `package.json`

- [ ] **Step 1: Write the failing static verification script**

Create `tools/verify/verify_offscreen_target_filter.js`:

```javascript
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");

function readProjectFile(relativePath) {
  return readTextFile(path.join(root, relativePath));
}

function extractGdFunctionBody(text, signaturePattern) {
  const match = signaturePattern.exec(text);
  if (!match) return "";

  const bodyStart = text.indexOf("\n", match.index);
  if (bodyStart < 0) return "";

  const rest = text.slice(bodyStart + 1);
  const nextFunction = rest.search(/^(?:static\s+)?func\s+/m);
  return nextFunction >= 0 ? rest.slice(0, nextFunction) : rest;
}

function validateTargetingService(text) {
  const errors = [];
  const isValidTargetBody = extractGdFunctionBody(text, /^static\s+func\s+is_valid_target\s*\(/m);
  const isValidEnemyBody = extractGdFunctionBody(text, /^static\s+func\s+_is_valid_enemy\s*\(/m);
  const cameraVisibilityBody = extractGdFunctionBody(text, /^static\s+func\s+_is_enemy_inside_active_camera_view\s*\(/m);

  if (isValidTargetBody === "") {
    errors.push("TargetingService.is_valid_target must exist.");
  } else if (!isValidTargetBody.includes("_is_valid_enemy(")) {
    errors.push("TargetingService.is_valid_target must reuse _is_valid_enemy.");
  }

  if (isValidEnemyBody === "") {
    errors.push("TargetingService._is_valid_enemy must exist.");
  } else {
    for (const token of ["is_queued_for_deletion", "current_health", "get_runtime_state", "_is_dead"]) {
      if (!isValidEnemyBody.includes(token)) {
        errors.push(`TargetingService._is_valid_enemy must keep ${token} validity check.`);
      }
    }
    if (!isValidEnemyBody.includes("_is_enemy_inside_active_camera_view(enemy)")) {
      errors.push("TargetingService._is_valid_enemy must reject enemies outside the active camera view.");
    }
  }

  if (cameraVisibilityBody === "") {
    errors.push("TargetingService._is_enemy_inside_active_camera_view must exist.");
  } else {
    for (const token of [
      "Engine.get_main_loop",
      "tree.root",
      "get_camera_2d",
      "get_visible_rect",
      "camera.zoom.abs",
      "camera.global_position",
      "enemy.global_position",
      "Rect2",
      "has_point",
    ]) {
      if (!cameraVisibilityBody.includes(token)) {
        errors.push(`TargetingService camera visibility helper must use ${token}.`);
      }
    }
    if (!/camera\s*==\s*null[\s\S]*return true/.test(cameraVisibilityBody)) {
      errors.push("TargetingService camera visibility helper must allow targets when no active camera exists.");
    }
  }

  return errors;
}

function validateProjectile(text) {
  const errors = [];
  const nearestBody = extractGdFunctionBody(text, /^func\s+_find_nearest_homing_target\s*\(/m);
  const validBody = extractGdFunctionBody(text, /^func\s+_is_valid_homing_target\s*\(/m);

  if (!text.includes('preload("res://scripts/skills/targeting_service.gd")')) {
    errors.push("Projectile must preload TargetingService.");
  }

  if (nearestBody === "") {
    errors.push("Projectile._find_nearest_homing_target must exist.");
  } else if (!nearestBody.includes("_is_valid_homing_target(target)")) {
    errors.push("Projectile._find_nearest_homing_target must reuse _is_valid_homing_target.");
  }

  if (validBody === "") {
    errors.push("Projectile._is_valid_homing_target must exist.");
  } else if (!validBody.includes("TargetingServiceScript.is_valid_target(target)")) {
    errors.push("Projectile._is_valid_homing_target must use TargetingServiceScript.is_valid_target(target).");
  }

  return errors;
}

function main() {
  const targetingService = readProjectFile("scripts/skills/targeting_service.gd");
  const projectile = readProjectFile("scripts/combat/projectile.gd");
  const errors = [
    ...validateTargetingService(targetingService),
    ...validateProjectile(projectile),
  ];

  if (errors.length > 0) {
    console.error("verify_offscreen_target_filter: FAIL");
    for (const error of errors) {
      console.error(`- ${error}`);
    }
    process.exit(1);
  }

  console.log("verify_offscreen_target_filter: PASS");
}

if (require.main === module) {
  main();
}
```

- [ ] **Step 2: Add the npm script**

In `package.json`, add this entry near the other Node verification scripts:

```json
"verify:offscreen-target-filter": "node tools\\verify\\verify_offscreen_target_filter.js",
```

Keep comma placement valid JSON.

- [ ] **Step 3: Run the new verification and confirm it fails**

Run:

```powershell
npm run verify:offscreen-target-filter
```

Expected: FAIL with messages that `_is_enemy_inside_active_camera_view` is missing and `Projectile._is_valid_homing_target` does not call `TargetingServiceScript.is_valid_target(target)`.

---

### Task 2: Implement Camera-Visible Target Validity

**Files:**
- Modify: `scripts/skills/targeting_service.gd`
- Modify: `scripts/combat/projectile.gd`

- [ ] **Step 1: Add active camera visibility to `TargetingService`**

In `scripts/skills/targeting_service.gd`, update `_is_valid_enemy(enemy: Node2D) -> bool` so the end of the function becomes:

```gdscript
	var is_dead_variant: Variant = enemy.get("_is_dead")
	if is_dead_variant != null and bool(is_dead_variant):
		return false

	if not _is_enemy_inside_active_camera_view(enemy):
		return false

	return true
```

Then add this helper immediately after `_is_valid_enemy()`:

```gdscript
static func _is_enemy_inside_active_camera_view(enemy: Node2D) -> bool:
	if enemy == null:
		return false

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return true

	var viewport: Viewport = tree.root
	var camera: Camera2D = viewport.get_camera_2d()
	if camera == null:
		return true

	var visible_size: Vector2 = viewport.get_visible_rect().size
	if visible_size.x <= 0.0 or visible_size.y <= 0.0:
		return true

	var camera_zoom: Vector2 = camera.zoom.abs()
	var world_size: Vector2 = Vector2(
		visible_size.x / maxf(camera_zoom.x, 0.001),
		visible_size.y / maxf(camera_zoom.y, 0.001)
	)
	var world_rect: Rect2 = Rect2(camera.global_position - world_size * 0.5, world_size)
	return world_rect.has_point(enemy.global_position)
```

- [ ] **Step 2: Reuse `TargetingService` from projectile homing**

In `scripts/combat/projectile.gd`, add this preload with the other constants near the top:

```gdscript
const TargetingServiceScript: Script = preload("res://scripts/skills/targeting_service.gd")
```

Update `_find_nearest_homing_target()` so the loop uses the shared homing validity helper:

```gdscript
	for node: Node in tree.get_nodes_in_group(target_group):
		var target: Node2D = node as Node2D
		if not _is_valid_homing_target(target):
			continue
		var distance_squared: float = global_position.distance_squared_to(target.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest = target
```

Replace `_is_valid_homing_target(target: Node2D) -> bool` with:

```gdscript
func _is_valid_homing_target(target: Node2D) -> bool:
	return TargetingServiceScript.is_valid_target(target)
```

- [ ] **Step 3: Run the new verification and confirm it passes**

Run:

```powershell
npm run verify:offscreen-target-filter
```

Expected:

```text
verify_offscreen_target_filter: PASS
```

---

### Task 3: Run Regression Checks

**Files:**
- No code changes expected.

- [ ] **Step 1: Run targeted and adjacent checks**

Run:

```powershell
npm run verify:offscreen-target-filter
npm run verify:skill-retarget-dead-target
npm run verify:player-dash
npm run verify:enemy-motion-neighbor-limit
```

Expected: each command exits `0` and prints PASS output.

- [ ] **Step 2: Check known unrelated smoke failures separately**

Run only if you need to compare broader smoke status:

```powershell
npm run verify:fire-skill-runtime-smoke
npm run verify:frost-skill-runtime-smoke
```

Expected current repository behavior: these fail before the offscreen target path in `SkillManager.add_skill()` because the smoke tests still assume full direct learning of fire/frost/fusion skill sets while the current `SkillManager` enforces the god-school learning cap.

- [ ] **Step 3: Check git diff**

Run:

```powershell
git diff --stat
git status --short
```

Expected changed files:

```text
package.json
scripts/combat/projectile.gd
scripts/skills/targeting_service.gd
tools/verify/verify_offscreen_target_filter.js
```

The plan document may also be present if it has not already been committed.

---

### Task 4: Commit Implementation

**Files:**
- Modify: `package.json`
- Modify: `scripts/combat/projectile.gd`
- Modify: `scripts/skills/targeting_service.gd`
- Create: `tools/verify/verify_offscreen_target_filter.js`

- [ ] **Step 1: Stage implementation changes**

Run:

```powershell
git add package.json scripts/combat/projectile.gd scripts/skills/targeting_service.gd tools/verify/verify_offscreen_target_filter.js
```

- [ ] **Step 2: Commit implementation**

Run:

```powershell
git commit -m "fix: ignore offscreen enemies when targeting"
```

Expected: commit succeeds with the implementation files staged.
