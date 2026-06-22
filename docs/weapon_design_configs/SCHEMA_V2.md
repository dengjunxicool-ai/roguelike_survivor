# Weapon Branch Design V2 Schema

`weapon_branch_design_v2` describes Lv2-Lv5 branch growth for every weapon design file in this directory.

## Level Path Example

```json
{
  "level_path": {
    "2": {
      "upgrade_role": "direction",
      "summary": "coverage_clear Lv2: increase area, reduce focused single-target damage.",
      "runtime_modifiers": [
        {
          "stat": "radius",
          "op": "multiplier_add",
          "value": 0.15,
          "scope": {
            "domain": "skill"
          }
        },
        {
          "stat": "damage",
          "op": "multiplier_add",
          "value": -0.08,
          "scope": {
            "domain": "skill"
          }
        }
      ],
      "design_modifiers": {
        "coverage_radius_multiplier_add": 0.15,
        "primary_target_damage_multiplier_add": -0.08
      },
      "damage_profile": {
        "primary_attack": 0.6,
        "dot": 0,
        "reaction": 0.2,
        "field": 0.15,
        "trap": 0,
        "summon": 0,
        "survival": 0.05
      },
      "trigger_rules": [
        {
          "trigger": "on_hit_or_kill",
          "condition": "enemy_density_or_area_contact",
          "max_triggers_per_source": 4
        }
      ],
      "special_rules": {
        "tradeoff": "larger_area_lower_single_hit",
        "branch_archetype": "coverage_clear",
        "upgrade_role": "direction"
      },
      "boss_rules": {
        "boss_damage_multiplier": 0.75,
        "boss_dot_multiplier": 0.65,
        "boss_reaction_multiplier": 0.75,
        "boss_field_multiplier": 0.85,
        "boss_control_multiplier": 0
      },
      "limits": {
        "max_targets": 6,
        "max_chain_steps": 4,
        "same_source_cooldown": 0.25,
        "recursive": false
      },
      "runtime_requirements": [],
      "ui_feedback": {
        "icon": "coverage_clear",
        "hint": "large area feedback",
        "level_label": "Lv2",
        "readable_effect": "Increase area, reduce focused single-target damage."
      },
      "modifier_source": "weapon_branch:fire_staff_branch_burst:lv2"
    }
  }
}
```

## Runtime Modifier Effect

`runtime_modifiers` must be an array of structured modifier effects:

```json
{
  "stat": "damage",
  "op": "multiplier_add",
  "value": 0.08,
  "scope": {
    "domain": "skill"
  }
}
```

| Field | Meaning |
| --- | --- |
| `stat` | Canonical runtime stat, validated by `tools/validate_modifier_effects.js`. |
| `op` | Operation: `add`, `multiplier_add`, `multiplier`, or `override`. |
| `value` | Numeric modifier value. |
| `scope` | Where the modifier applies. Weapon branch design configs usually use `domain: "skill"` for skill stats, or `domain: "damage"` with `damage_origin` for damage-channel-specific effects. |

Common branch mappings:

| Old intent | New runtime modifier |
| --- | --- |
| Generic skill damage +8% | `{ "stat": "damage", "op": "multiplier_add", "value": 0.08, "scope": { "domain": "skill" } }` |
| Primary/direct damage +8% | `{ "stat": "damage", "op": "multiplier_add", "value": 0.08, "scope": { "domain": "damage", "damage_origin": ["primary_attack"] } }` |
| Skill area/radius +15% | `{ "stat": "radius", "op": "multiplier_add", "value": 0.15, "scope": { "domain": "skill" } }` |
| Attack speed +5% | `{ "stat": "attack_speed", "op": "multiplier_add", "value": 0.05, "scope": { "domain": "skill" } }` |
| Projectile speed +10% | `{ "stat": "projectile_speed", "op": "multiplier_add", "value": 0.1, "scope": { "domain": "skill" } }` |

## Field Meanings

| Field | Meaning |
| --- | --- |
| `schema` | Config structure version. These files use `weapon_branch_design_v2`. |
| `weapon_id` | Weapon ID corresponding to runtime weapon definitions. |
| `branch_id` | Concrete branch ID. |
| `archetype` | Branch prototype: `coverage_clear`, `precision_hunt`, `status_reaction`, or `survival_control`. |
| `level_path` | Lv2-Lv5 branch growth table. |
| `upgrade_role` | Level role: `direction`, `core_engine`, `efficiency`, or `capstone`. |
| `summary` | Short description for design review, UI, and debug panels. |
| `runtime_modifiers` | Runtime-supported structured modifier effects. This field is validated as an effect array. |
| `design_modifiers` | Design-only values that may later become new modifiers, actions, or special rule executor fields. These are not runtime modifier effects. |
| `damage_profile` | Target damage distribution for balance review; not consumed directly by runtime. |
| `trigger_rules` | Trigger descriptions such as hit, kill, full stack, damaged, low HP, or every N casts. |
| `special_rules` | Mechanic rules that cannot be represented by simple numeric modifiers. |
| `boss_rules` | Boss-specific compensation rules for DOT, reaction, field, control, and percentage damage. |
| `limits` | Safety limits and recursion guards. |
| `runtime_requirements` | Missing runtime capabilities before the design can be fully implemented. |
| `ui_feedback` | Player-facing visual and text feedback requirements. |
| `modifier_source` | Source ID for debugging, statistics, and runtime migration. |

## Rules

- Every `level_path.<level>` block must keep the same field set.
- `runtime_modifiers` only contains structured effects that current runtime can consume.
- New design-side ideas stay in `design_modifiers`, `special_rules`, and `runtime_requirements` until runtime support exists.
- Derived attacks, bounces, reactions, fields, and summons must declare limits to prevent unbounded recursion.
- Boss DOT, reaction, field, control, and percentage-damage behavior must be declared separately in `boss_rules`.
