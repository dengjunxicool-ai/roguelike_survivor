# Structured Modifiers Runtime Implementation Record

Goal: replace runtime modifier config with structured modifier effects, without keeping old flat modifier dictionaries in runtime data.

Runtime effect shape:

```json
{
	"stat": "damage",
	"op": "multiplier_add",
	"value": 0.12,
	"scope": {
		"domain": "damage",
		"element": ["fire"]
	}
}
```

## Completed Work

- [x] Added `tools/validate_modifier_effects.js` to reject flat modifier containers.
- [x] Migrated runtime data modifier containers in:
  - `data/upgrades.json`
  - `data/relics.json`
  - `data/characters.json`
  - `data/weapon_branches.json`
  - `data/challenges.json`
- [x] Added `tools/migrate_modifier_effects.js` as the one-time migration helper.
- [x] Updated `ModifierSource` to compile structured effects into existing internal calculation keys.
- [x] Updated `ModifierQuery` with `object_type`, `target_type`, and `status_id`.
- [x] Updated `ModifierStore` to keep raw modifier blocks and compile them per query.
- [x] Updated `ModifierAggregator` to pass query context into modifier flattening.
- [x] Updated player level-up modifier handling so `level_modifiers` entries can be effect arrays.
- [x] Updated relic passive, negative, and trigger modifiers to register effect arrays.
- [x] Updated weapon graph and primary attack validators for structured effects.

## Scope Rules

- `domain: "player"` applies to player snapshots and player-scoped queries.
- `domain: "skill"` applies to skill stat calculation.
- `domain: "damage"` applies to damage packet modifier collection.
- `domain: "object"` compiles object-scoped effects such as explosion radius/damage.
- `domain: "status"` compiles status-scoped effects such as burn damage, duration, and max stacks.
- `domain: "economy"`, `"enemy_spawn"`, and `"progression"` are player-level run modifiers.

## Verification

Passed:

```powershell
node tools\validate_modifier_effects.js
node tools\validate_weapon_authoring_pipeline.js
node tools\validate_character_configs.js
```

Not run:

```powershell
godot
godot4
```

Godot executable was not available in PATH in this shell.
