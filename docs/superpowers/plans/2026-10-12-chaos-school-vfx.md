# Chaos School VFX Implementation Plan

> **For agentic workers:** Apply test-driven-development and verification-before-completion. Independent visual modules are delegated with explicit file ownership; shared integration belongs to root.

**Goal:** Complete all 14 base chaos skill presentations at the same production quality as the approved five schools, after merging their PR.

**Architecture:** Reuse actual AreaEffect/Projectile/SummonController hooks; pure shaders and fixed geometry follow host state. The event bus owns a bounded read-only presentation layer for actual instability, entropy sources, stability readiness, echo charge and singularity progress. No visual produces damage or consumes resources.

**Tech Stack:** Godot 4.6.3, GDScript, CanvasItem shaders, fixed meshes, existing actual combat factories.

**Spec:** Approved ongoing per-school VFX extension in this conversation. Only base chaos skills; no fusion changes. PR #23 has merged the five previously completed schools; branch codex/chaos-school-vfx keeps this new work separate.

## Global Constraints

- Never write files/caches/userdata/logs/screenshots on C:. Use E:/codex and direct PowerShell Godot launches with all four environment paths redirected explicitly.
- Preserve all other working-tree edits. Each worker owns new module files and tests only; root owns shared JSON, event bus, runtime state, host notifications and documentation.
- Shader TIME, gameplay RNG, fake health/shield changes, per-frame node construction and unbounded feedback are prohibited.
- Use actual collision shape/radius, actual damage provenance, host lifecycle/pause, independent materials and clean pool reuse.

## Review Focus

- Clone must replay its actual stored original output; no fake chaos-orb substitute. Show a replay gesture only when replay succeeds.
- Void maw is stationary and actual attack is a pulse area. Do not depict execution or suction as actual mechanics unless a corresponding action succeeds.
- Exchange currently swaps two real targets then creates a circle around their midpoint. Present the actual circular damage footprint plus a pure end-point tearing thread; do not imply damage is restricted to a thin line.
- Entropy requires exact live positive source (cooldown reduction is negative), at most two branches; expired or removed sources cannot remain glowing.
- Stability/echo/fission progress must derive from actual counters and ready flags; failed casts and copy outputs cannot advance fake visual counters.

## Tasks

- [x] Areas: add chaos_area_effect.gd/chaos_area.gdshader/scene, actual eight area profiles, tests for shape/radius/host age/reuse/pause; exchange circle preserved.
- [x] Projectile: add chaos_projectile_effect.gd/shader/scene, actual orb and deterministic fragment wake, tests for fixed geometry/material/reuse/host motion.
- [x] Summons: add two scenes plus chaos_summon_effect.gd/shader; humanoid fractured clone and stationary tooth-ring maw; tests and real clone/pulse damage. Root supplies replay-success notification.
- [x] Root status/feedback: RED tests first; instability four layers, actual entropy/stability/echo/singularity source/counters, confirmed positive chaos impacts and actual swap endpoints; bounded hit/burst/thread pools.
- [x] Root integration: wire eight areas/one projectile/two summons/status; expose only required read-only counters, actual replay/swap notifications without skill events.
- [x] Verification: headless relevant regression matrix, actual damage/resource tests, serial GPU pixel checks/pause, visible/hidden stress with actual HP parity; inspect screenshots.
- [x] Independent review and school documentation; report completed chaos, with PR #23 link. Do not push chaos into the five-school PR.
