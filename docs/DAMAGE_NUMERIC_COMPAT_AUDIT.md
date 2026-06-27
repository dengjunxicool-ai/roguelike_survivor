# Numeric Damage Compatibility Audit

Audit date: 2026-06-27.

## Scope

This audit covers the legacy numeric damage input path in `scripts/combat/damage_system.gd`.

Current runtime damage calls should pass one of:
- a `DamagePacket` object,
- a packet-like `Dictionary`,
- a result from `DamagePacketBuilder`, `EnemyDamagePacketBuilder`, or `ReactionDamageBuilder`.

Pure numeric damage input is legacy compatibility only.

## Evidence

- Runtime hit sources in `scripts/combat`, `scripts/skills`, `scripts/enemies`, and `scripts/summons` build packet dictionaries before calling `take_damage`.
- `DamageSystem.calculate()` call sites in runtime application stages receive the application context payload, not direct numeric literals.
- `npm run verify:no-numeric-damage-inputs` guards against reintroducing direct numeric literal damage calls in runtime scripts.

## Decision

The numeric fallback inside `DamageSystem._normalize_packet_object()` is a high-risk compatibility boundary and is temporarily retained.

Removing it directly would change the public damage API and could affect older debug callers or external scripts that are not visible from static runtime scans.

## Verification Note

`tools/verify/verify_damage_formula.gd` is the broad damage-system regression check and is available as `npm run verify:damage-formula`.

## Removal Path

1. Keep `verify:no-numeric-damage-inputs` passing.
2. Add a dedicated regression check for the intended rejection behavior.
3. Convert any discovered compatibility callers to explicit packet builders.
4. Remove the fallback in a dedicated combat-system change.
5. Run `tools/verify/verify_damage_formula.gd`, package verification scripts, and full-flow autoplay.
