# Skill Retarget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent targeted skills from wasting casts when their original target is killed by a primary attack before the skill action resolves.

**Architecture:** Centralize target liveness in `TargetingService`, then reuse it from `SkillActionExecutor._context_with_resolved_target()`. Retargeting only happens when the current target is unusable; living targets remain stable.

**Tech Stack:** Godot 4.6 GDScript, existing Node-based static verification scripts, existing `npm run verify:*` commands.

---

## File Structure

- Create `tools/verify/verify_skill_retarget_dead_target.js`
  - Static regression test that verifies the retargeting contract in `TargetingService` and `SkillActionExecutor`.
- Modify `package.json`
  - Add `verify:skill-retarget-dead-target`.
- Modify `scripts/skills/targeting_service.gd`
  - Add public `is_valid_target(enemy: Node2D) -> bool`.
- Modify `scripts/skills/skill_action_executor.gd`
  - Replace ad hoc valid target check in `_context_with_resolved_target()` with `TargetingServiceScript.is_valid_target(target)`.

---

### Task 1: Add Retarget Regression Verification

**Files:**
- Create: `tools/verify/verify_skill_retarget_dead_target.js`
- Modify: `package.json`

- [ ] **Step 1: Write the failing static verification script**

Create `tools/verify/verify_skill_retarget_dead_target.js`:

```javascript
const fs = require("fs");
const path = require("path");

const root = process.cwd();

function readProjectFile(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function extractFunction(source, name) {
  const marker = `func ${name}`;
  const start = source.indexOf(marker);
  if (start < 0) {
    throw new Error(`Missing function ${name}`);
  }
  const next = source.indexOf("\nfunc ", start + marker.length);
  return source.slice(start, next < 0 ? source.length : next);
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const targetingService = readProjectFile("scripts/skills/targeting_service.gd");
const skillActionExecutor = readProjectFile("scripts/skills/skill_action_executor.gd");

const publicValidity = extractFunction(targetingService, "is_valid_target");
const privateValidity = extractFunction(targetingService, "_is_valid_enemy");
const contextRetarget = extractFunction(skillActionExecutor, "_context_with_resolved_target");

assert(
  publicValidity.includes("_is_valid_enemy"),
  "TargetingService.is_valid_target should reuse the centralized enemy validity rules."
);

assert(
  privateValidity.includes("is_queued_for_deletion") &&
    privateValidity.includes("current_health") &&
    privateValidity.includes("get_runtime_state") &&
    privateValidity.includes("_is_dead"),
  "TargetingService validity should reject queued, dead-state, zero-health, and _is_dead enemies."
);

assert(
  contextRetarget.includes("TargetingServiceScript.is_valid_target(target)"),
  "SkillActionExecutor should validate context targets through TargetingService before keeping them."
);

assert(
  !contextRetarget.includes("not target.is_queued_for_deletion()"),
  "SkillActionExecutor should not rely on queue state alone; dead/zero-health targets must retarget too."
);

assert(
  contextRetarget.includes("_resolve_action_target(params, context)") &&
    contextRetarget.includes('resolved_context["target"] = resolved_target') &&
    contextRetarget.includes('resolved_context["enemy"] = resolved_target'),
  "SkillActionExecutor should resolve and store replacement target/enemy when the old target is invalid."
);

console.log("verify_skill_retarget_dead_target: PASS");
```

- [ ] **Step 2: Add the npm script**

In `package.json`, add this entry inside `"scripts"`:

```json
"verify:skill-retarget-dead-target": "node tools\\verify\\verify_skill_retarget_dead_target.js",
```

Keep the JSON comma placement consistent with the surrounding script entries.

- [ ] **Step 3: Run the new verification and confirm it fails**

Run:

```powershell
npm run verify:skill-retarget-dead-target
```

Expected: FAIL with `Missing function is_valid_target` or an assertion saying `SkillActionExecutor` does not use `TargetingServiceScript.is_valid_target(target)`.

---

### Task 2: Implement Centralized Retarget Validation

**Files:**
- Modify: `scripts/skills/targeting_service.gd`
- Modify: `scripts/skills/skill_action_executor.gd`

- [ ] **Step 1: Add public target validity wrapper**

In `scripts/skills/targeting_service.gd`, add this function immediately before `_is_valid_enemy(enemy: Node2D) -> bool`:

```gdscript
static func is_valid_target(enemy: Node2D) -> bool:
	return _is_valid_enemy(enemy)
```

- [ ] **Step 2: Update action context retargeting**

In `scripts/skills/skill_action_executor.gd`, replace the current keep-target condition in `_context_with_resolved_target()`:

```gdscript
if not force_configured_targeting and target != null and is_instance_valid(target) and not target.is_queued_for_deletion():
	return context
```

with:

```gdscript
if not force_configured_targeting and TargetingServiceScript.is_valid_target(target):
	return context
```

The rest of `_context_with_resolved_target()` should remain unchanged so that invalid targets still call `_resolve_action_target(params, context)` and store both `target` and `enemy`.

- [ ] **Step 3: Run the new verification and confirm it passes**

Run:

```powershell
npm run verify:skill-retarget-dead-target
```

Expected:

```text
verify_skill_retarget_dead_target: PASS
```

---

### Task 3: Run Regression Checks

**Files:**
- No code changes expected.

- [ ] **Step 1: Run skill and targeting-adjacent verification**

Run:

```powershell
npm run verify:skill-retarget-dead-target
npm run verify:skill-definition-schema
npm run verify:fire-skill-runtime-smoke
npm run verify:frost-skill-runtime-smoke
```

Expected: each command exits `0` and prints its PASS output.

- [ ] **Step 2: Run player attack/dash and performance guard checks**

Run:

```powershell
npm run verify:player-dash
npm run verify:enemy-motion-neighbor-limit
```

Expected: both commands exit `0` and print PASS output.

- [ ] **Step 3: Check git diff**

Run:

```powershell
git diff --stat
git status --short
```

Expected: only `package.json`, `scripts/skills/targeting_service.gd`, `scripts/skills/skill_action_executor.gd`, and `tools/verify/verify_skill_retarget_dead_target.js` should be changed for implementation.

---

### Task 4: Commit Implementation

**Files:**
- Commit all implementation files from Tasks 1-2.

- [ ] **Step 1: Stage implementation changes**

Run:

```powershell
git add package.json scripts/skills/targeting_service.gd scripts/skills/skill_action_executor.gd tools/verify/verify_skill_retarget_dead_target.js
```

- [ ] **Step 2: Commit**

Run:

```powershell
git commit -m "fix: retarget skills after target death"
```

Expected: commit succeeds with the four implementation files staged.

---

## Execution Notes

- Implemented `TargetingService.is_valid_target()` and reused it from `SkillActionExecutor._context_with_resolved_target()`.
- Added stale-target clearing when an implicit dead target has no replacement, so follow-up actions do not continue using a dead target.
- Added `npm run verify:skill-retarget-dead-target`.
- Passing verification:
  - `npm run verify:skill-retarget-dead-target`
  - `npm run verify:skill-definition-schema`
  - `npm run verify:player-dash`
  - `npm run verify:enemy-motion-neighbor-limit`
- Known unrelated verification failure:
  - `npm run verify:fire-skill-runtime-smoke`
  - `npm run verify:frost-skill-runtime-smoke`
  - Both fail in `SkillManager.add_skill()` because the smoke tests still assume full fire/frost/fusion skill sets can be learned directly, while `e6b6aef` introduced the god-school learning cap. This failure occurs before the retarget action path.
