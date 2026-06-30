# Skill Retarget Design

## Problem

When a skill and the primary attack choose the same enemy in the same short window, the primary attack can kill that enemy before the skill action resolves. Some skill actions then keep using the stale target from the cast context, which can make projectiles or targeted areas miss even though other valid enemies are nearby.

## Goal

If the current cast target is dead, invalid, queued for deletion, or has no remaining health, targeted skill actions should automatically select another valid enemy. The skill should only retarget when the existing target is unusable; living targets should not be replaced.

## Approach

Use a shared target-validity check in `TargetingService`, then have `SkillActionExecutor._context_with_resolved_target()` call that check before trusting `context["target"]`.

The behavior should be:

1. If `context["target"]` is alive and valid, keep it.
2. If the target is invalid, use the action's configured `targeting` or `targeting_mode`.
3. If no targeting is configured, fall back to `nearest_enemy`.
4. Use the action's `range` or `detect_range`; otherwise use the skill stat range fallback.
5. If no valid target exists, preserve the current fallback behavior: the action may use caster position or fail depending on the action type.

## Components

`TargetingService`

- Expose a public `is_valid_target(enemy: Node2D) -> bool` wrapper around the existing enemy validity logic.
- Keep the existing filtering behavior centralized so targeting modes and retargeting share the same definition of alive/valid.

`SkillActionExecutor`

- Update `_context_with_resolved_target()` to reject stale targets using `TargetingService.is_valid_target()`.
- Keep forced targeting behavior for actions with explicit `targeting` or `targeting_mode`.
- Preserve `target` and `enemy` together when a replacement target is found.

## Data Flow

Skill cast emits an action context. Before a targeted action resolves position, direction, projectile launch data, or area center, `_context_with_resolved_target()` validates the context target. If the target is stale, it calls `_resolve_action_target()`, which delegates to `TargetingService.find_target()`. The replacement target then flows through the existing action code as if it had been selected initially.

## Edge Cases

- No other valid enemy: no retarget occurs; existing action fallback behavior remains.
- Explicit non-enemy targeting such as `self`: should continue to work because `TargetingService.find_targets()` handles `self`.
- Bosses, elites, and boss cores: keep current targeting priority and validity rules.
- Already living target: do not retarget, avoiding noisy target switching.

## Tests

Add a focused verification script that creates a caster and two enemies, marks the original target dead, executes a targeted skill action, and asserts the replacement target is selected. The script should also check that a live target is not replaced.

Run existing skill and targeting-related verification commands after implementation.
